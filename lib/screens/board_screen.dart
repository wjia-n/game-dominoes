import 'package:flutter/material.dart';
import '../engine/chain_layout.dart';
import '../engine/domino_engine.dart';
import '../engine/turn_director.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/save_store.dart';
import '../services/settings_store.dart';
import '../theme/club_themes.dart';
import '../theme/palette.dart';
import '../theme/physical.dart';
import 'game_over_screen.dart';
import 'settings_screen.dart';

/// Mesa de Juego — the felt table, driven by the engine-owned [TurnDirector].
///
/// Every seat has its own tray showing the active player with narration;
/// bot draws and placements fly visibly across the table — never silently
/// auto-played. The UI renders director events; it never drives turns.
class BoardScreen extends StatefulWidget {
  final DominoEngine engine;
  final SettingsStore settings;
  final StoreService store;
  final bool fresh;
  const BoardScreen({
    super.key,
    required this.engine,
    required this.settings,
    required this.store,
    this.fresh = true,
  });

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

/// One tile in flight across the table (bot draw / placement).
class _Flight {
  final int id;
  final Offset from;
  final Offset to;
  final int first;
  final int second;
  final bool faceDown;
  final int seq; // revealed on landing (-1 for draws)
  final int player;
  final bool spinner;
  final AnimationController controller;
  _Flight({
    required this.id,
    required this.from,
    required this.to,
    required this.first,
    required this.second,
    required this.faceDown,
    required this.seq,
    required this.player,
    required this.spinner,
    required this.controller,
  });
}

class _BoardScreenState extends State<BoardScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late DominoEngine _e;
  final SaveStore _save = SaveStore();
  TurnDirector? _director;
  DomTile? _selected;
  bool _paused = false;
  String _banner = '';

  // Visibility machinery.
  final List<_Flight> _flights = [];
  int _flightId = 0;
  final Set<int> _hiddenSeqs = {};
  final Map<int, int> _pendingDraws = {};
  final Map<int, String> _trayStatus = {};
  late List<GlobalKey> _trayKeys;
  final GlobalKey _boneyardKey = GlobalKey();
  final GlobalKey _tableKey = GlobalKey();
  Size _tableSize = Size.zero;

  ClubThemeDef get _theme => widget.settings.theme;
  TileStyleDef get _tileStyle => widget.settings.tileStyle;

