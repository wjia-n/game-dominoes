import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_store.dart';
import '../theme/club_themes.dart';
import '../theme/palette.dart';
import '../theme/physical.dart';
import 'menu_screen.dart';

/// Launch flow: a WAJIHA company splash moment, then the game splash
/// (logo + name + animated loading line + "Credits: WAJIHA").
class SplashScreen extends StatefulWidget {
  final SettingsStore settings;
  final StoreService store;
  const SplashScreen({super.key, required this.settings, required this.store});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loader;
  bool _company = true;

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _run();
  }

  Future<void> _run() async {
    // Company moment on the official WAJIHA mark, then the game splash.
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() => _company = false);
    // Pre-warm audio while the splash shows, then start menu music.
    AudioService.instance.prewarm();
    AudioService.instance.playMenuMusic();
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            MenuScreen(settings: widget.settings, store: widget.store),
      ),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.settings.theme;
    return Scaffold(
      backgroundColor: const Color(0xFF0E0B08),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _company
            ? _CompanySplash(key: const ValueKey('company'))
            : _GameSplash(
                key: const ValueKey('game'),
                theme: theme,
                loader: _loader,
              ),
      ),
    );
  }
}

/// Company splash moment: the official WAJIHA mark, untouched.
class _CompanySplash extends StatelessWidget {
  const _CompanySplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/wajiha_logo.png',
            width: 120,
            height: 120,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 18),
          Text(
            'WAJIHA',
            style: ClubType.label(20, color: ClubPalette.brassBright),
          ),
        ],
      ),
    );
  }
}

/// Game splash: logo + name + animated loading line + credits.
class _GameSplash extends StatelessWidget {
  final ClubThemeDef theme;
  final AnimationController loader;
  const _GameSplash(
      {super.key, required this.theme, required this.loader});

  @override
  Widget build(BuildContext context) {
    return FeltTable(
      theme: theme,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: theme.accentBright, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      offset: const Offset(0, 10),
                      blurRadius: 24,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset('assets/domino_logo.png',
                    fit: BoxFit.cover),
              ),
              const SizedBox(height: 20),
              Text('DOMINOES',
                  style: ClubType.headline(46).copyWith(
                    color: theme.accentBright,
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
              const SizedBox(height: 4),
              Text(
                'CLUB DE DOMINÓ HABANA',
                style: ClubType.label(13, color: theme.accent),
              ),
              const SizedBox(height: 30),
              // Animated loading line.
              SizedBox(
                width: 220,
                child: AnimatedBuilder(
                  animation: loader,
                  builder: (_, _) => Column(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: Colors.black.withValues(alpha: 0.45),
                          border: Border.all(color: theme.accentDeep),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: loader.value.clamp(0.02, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              gradient: LinearGradient(
                                colors: [
                                  theme.accentBright,
                                  theme.accent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        loader.value < 1
                            ? 'Racking the tiles…'
                            : 'The table is ready.',
                        style: ClubType.bodyText(13,
                            color: theme.creamText
                                .withValues(alpha: 0.75)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 44),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/wajiha_logo.png',
                    width: 30,
                    height: 30,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Credits: WAJIHA',
                    style: ClubType.label(14, color: theme.parchment),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
