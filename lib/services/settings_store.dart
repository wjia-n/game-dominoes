import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/domino_engine.dart';
import 'audio_service.dart';

/// Persisted club preferences: music/SFX toggles, volume, bot difficulty,
/// match target score.
class SettingsStore extends ChangeNotifier {
  static const _kMusic = 'dominoes.music';
  static const _kSfx = 'dominoes.sfx';
  static const _kVolume = 'dominoes.volume';
  static const _kDifficulty = 'dominoes.difficulty';
  static const _kTarget = 'dominoes.target';

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  BotDifficulty difficulty = BotDifficulty.normal;
  int matchTarget = 100;

  Future<void> load() async {
    musicOn = await _prefs.getBool(_kMusic) ?? true;
    sfxOn = await _prefs.getBool(_kSfx) ?? true;
    volume = await _prefs.getDouble(_kVolume) ?? 0.8;
    difficulty =
        BotDifficulty.values[(await _prefs.getInt(_kDifficulty)) ?? 1];
    matchTarget = await _prefs.getInt(_kTarget) ?? 100;
    await AudioService.instance
        .setVolumes(music: musicOn, sfx: sfxOn, volume: volume);
    notifyListeners();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    await _prefs.setBool(_kMusic, v);
    await AudioService.instance.setVolumes(music: v);
    notifyListeners();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    await _prefs.setBool(_kSfx, v);
    await AudioService.instance.setVolumes(sfx: v);
    notifyListeners();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    await _prefs.setDouble(_kVolume, volume);
    await AudioService.instance.setVolumes(volume: volume);
    notifyListeners();
  }

  Future<void> setDifficulty(BotDifficulty d) async {
    difficulty = d;
    await _prefs.setInt(_kDifficulty, d.index);
    notifyListeners();
  }

  Future<void> setMatchTarget(int t) async {
    matchTarget = t;
    await _prefs.setInt(_kTarget, t);
    notifyListeners();
  }
}
