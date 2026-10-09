import 'package:flutter/material.dart';
import '../engine/domino_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/save_store.dart';
import '../services/settings_store.dart';
import '../theme/palette.dart';
import '../theme/physical.dart';
import 'board_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';
import 'theme_screen.dart';

class MenuScreen extends StatefulWidget {
  final SettingsStore settings;
  final StoreService store;
  const MenuScreen({super.key, required this.settings, required this.store});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  GameMode _mode = GameMode.draw;
  int _seats = 2;
  late List<bool> _seatIsBot;
  bool _hasSave = false;
  Map<String, dynamic>? _saveMeta;

  @override
  void initState() {
    super.initState();
    _seatIsBot = [false, true, true, true];
    AudioService.instance.playMenuMusic();
    _checkSave();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh theme/pro state when returning from other screens.
    setState(() {});
  }

  Future<void> _checkSave() async {
    final store = SaveStore();
    final has = await store.hasSave();
    final meta = has ? await store.meta() : null;
    if (mounted) {
      setState(() {
        _hasSave = has;
        _saveMeta = meta;
      });
    }
  }

  List<String> _names() => List.generate(
      _seats, (i) => widget.settings.playerNames[i]);
  List<bool> _bots() => List.generate(_seats, (i) => _seatIsBot[i]);

