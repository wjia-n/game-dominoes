import 'package:flutter/material.dart';
import '../engine/chain_layout.dart';
import '../engine/domino_engine.dart';
import '../services/audio_service.dart';
import '../services/save_store.dart';
import '../services/settings_store.dart';
import '../theme/palette.dart';
import '../theme/physical.dart';
import 'game_over_screen.dart';
import 'settings_screen.dart';

/// Mesa de Juego — the felt table. Serpentine ivory chain with crosswise
/// spinners, brass name plates, walnut hand rack, boneyard stack.
class BoardScreen extends StatefulWidget {
  final DominoEngine engine;
  final SettingsStore settings;
  final bool fresh;
  const BoardScreen(
      {super.key,
      required this.engine,
      required this.settings,
      this.fresh = true});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen>
    with WidgetsBindingObserver {
  late DominoEngine _e;
  final SaveStore _save = SaveStore();
  DomTile? _selected;
  bool _busy = false;
  bool _paused = false;
  String _banner = '';

  bool get _humanTurn =>
      !_e.roundOver && !_busy && !_paused && !_e.isBot[_e.turn];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _e = widget.engine;
    AudioService.instance.playGameMusic();
    if (widget.fresh) {
      AudioService.instance.shuffle();
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) AudioService.instance.roundStart();
      });
    }
    _announceOpening();
    _maybeBot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (!_e.roundOver && !_e.matchOver && mounted && !_paused) {
        setState(() => _paused = true);
      }
      _saveGame();
      AudioService.instance.pauseMusic();
    } else if (state == AppLifecycleState.resumed) {
      if (!_paused) AudioService.instance.resumeMusic();
    }
  }

  Future<void> _saveGame() => _save.save(_e);

  void _announceOpening() {
    final t = _e.spine.first;
    final opener = _e.names[(_e.turn - 1 + _e.n) % _e.n];
    _banner =
        '$opener opens with [${t.connect}|${t.open}]${t.isDouble ? ' — spinner!' : ''}';
  }

  // ------------------------------------------------------------------ bot
  void _maybeBot() {
    if (_e.roundOver || _e.matchOver || _busy || _paused) return;
    if (!_e.isBot[_e.turn]) return;
    _busy = true;
    setState(() => _banner = '${_e.names[_e.turn]} is studying the table…');
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted || _e.roundOver || _paused || !_e.isBot[_e.turn]) {
        _busy = false;
        return;
      }
      _botStep();
    });
  }

  Future<void> _botStep() async {
    while (mounted && !_e.roundOver && !_paused && _e.isBot[_e.turn]) {
      final p = _e.turn;
      final action = _e.botDecision(p);
      await Future.delayed(const Duration(milliseconds: 550));
      if (!mounted || _e.roundOver || _paused) break;
      switch (action.type) {
        case BotActionType.draw:
          final t = _e.drawTile(p, relaxed: action.relaxed);
          setState(() => _banner =
              '${_e.names[p]} draws from the boneyard… (${_e.boneyard.length} left)');
          AudioService.instance.draw();
          if (t == null) {
            _botPass(p, action.relaxed);
            return;
          }
          continue; // drawn tile must be played immediately — bot loops
        case BotActionType.pass:
          _botPass(p, action.relaxed);
          return;
        case BotActionType.play:
          _busy = false;
          _botPlay(p, action.tile!, action.end!);
          return;
      }
    }
    _busy = false;
    if (mounted) setState(() {});
  }

  void _botPass(int p, [bool relaxed = false]) {
    _busy = false;
    try {
      _e.pass(p, relaxed: relaxed);
    } catch (_) {
      return;
    }
    setState(() => _banner = '${_e.names[p]} passes.');
    AudioService.instance.click();
    _afterMove();
  }

  void _botPlay(int p, DomTile tile, ChainEnd end) {
    final madeSpinner = _e.playTile(p, tile, end);
    if (madeSpinner) {
      AudioService.instance.spinner();
    } else {
      AudioService.instance.clack();
    }
    setState(() => _banner =
        '${_e.names[p]} lays [${tile.a}|${tile.b}]${madeSpinner ? ' — spinner!' : ''}');
    _afterMove();
  }

  // ------------------------------------------------------------------ human
  void _onTileTap(DomTile tile) {
    if (!_humanTurn) return;
    if (!_e.hands[_e.turn].contains(tile)) return;
    final ends = _e.endsFor(tile);
    if (ends.isEmpty) {
      AudioService.instance.invalid();
      setState(() => _banner =
          'That tile matches no open end — try another.');
      return;
    }
    AudioService.instance.click();
    if (ends.length == 1) {
      _playHuman(tile, ends.first);
    } else {
      setState(() {
        _selected = (_selected == tile) ? null : tile;
        if (_selected != null) {
          _banner =
              'Where should [${tile.a}|${tile.b}] go? Tap a brass end.';
        }
      });
    }
  }

  void _onEndTap(ChainEnd end) {
    if (!_humanTurn || _selected == null) return;
    final tile = _selected!;
    _playHuman(tile, end);
  }

  void _playHuman(DomTile tile, ChainEnd end) {
    bool madeSpinner = false;
    try {
      madeSpinner = _e.playTile(_e.turn, tile, end);
    } catch (_) {
      AudioService.instance.invalid();
      setState(() {
        _selected = null;
        _banner = 'Not a legal placement — the table disagrees.';
      });
      return;
    }
    _selected = null;
    if (madeSpinner) {
      AudioService.instance.spinner();
    } else {
      AudioService.instance.place();
    }
    setState(() => _banner = madeSpinner
        ? 'Spinner! Both arms need a tile before the chain continues.'
        : '');
    _afterMove();
  }

  void _humanDraw() {
    if (!_humanTurn) return;
    if (_e.mode != GameMode.draw || _e.boneyard.isEmpty) return;
    if (_e.hasPlay(_e.turn)) return; // drawing with a playable tile is illegal
    final t = _e.drawTile(_e.turn);
    if (t == null) return;
    AudioService.instance.draw();
    final fits = _e.endsFor(t).isNotEmpty;
    setState(() {
      _banner = fits
          ? 'Drew [${t.a}|${t.b}] — it fits! Lay it down.'
          : 'Drew [${t.a}|${t.b}] — still stuck, draw again.';
    });
    _saveGame();
  }

  void _humanPass() {
    if (!_humanTurn) return;
    if (_e.boneyard.isNotEmpty || _e.hasPlay(_e.turn)) return;
    try {
      _e.pass(_e.turn);
    } catch (_) {
      AudioService.instance.invalid();
      return;
    }
    AudioService.instance.click();
    setState(() => _banner = '${_e.names[_e.turn]} pass.');
    _afterMove();
  }

  void _afterMove() {
    if (!mounted) return;
    if (_e.roundOver) {
      _saveGame();
      _showRoundEnd();
      return;
    }
    setState(() {
      if (_banner.isEmpty && !_e.isBot[_e.turn]) {
        _banner = '${_e.names[_e.turn]}, your move.';
      }
    });
    _saveGame();
    _maybeBot();
  }

  // -------------------------------------------------------------- round end
  Future<void> _showRoundEnd() async {
    final res = _e.lastResult;
    if (res == null || !mounted) return;
    if (res.domino) {
      AudioService.instance.win();
    } else {
      AudioService.instance.roundStart();
    }
    final action = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => GameOverScreen(
          engine: _e,
          result: res,
          settings: widget.settings,
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'menu') {
      Navigator.of(context).pop();
      return;
    }
    if (action == 'again') {
      Navigator.of(context).pop('again');
      return;
    }
    // next round (or the tie-break decider)
    if (res.tieBreakRound) {
      _e.beginTieBreak();
      if (mounted) {
        setState(() => _banner = 'Decider round — winner takes the match!');
      }
    } else {
      _e.startRound();
      _announceOpening();
    }
    _selected = null;
    _busy = false;
    AudioService.instance.shuffle();
    AudioService.instance.playGameMusic();
    await _saveGame();
    if (mounted) setState(() {});
    _maybeBot();
  }

  // ------------------------------------------------------------------ pause
  void _togglePause() {
    if (_e.roundOver || _e.matchOver) return;
    AudioService.instance.click();
    if (_paused) {
      setState(() => _paused = false);
      AudioService.instance.resumeMusic();
      _maybeBot();
    } else {
      setState(() => _paused = true);
      _saveGame();
      AudioService.instance.pauseMusic();
    }
  }

  void _restartRound() {
    AudioService.instance.click();
    _e.startRound();
    _selected = null;
    _busy = false;
    _paused = false;
    _announceOpening();
    AudioService.instance.shuffle();
    AudioService.instance.resumeMusic();
    _saveGame();
    setState(() {});
    _maybeBot();
  }

  void _quitToMenu() {
    AudioService.instance.click();
    _saveGame();
    Navigator.of(context).pop();
  }

  void _openSettings() {
    AudioService.instance.click();
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => SettingsScreen(settings: widget.settings)))
        .then((_) {
      if (_paused) return; // stay paused behind the overlay
      if (mounted) setState(() {});
    });
  }

  Widget _pauseOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.62),
        child: Center(
          child: ClubPanel(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('PAUSED',
                    style: ClubType.plaqueTitle(24)),
                const SizedBox(height: 6),
                Text('The tiles wait. The coffee doesn\'t.',
                    style: ClubType.bodyText(14,
                        color: ClubPalette.parchment, italic: true)),
                const SizedBox(height: 18),
                BrassButton(label: 'Resume', onTap: _togglePause),
                const SizedBox(height: 10),
                OxbloodButton(label: 'Restart round', onTap: _restartRound),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BrassButton(
                        label: 'Settings',
                        compact: true,
                        onTap: _openSettings),
                    const SizedBox(width: 10),
                    BrassButton(
                        label: 'Quit',
                        compact: true,
                        onTap: _quitToMenu),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------- ui
  @override
  Widget build(BuildContext context) {
    final turn = _e.turn;
    final stuck = _humanTurn && !_e.hasPlay(turn);
    final showDraw = _humanTurn &&
        stuck &&
        _e.mode == GameMode.draw &&
        _e.boneyard.isNotEmpty;
    final showPass =
        _humanTurn && stuck && _e.boneyard.isEmpty;

    return Scaffold(
      backgroundColor: ClubPalette.darkSurface,
      body: FeltTable(
        borderRadius: BorderRadius.circular(12),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _topBar(),
                  _playerPlates(),
                  _bannerStrip(),
                  Expanded(child: _table()),
                  _controls(showDraw: showDraw, showPass: showPass),
                  _handRack(),
                ],
              ),
              if (_paused) _pauseOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePause,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                gradient: ClubPalette.brassFace,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: ClubPalette.brassDark, width: 1.4),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 4,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.pause,
                  color: ClubPalette.deboss, size: 18),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('MESA DE DOMINÓ',
                style: ClubType.plaqueTitle(15)),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: ClubPalette.feltDeep,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: ClubPalette.brassDark.withValues(alpha: 0.7)),
            ),
            child: Text(
              'R${_e.round} · ${_e.matchTarget} PTS',
              style: ClubType.number(12, color: ClubPalette.brassBright),
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerPlates() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: _e.n,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = i == _e.turn && !_e.roundOver;
          final bot = _e.isBot[i];
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: active
                  ? ClubPalette.brassFace
                  : const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF3A2A18), Color(0xFF241610)],
                    ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: active
                      ? ClubPalette.brassBright
                      : ClubPalette.brassDark.withValues(alpha: 0.6),
                  width: active ? 2 : 1.2),
              boxShadow: active
                  ? [
                      BoxShadow(
                          color: ClubPalette.brass
                              .withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2)),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${bot ? '🤖 ' : ''}${_e.names[i]}',
                  style: active
                      ? ClubType.engraved(12)
                      : ClubType.label(12,
                          color: ClubPalette.parchment),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_e.hands[i].length} tiles · ${_e.scores[i]} pts',
                    style: ClubType.number(11,
                        color: active
                            ? ClubPalette.deboss
                            : ClubPalette.brassBright),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _bannerStrip() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEFE6CC), Color(0xFFD9CBA6)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ClubPalette.brassDark, width: 1.2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Text(
        _banner.isEmpty ? 'Welcome to the club.' : _banner,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: ClubType.bodyText(13.5, color: ClubPalette.deboss),
      ),
    );
  }

  Widget _table() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0D0805), width: 3),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size =
                Size(constraints.maxWidth, constraints.maxHeight);
            final layout = ChainLayout.build(_e, size);
            return CustomPaint(
              painter: const FeltPainter(seed: 21),
              child: Stack(
                children: [
                  for (final t in layout.tiles)
                    Positioned(
                      left: t.rect.left,
                      top: t.rect.top,
                      width: t.rect.width,
                      height: t.rect.height,
                      child: DominoTile(
                        first: t.first,
                        second: t.second,
                        vertical: t.vertical,
                        // horizontal rect is 2×tileW wide: width drives height
                        width: t.rect.width,
                      ),
                    ),
                  if (_selected != null && _humanTurn)
                    for (final m in layout.ends)
                      if (_e
                          .endsFor(_selected!)
                          .contains(m.end))
                        Positioned(
                          left: m.center.dx - 17,
                          top: m.center.dy - 17,
                          child: _EndMarker(
                            value: m.end.value,
                            onTap: () => _onEndTap(m.end),
                          ),
                        ),
                  if (_e.mode == GameMode.draw)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: _Boneyard(
                        count: _e.boneyard.length,
                        onTap: _humanDraw,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _controls({required bool showDraw, required bool showPass}) {
    return SizedBox(
      height: 56,
      child: Center(
        child: showDraw
            ? BrassButton(
                label: 'Draw  (${_e.boneyard.length})',
                compact: true,
                onTap: _humanDraw)
            : showPass
                ? OxbloodButton(
                    label: 'Pass', onTap: _humanPass)
                : Text(
                    _e.roundOver
                        ? ''
                        : _e.isBot[_e.turn]
                            ? '${_e.names[_e.turn]} is playing…'
                            : _selected != null
                                ? 'Tap a glowing brass end'
                                : 'Tap one of your tiles to play',
                    style: ClubType.bodyText(13.5,
                        color: ClubPalette.parchment, italic: true),
                  ),
      ),
    );
  }

  Widget _handRack() {
    final hand = _e.hands[_e.turn];
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        gradient: ClubPalette.walnutFace,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ClubPalette.brassDark, width: 1.6),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const BrassRivet(size: 8),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_e.names[_e.turn]}\'s hand · ${hand.length} tiles',
                  style: ClubType.label(12,
                      color: ClubPalette.brassPale),
                ),
              ),
              Text('${_e.scores[_e.turn]} pts',
                  style: ClubType.number(12,
                      color: ClubPalette.brassBright)),
              const SizedBox(width: 8),
              const BrassRivet(size: 8),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: hand.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final tile = hand[i];
                final playable =
                    _humanTurn && _e.endsFor(tile).isNotEmpty;
                final selected = _selected == tile;
                return GestureDetector(
                  onTap: () => _onTileTap(tile),
                  child: AnimatedContainer(
                    duration:
                        const Duration(milliseconds: 160),
                    transform: Matrix4.translationValues(
                        0, playable ? (selected ? -12 : -6) : 6, 0),
                    padding: selected
                        ? const EdgeInsets.all(2.5)
                        : EdgeInsets.zero,
                    decoration: selected
                        ? BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    ClubPalette.brassBright,
                                width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                  color: ClubPalette.brass
                                      .withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3)),
                            ],
                          )
                        : null,
                    child: Opacity(
                      opacity: _humanTurn && !playable ? 0.45 : 1.0,
                      child: DominoTile(
                        first: tile.a,
                        second: tile.b,
                        vertical: true,
                        width: 46,
                        elevation: playable ? 1.4 : 0.8,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Machined brass end marker with a stamped value.
class _EndMarker extends StatelessWidget {
  final int value;
  final VoidCallback onTap;
  const _EndMarker({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AudioService.instance.click();
        onTap();
      },
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-0.3, -0.35),
            radius: 1.15,
            colors: [
              Color(0xFFE9C176),
              Color(0xFFC5A059),
              Color(0xFF8C6C30)
            ],
          ),
          border: Border.all(color: ClubPalette.brassDark, width: 1.6),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 6,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Center(
          child: Text('$value',
              style: ClubType.engraved(16)),
        ),
      ),
    );
  }
}

/// Face-down boneyard stack with a count badge.
class _Boneyard extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _Boneyard({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () {
        AudioService.instance.click();
        onTap();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const DominoTile(
              first: 0, second: 0, faceDown: true, width: 30),
          Positioned(
            right: -8,
            top: -8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: ClubPalette.brassFace,
                border:
                    Border.all(color: ClubPalette.brassDark, width: 1.2),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 4,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Text('$count',
                  style: ClubType.engraved(12)),
            ),
          ),
        ],
      ),
    );
  }
}