  bool get _humanTurn =>
      !_e.roundOver &&
      !_paused &&
      _director?.phase == DirectorPhase.awaitingHuman &&
      !_e.isBot[_e.turn];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _e = widget.engine;
    _trayKeys = List.generate(_e.n, (_) => GlobalKey());
    AudioService.instance.playGameMusic();
    if (widget.fresh) {
      AudioService.instance.shuffle();
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) AudioService.instance.roundStart();
      });
    }
    _announceOpening();
    _attachDirector();
  }

  @override
  void dispose() {
    _director?.dispose();
    for (final f in _flights) {
      f.controller.dispose();
    }
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
      _detachDirector();
      _saveGame();
      AudioService.instance.pauseMusic();
    } else if (state == AppLifecycleState.resumed) {
      if (!_paused) AudioService.instance.resumeMusic();
    }
  }

  // ------------------------------------------------------------- director
  void _attachDirector() {
    _director?.dispose();
    _director = TurnDirector(engine: _e, onEvent: _onDirectorEvent)
      ..start()
      ..startWatchdog();
  }

  void _detachDirector() {
    _director?.dispose();
    _director = null;
    for (final f in _flights) {
      f.controller.dispose();
    }
    _flights.clear();
    _hiddenSeqs.clear();
    _pendingDraws.clear();
  }

  void _onDirectorEvent(DirectorEvent e) {
    if (!mounted) return;
    switch (e) {
      case HumanTurnEvent(:final player):
        _selected = null;
        _trayStatus.clear();
        _saveGame();
        setState(() => _banner = _humanPrompt(player));
      case BotThinkingEvent(:final player):
        _trayStatus[player] = 'studying the table…';
        setState(
            () => _banner = '${_e.names[player]} is studying the table…');
      case BotDrewEvent(:final player, :final boneyardLeft):
        _trayStatus[player] = 'drawing…';
        _pendingDraws[player] = (_pendingDraws[player] ?? 0) + 1;
        AudioService.instance.draw();
        _saveGame();
        setState(() => _banner =
            '${_e.names[player]} draws from the boneyard… ($boneyardLeft left)');
        _flyDraw(player);
      case BotPlayedEvent(
          :final player,
          :final tile,
          :final spinner,
        ):
        final seq = _newestSeq();
        _hiddenSeqs.add(seq);
        _trayStatus[player] =
            'laid [${tile.a}|${tile.b}]${spinner ? ' — spinner!' : ''}';
        _saveGame();
        setState(() => _banner =
            '${_e.names[player]} lays [${tile.a}|${tile.b}]${spinner ? ' — spinner!' : ''}');
        _flyPlay(player, tile, seq, spinner);
      case BotPassedEvent(:final player):
        _trayStatus[player] = 'passed';
        AudioService.instance.click();
        _saveGame();
        setState(() => _banner = '${_e.names[player]} passes.');
      case RoundEndedEvent(:final result):
        _onRoundEnded(result);
    }
  }

  String _humanPrompt(int player) {
    final humans = _e.isBot.where((b) => !b).length;
    if (humans <= 1) return 'Your move, ${_e.names[player]}.';
    return "${_e.names[player]}'s turn — pass the phone.";
  }

  /// Max PlacedTile.seq on the table — the tile the engine just committed.
  int _newestSeq() {
    var m = -1;
    for (final t in _e.spine) {
      if (t.seq > m) m = t.seq;
    }
    for (final s in _e.spinners) {
      for (final t in s.armA) {
        if (t.seq > m) m = t.seq;
      }
      for (final t in s.armB) {
        if (t.seq > m) m = t.seq;
      }
    }
    return m;
  }

  Offset? _keyCenter(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  void _flyDraw(int player) {
    final from = _keyCenter(_boneyardKey) ?? _keyCenter(_trayKeys[player]);
    final to = _keyCenter(_trayKeys[player]);
    if (from == null || to == null) {
      _pendingDraws[player] = (_pendingDraws[player] ?? 1) - 1;
      return;
    }
    final c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    final f = _Flight(
      id: _flightId++,
      from: from,
      to: to,
      first: 0,
      second: 0,
      faceDown: true,
      seq: -1,
      player: player,
      spinner: false,
      controller: c,
    );
    _flights.add(f);
    c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        _pendingDraws[player] = (_pendingDraws[player] ?? 1) - 1;
        f.controller.dispose();
        setState(() => _flights.remove(f));
      }
    });
    setState(() {});
    c.forward();
  }

  void _flyPlay(int player, DomTile tile, int seq, bool spinner) {
    final from = _keyCenter(_trayKeys[player]);
    // Target: the rect of the just-placed tile in the current layout.
    Offset? to;
    if (_tableSize != Size.zero) {
      final layout = ChainLayout.build(_e, _tableSize);
      for (final t in layout.tiles) {
        if (t.seq == seq) {
          final box =
              _tableKey.currentContext?.findRenderObject() as RenderBox?;
          if (box != null && box.hasSize) {
            to = box.localToGlobal(t.rect.center);
          }
          break;
        }
      }
    }
    if (from == null || to == null) {
      // Table not laid out yet — reveal immediately, no flight.
      _hiddenSeqs.remove(seq);
      if (spinner) {
        AudioService.instance.spinner();
      } else {
        AudioService.instance.clack();
      }
      setState(() {});
      return;
    }
    final c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));
    final f = _Flight(
      id: _flightId++,
      from: from,
      to: to,
      first: tile.a,
      second: tile.b,
      faceDown: false,
      seq: seq,
      player: player,
      spinner: spinner,
      controller: c,
    );
    _flights.add(f);
    c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        _hiddenSeqs.remove(seq);
        if (spinner) {
          AudioService.instance.spinner();
        } else {
          AudioService.instance.clack();
        }
        f.controller.dispose();
        setState(() => _flights.remove(f));
      }
    });
    setState(() {});
    c.forward();
  }

  // ------------------------------------------------------------------ human
  void _onTileTap(DomTile tile) {
    if (!_humanTurn) return;
    if (!_e.hands[_e.turn].contains(tile)) return;
    final ends = _e.endsFor(tile);
    if (ends.isEmpty) {
      AudioService.instance.invalid();
      setState(() =>
          _banner = 'That tile matches no open end — try another.');
      return;
    }
    AudioService.instance.click();
    if (ends.length == 1) {
      _playHuman(tile, ends.first);
    } else {
      setState(() {
        _selected = (_selected == tile) ? null : tile;
        if (_selected != null) {
          _banner = 'Where should [${tile.a}|${tile.b}] go? Tap a brass end.';
        } else {
          _banner = _humanPrompt(_e.turn);
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
    _saveGame();
    _director?.humanPlayed();
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
    _director?.humanDrew();
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
    _saveGame();
    _director?.humanPassed();
  }

  // -------------------------------------------------------------- round end
  bool _roundSheetOpen = false;

  void _onRoundEnded(RoundResult result) {
    if (_roundSheetOpen) return;
    _roundSheetOpen = true;
    _saveGame(); // clears the save: nothing resumable
    if (result.domino) {
      AudioService.instance.win();
    } else {
      AudioService.instance.roundStart();
    }
    Future.microtask(() async {
      if (!mounted) {
        _roundSheetOpen = false;
        return;
      }
      final action = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => GameOverScreen(
            engine: _e,
            result: result,
            settings: widget.settings,
          ),
        ),
      );
      _roundSheetOpen = false;
      if (!mounted) return;
      if (action == 'menu' || (result.matchOver && action != 'again')) {
        Navigator.of(context).pop();
        return;
      }
      if (action == 'again') {
        Navigator.of(context).pop('again');
        return;
      }
      // 'next' (or the decider): the director owns the next round.
      _selected = null;
      _trayStatus.clear();
      AudioService.instance.shuffle();
      AudioService.instance.playGameMusic();
      _director?.nextRound();
      _announceOpening();
      if (mounted) setState(() {});
    });
  }

  void _announceOpening() {
    if (_e.spine.isEmpty) return;
    final t = _e.spine.first;
    final opener = _e.names[(_e.turn - 1 + _e.n) % _e.n];
    _banner =
        '$opener opens with [${t.connect}|${t.open}]${t.isDouble ? ' — spinner!' : ''}';
  }

  Future<void> _saveGame() => _save.save(_e);

  // ------------------------------------------------------------------ pause
  void _togglePause() {
    if (_e.roundOver || _e.matchOver) return;
    AudioService.instance.click();
    if (_paused) {
      setState(() => _paused = false);
      AudioService.instance.resumeMusic();
      _attachDirector();
    } else {
      setState(() => _paused = true);
      _detachDirector();
      _saveGame();
      AudioService.instance.pauseMusic();
    }
  }

  void _restartRound() {
    AudioService.instance.click();
    _detachDirector();
    _e.startRound();
    _selected = null;
    _trayStatus.clear();
    _paused = false;
    _announceOpening();
    AudioService.instance.shuffle();
    AudioService.instance.resumeMusic();
    _saveGame();
    setState(() {});
    _attachDirector();
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
      if (_paused) return;
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
                Text('PAUSED', style: ClubType.plaqueTitle(24)),
                const SizedBox(height: 6),
                Text("The tiles wait. The coffee doesn't.",
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
                        label: 'Quit', compact: true, onTap: _quitToMenu),
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
    return Stack(
      children: [
        Scaffold(
          backgroundColor: ClubPalette.darkSurface,
          body: FeltTable(
            borderRadius: BorderRadius.circular(12),
            theme: _theme,
            child: SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      _topBar(),
                      _traysStrip(),
                      _bannerStrip(),
                      Expanded(child: _table()),
                      _controls(),
                      _handRack(),
                    ],
                  ),
                  if (_paused) _pauseOverlay(),
                ],
              ),
            ),
          ),
        ),
        for (final f in _flights) _flightWidget(f),
      ],
    );
  }

  Widget _flightWidget(_Flight f) {
    return AnimatedBuilder(
      animation: f.controller,
      builder: (_, _) {
        final t = Curves.easeInOut.transform(f.controller.value);
        final pos = Offset.lerp(f.from, f.to, t)!;
        const w = 34.0;
        return Positioned(
          left: pos.dx - w / 2,
          top: pos.dy - w,
          child: Transform.rotate(
            angle: (1 - t) * 0.5,
            child: Opacity(
              opacity: 0.35 + 0.65 * t,
              child: DominoTile(
                first: f.first,
                second: f.second,
                vertical: true,
                faceDown: f.faceDown,
                width: w,
                elevation: 1.6,
                style: _tileStyle,
              ),
            ),
          ),
        );
      },
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
                border: Border.all(color: ClubPalette.brassDark, width: 1.4),
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
              color: _theme.feltDeep,
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

  /// Every seat's own tray: name, type, hidden-tile fan, score, and the
  /// active seat highlighted with live narration.
  Widget _traysStrip() {
    final accent = widget.settings.tableAccent;
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: _e.n,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = i == _e.turn && !_e.roundOver;
          final bot = _e.isBot[i];
          final count =
              _e.hands[i].length - (_pendingDraws[i] ?? 0);
          final status = _trayStatus[i];
          return AnimatedContainer(
            key: _trayKeys[i],
            duration: const Duration(milliseconds: 200),
            width: 128,
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _theme.walnutLight,
                  _theme.walnut,
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: active ? accent.color : accent.deep,
                  width: active ? 2.4 : 1.2),
              boxShadow: active
                  ? [
                      BoxShadow(
                          color: accent.color.withValues(alpha: 0.45),
                          blurRadius: 10,
                          offset: const Offset(0, 2)),
                    ]
                  : [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2)),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _e.names[i].toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ClubType.label(
                            10.5,
                            color: active
                                ? accent.color
                                : ClubPalette.brassPale),
                      ),
                    ),
                    Text(bot ? '🤖' : '🧑',
                        style: const TextStyle(fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 2),
                // hidden-tile fan
                SizedBox(
                  height: 20,
                  child: Row(
                    children: [
                      for (int k = 0;
                          k < count.clamp(0, 7);
                          k++)
                        Container(
                          width: 9,
                          height: 18,
                          margin: const EdgeInsets.only(right: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _theme.walnutLight,
                                _theme.walnutDeep,
                              ],
                            ),
                            border: Border.all(
                                color: accent.deep, width: 0.8),
                          ),
                        ),
                      const SizedBox(width: 2),
                      Text('$count',
                          style: ClubType.number(10,
                              color: ClubPalette.brassBright)),
                    ],
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  active && status != null
                      ? status
                      : '${_e.scores[i]} pts',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ClubType.bodyText(
                      10.5,
                      color: active
                          ? ClubPalette.brassBright
                          : ClubPalette.parchment,
                      italic: active),
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
          key: _tableKey,
          builder: (context, constraints) {
            final size =
                Size(constraints.maxWidth, constraints.maxHeight);
            _tableSize = size;
            final layout = ChainLayout.build(_e, size);
            return CustomPaint(
              painter: FeltPainter(seed: 21, theme: _theme),
              child: Stack(
                children: [
                  for (final t in layout.tiles)
                    if (!_hiddenSeqs.contains(t.seq))
                      Positioned(
                        left: t.rect.left,
                        top: t.rect.top,
                        width: t.rect.width,
                        height: t.rect.height,
                        child: DominoTile(
                          first: t.first,
                          second: t.second,
                          vertical: t.vertical,
                          width: t.rect.width,
                          style: _tileStyle,
                        ),
                      ),
                  if (_selected != null && _humanTurn)
                    for (final m in layout.ends)
                      if (_e.endsFor(_selected!).contains(m.end))
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
                        key: _boneyardKey,
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

  Widget _controls() {
    final turn = _e.turn;
    final stuck = _humanTurn && !_e.hasPlay(turn);
    final showDraw = _humanTurn &&
        stuck &&
        _e.mode == GameMode.draw &&
        _e.boneyard.isNotEmpty;
    final showPass = _humanTurn && stuck && _e.boneyard.isEmpty;
    return SizedBox(
      height: 56,
      child: Center(
        child: showDraw
            ? BrassButton(
                label: 'Draw  (${_e.boneyard.length})',
                compact: true,
                onTap: _humanDraw)
            : showPass
                ? OxbloodButton(label: 'Pass', onTap: _humanPass)
                : Text(
                    _e.roundOver
                        ? ''
                        : _e.isBot[_e.turn]
                            ? '${_e.names[_e.turn]} is playing — watch the table…'
                            : _selected != null
                                ? 'Tap a glowing brass end'
                                : 'Tap one of your tiles to play',
                    style: ClubType.bodyText(13.5,
                        color: ClubPalette.parchment, italic: true),
                  ),
      ),
    );
  }

  /// The current seat's rack: the human's real tiles face-up and playable;
  /// a bot's tiles stay hidden (watch their tray instead).
  Widget _handRack() {
    final turn = _e.turn;
    final human = !_e.isBot[turn];
    final hand = _e.hands[turn];
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_theme.walnutLight, _theme.walnutDeep],
        ),
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
                  human
                      ? '${_e.names[turn]}\'s hand · ${hand.length} tiles'
                      : '${_e.names[turn]}\'s tiles stay hidden — watch their tray',
                  style: ClubType.label(12,
                      color: ClubPalette.brassPale),
                ),
              ),
              Text('${_e.scores[turn]} pts',
                  style: ClubType.number(12,
                      color: ClubPalette.brassBright)),
              const SizedBox(width: 8),
              const BrassRivet(size: 8),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 108,
            child: human
                ? ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: hand.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: 8),
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
                              0,
                              playable
                                  ? (selected ? -12 : -6)
                                  : 6,
                              0),
                          padding: selected
                              ? const EdgeInsets.all(2.5)
                              : EdgeInsets.zero,
                          decoration: selected
                              ? BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  border: Border.all(
                                      color: ClubPalette.brassBright,
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
                            opacity:
                                _humanTurn && !playable ? 0.45 : 1.0,
                            child: DominoTile(
                              first: tile.a,
                              second: tile.b,
                              vertical: true,
                              width: 46,
                              elevation: playable ? 1.4 : 0.8,
                              style: _tileStyle,
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int k = 0;
                          k < hand.length.clamp(0, 10);
                          k++)
                        Container(
                          width: 26,
                          height: 52,
                          margin:
                              const EdgeInsets.symmetric(horizontal: 3),
                          child: DominoTile(
                              first: 0,
                              second: 0,
                              faceDown: true,
                              width: 26,
                              style: _tileStyle),
                        ),
                    ],
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
          child: Text('$value', style: ClubType.engraved(16)),
        ),
      ),
    );
  }
}

/// Face-down boneyard stack with a count badge.
class _Boneyard extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _Boneyard({super.key, required this.count, required this.onTap});

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
              child: Text('$count', style: ClubType.engraved(12)),
            ),
          ),
        ],
      ),
    );
  }
}
