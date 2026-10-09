import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'services/audio_service.dart';
import 'services/iap_service.dart';
import 'services/settings_store.dart';
import 'theme/palette.dart';
import 'theme/physical.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await AudioService.instance.init();
  final settings = SettingsStore();
  await settings.load();
  final store = StoreService();
  // Store init is best-effort and never blocks launch.
  unawaited(store.init());
  runApp(DominoesApp(settings: settings, store: store));
}

class DominoesApp extends StatelessWidget {
  final SettingsStore settings;
  final StoreService store;
  const DominoesApp(
      {super.key, required this.settings, required this.store});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dominoes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: ClubPalette.darkSurface,
        colorScheme: const ColorScheme.dark(
          primary: ClubPalette.brass,
          surface: ClubPalette.darkSurface,
        ),
      ),
      // The whole club is framed by a bevelled walnut bezel (DESIGN.md),
      // dressed in the player's chosen table theme.
      builder: (context, child) => ListenableBuilder(
        listenable: settings,
        builder: (_, _) => WalnutBezel(
          theme: settings.theme,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: SplashScreen(settings: settings, store: store),
    );
  }
}