  void _start({DominoEngine? restored}) {
    AudioService.instance.click();
    final engine = restored ??
        (DominoEngine(
          mode: _mode,
          names: _names(),
          isBot: _bots(),
          difficulty: widget.settings.difficulty,
          matchTarget: widget.settings.matchTarget,
        )..newMatch());
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => BoardScreen(
          engine: engine,
          settings: widget.settings,
          store: widget.store,
          fresh: restored == null,
        ),
      ),
    )
        .then((_) {
      AudioService.instance.playMenuMusic();
      _checkSave();
    });
  }

  Future<void> _continue() async {
    final engine = await SaveStore().load();
    if (engine == null) {
      if (mounted) setState(() => _hasSave = false);
      return;
    }
    _start(restored: engine);
  }

  void _openSettings() {
    AudioService.instance.click();
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => SettingsScreen(settings: widget.settings)))
        .then((_) => setState(() {}));
  }

  void _openThemes() {
    AudioService.instance.click();
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => ThemeScreen(
                settings: widget.settings, store: widget.store)))
        .then((_) => setState(() {}));
  }

  void _openPro() {
    AudioService.instance.click();
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => ProScreen(
                settings: widget.settings, store: widget.store)))
        .then((_) => setState(() {}));
  }

  void _renameSeat(int seat) {
    final ctrl =
        TextEditingController(text: widget.settings.playerNames[seat]);
    AudioService.instance.click();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClubPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('NAME SEAT ${seat + 1}',
                  textAlign: TextAlign.center,
                  style: ClubType.plaqueTitle(18)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLength: 14,
                style: ClubType.bodyText(17),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: ClubPalette.feltDeep,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: ClubPalette.brassDark, width: 1.4),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: ClubPalette.brassBright, width: 1.8),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OxbloodButton(
                      label: 'Cancel',
                      onTap: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BrassButton(
                      label: 'Save',
                      onTap: () {
                        widget.settings.setPlayerName(seat, ctrl.text);
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _howToPlay() {
    AudioService.instance.click();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClubPanel(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('HOW TO PLAY',
                    textAlign: TextAlign.center,
                    style: ClubType.plaqueTitle(20)),
                const SizedBox(height: 12),
                Text(
                  'Match the open ends of the chain. Tap one of your '
                  'tiles, then tap a glowing brass end to lay it down.\n\n'
                  '• Highest double opens; no doubles, heaviest tile opens.\n'
                  '• Doubles are spinners, laid crosswise — both arms must '
                  'take a tile before the chain ends open again.\n'
                  '• Draw game: stuck? Pull from the boneyard until a tile '
                  'fits. Block game: no boneyard — pass and grit your teeth.\n'
                  '• Empty your hand to shout DOMINO and bank every pip '
                  'left in rival hands. Blocked round: fewest pips wins.\n'
                  '• First to the target score takes the match.',
                  style: ClubType.bodyText(15),
                ),
                const SizedBox(height: 16),
                Center(
                    child: BrassButton(
                        label: 'Back to the club',
                        compact: true,
                        onTap: () => Navigator.pop(ctx))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClubPalette.darkSurface,
      body: FeltTable(
        borderRadius: BorderRadius.circular(12),
        theme: widget.settings.theme,
        child: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 6),
                // Game logo.
                Center(
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: ClubPalette.brassBright, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          offset: const Offset(0, 8),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/domino_logo.png',
                        fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 8),
                Text('CLUB DE DOMINÓ HABANA',
                    textAlign: TextAlign.center,
                    style: ClubType.label(12, color: ClubPalette.brass)),
                const SizedBox(height: 2),
                Text('DOMINOES',
                    textAlign: TextAlign.center,
                    style: ClubType.headline(46).copyWith(
                      shadows: const [
                        Shadow(
                            color: Color(0xAA000000),
                            offset: Offset(0, 3),
                            blurRadius: 4),
                        Shadow(
                            color: Color(0x66FFF3D6),
                            offset: Offset(0, -1),
                            blurRadius: 0),
                      ],
                    )),
                Text('Salón Tradicional · where every tile tells a story',
                    textAlign: TextAlign.center,
                    style: ClubType.bodyText(14,
                        color: ClubPalette.parchment, italic: true)),
                const SizedBox(height: 14),
                const _LooseTiles(),
                const SizedBox(height: 18),
                Text('MODALIDAD DE MESA',
                    textAlign: TextAlign.center,
                    style: ClubType.label(12, color: ClubPalette.brass)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: _ModePlaque(
                            title: 'Draw Game',
                            sub: 'Boneyard · draw till it fits',
                            selected: _mode == GameMode.draw,
                            onTap: () {
                              AudioService.instance.click();
                              setState(() => _mode = GameMode.draw);
                            })),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _ModePlaque(
                            title: 'Block Game',
                            sub: 'No boneyard · pass when stuck',
                            selected: _mode == GameMode.block,
                            onTap: () {
                              AudioService.instance.click();
                              setState(() => _mode = GameMode.block);
                            })),
                  ],
                ),
                const SizedBox(height: 16),
                Text('JUGADORES',
                    textAlign: TextAlign.center,
                    style: ClubType.label(12, color: ClubPalette.brass)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [2, 3, 4]
                      .map((n) => Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 5),
                            child: _SeatChip(
                                n: n,
                                selected: _seats == n,
                                onTap: () {
                                  AudioService.instance.click();
                                  setState(() => _seats = n);
                                }),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                // Seat setup: every seat is human or bot, with a renameable name.
                ClubPanel(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Column(
                    children: [
                      for (int i = 0; i < _seats; i++)
                        _SeatRow(
                          seat: i,
                          name: widget.settings.playerNames[i],
                          isBot: _seatIsBot[i],
                          onToggleBot: (v) {
                            AudioService.instance.click();
                            setState(() => _seatIsBot[i] = v);
                          },
                          onRename: () => _renameSeat(i),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Seat 1 is always human. Flip seats to mix bots and '
                  'pass-and-play rivals.',
                  textAlign: TextAlign.center,
                  style: ClubType.bodyText(12,
                      color: ClubPalette.parchment, italic: true),
                ),
                const SizedBox(height: 14),
                if (_hasSave) ...[
                  OxbloodButton(
                      label:
                          'Continue — round ${_saveMeta?['round'] ?? '?'}',
                      onTap: _continue),
                  const SizedBox(height: 10),
                ],
                BrassButton(label: "Rack 'em up", onTap: () => _start()),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _MiniLink(label: 'Settings', onTap: _openSettings),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: BrassRivet(size: 8),
                    ),
                    _MiniLink(label: 'Table & tiles', onTap: _openThemes),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: BrassRivet(size: 8),
                    ),
                    _MiniLink(label: 'How to play', onTap: _howToPlay),
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: GestureDetector(
                    onTap: _openPro,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: ClubPalette.brassBright, width: 1.4),
                        color: ClubPalette.brass.withValues(alpha: 0.15),
                      ),
                      child: Text(
                        widget.settings.pro
                            ? '✦ PRO MEMBER ✦'
                            : '✦ GO PRO — 12 tables, 10 tiles, Hard bot ✦',
                        style: ClubType.label(12,
                            color: ClubPalette.brassBright),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                    'Difficulty: ${_diffName(widget.settings.difficulty)} · '
                    'Target: ${widget.settings.matchTarget} pts',
                    textAlign: TextAlign.center,
                    style: ClubType.label(11, color: ClubPalette.parchment)),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _diffName(BotDifficulty d) => switch (d) {
        BotDifficulty.easy => 'Easy',
        BotDifficulty.normal => 'Normal',
        BotDifficulty.hard => 'Hard',
      };
}

/// One seat: name (tap ✎ to rename), human/bot flip.
class _SeatRow extends StatelessWidget {
  final int seat;
  final String name;
  final bool isBot;
  final ValueChanged<bool> onToggleBot;
  final VoidCallback onRename;
  const _SeatRow({
    required this.seat,
    required this.name,
    required this.isBot,
    required this.onToggleBot,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final locked = seat == 0; // seat 1 is always human
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: ClubPalette.brassDark, width: 1.4),
              color: ClubPalette.feltDeep,
            ),
            child: Center(
              child: Text('${seat + 1}',
                  style: ClubType.number(13,
                      color: ClubPalette.brassBright)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: onRename,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ClubType.bodyText(16),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit,
                      size: 14, color: ClubPalette.brass),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(isBot ? 'BOT' : 'HUMAN',
              style: ClubType.label(11,
                  color: isBot
                      ? ClubPalette.parchment
                      : ClubPalette.brassBright)),
          const SizedBox(width: 8),
          if (locked)
            Text('fixed',
                style: ClubType.bodyText(11,
                    color: ClubPalette.parchment, italic: true))
          else
            BrassToggle(value: isBot, onChanged: onToggleBot),
        ],
      ),
    );
  }
}

