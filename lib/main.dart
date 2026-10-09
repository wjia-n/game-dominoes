import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/audio_service.dart';
import 'services/settings_store.dart';
import 'theme/palette.dart';
import 'theme/physical.dart';
import 'screens/menu_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await AudioService.instance.init();
  final settings = SettingsStore();
  await settings.load();
  runApp(DominoesApp(settings: settings));
}

class DominoesApp extends StatelessWidget {
  final SettingsStore settings;
  const DominoesApp({super.key, required this.settings});

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
      // The whole club is framed by a bevelled walnut bezel (DESIGN.md).
      builder: (context, child) =>
          WalnutBezel(child: child ?? const SizedBox.shrink()),
      home: MenuScreen(settings: settings),
    );
  }
}