class _LooseTiles extends StatelessWidget {
  const _LooseTiles();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          _TiltedTile(first: 6, second: 6, angle: -0.22),
          SizedBox(width: 14),
          _TiltedTile(first: 3, second: 5, angle: 0.08),
          SizedBox(width: 14),
          _TiltedTile(first: 0, second: 4, angle: 0.24),
        ],
      ),
    );
  }
}

class _TiltedTile extends StatelessWidget {
  final int first, second;
  final double angle;
  const _TiltedTile(
      {required this.first, required this.second, required this.angle});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: DominoTile(first: first, second: second, width: 40, vertical: true),
    );
  }
}

class _ModePlaque extends StatelessWidget {
  final String title, sub;
  final bool selected;
  final VoidCallback onTap;
  const _ModePlaque(
      {required this.title,
      required this.sub,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          gradient: selected
              ? ClubPalette.brassFace
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2A2118), Color(0xFF171008)],
                ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected
                  ? ClubPalette.brassDark
                  : const Color(0xFF5C5140),
              width: 1.6),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 6,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          children: [
            Text(title.toUpperCase(),
                textAlign: TextAlign.center,
                style: selected
                    ? ClubType.engraved(15)
                    : ClubType.label(14, color: ClubPalette.parchment)),
            const SizedBox(height: 4),
            Text(sub,
                textAlign: TextAlign.center,
                style: ClubType.bodyText(11.5,
                    color: selected
                        ? ClubPalette.deboss
                        : ClubPalette.parchment)),
          ],
        ),
      ),
    );
  }
}

class _SeatChip extends StatelessWidget {
  final int n;
  final bool selected;
  final VoidCallback onTap;
  const _SeatChip(
      {required this.n, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: selected
              ? const RadialGradient(
                  center: Alignment(-0.3, -0.35),
                  radius: 1.2,
                  colors: [
                    Color(0xFFE9C176),
                    Color(0xFFC5A059),
                    Color(0xFF8C6C30)
                  ],
                )
              : const RadialGradient(
                  center: Alignment(-0.3, -0.35),
                  radius: 1.2,
                  colors: [Color(0xFF3A2E1E), Color(0xFF1D150C)],
                ),
          border: Border.all(color: ClubPalette.brassDark, width: 1.6),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 5,
                offset: const Offset(0, 2.5)),
          ],
        ),
        child: Center(
          child: Text('$n',
              style: selected
                  ? ClubType.engraved(20)
                  : ClubType.number(20, color: ClubPalette.parchment)),
        ),
      ),
    );
  }
}

class _MiniLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _MiniLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Text(label,
            style: ClubType.label(13, color: ClubPalette.brassBright)
                .copyWith(decoration: TextDecoration.underline)),
      ),
    );
  }
}
