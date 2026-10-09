import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/domino_engine.dart';
import '../theme/club_themes.dart';
import 'audio_service.dart';

/// Persisted club preferences: music/SFX toggles, volume, bot difficulty,
/// match target score, renameable player names (every slot), theme / tile
/// style / table accent picks, the custom theme, and Pro status.
class SettingsStore extends ChangeNotifier {
  static const _kMusic = 'dominoes.music';
  static const _kSfx = 'dominoes.sfx';
  static const _kVolume = 'dominoes.volume';
  static const _kDifficulty = 'dominoes.difficulty';
  static const _kTarget = 'dominoes.target';
  static const _kNames = 'dominoes.names'; // legacy unordered StringSet key
  /// Order-safe player-name storage: a single JSON string. Android's
  /// SharedPreferences stores StringLists as an unordered StringSet, so the
  /// old key scrambled name order on every app restart. Never use a
  /// StringList for ordered data on Android.
  static const _kNamesJson = 'dominoes_player_names_json';
  static const _kTheme = 'dominoes.theme';
  static const _kTileStyle = 'dominoes.tilestyle';
  static const _kAccent = 'dominoes.accent';
  static const _kCustom = 'dominoes.customtheme';
  static const _kPro = 'dominoes.pro';

  static const List<String> defaultNames = [
    'You',
    'Alejandro',
    'Emilia',
    'Rafael',
  ];

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  /// Encode the 4 player names as one JSON string (order-preserving).
  static String encodePlayerNames(List<String> names) => jsonEncode(names);

  static String _cleanName(int i, Object? v) {
    final s = v is String ? v.trim() : '';
    return s.isEmpty ? defaultNames[i] : s;
  }

  /// Decode persisted names; falls back to defaults on missing/corrupt data.
  static List<String> decodePlayerNames(String? raw) {
    if (raw == null) return List.of(defaultNames);
    try {
      final d = jsonDecode(raw);
      if (d is List && d.length == 4) {
        return [for (int i = 0; i < 4; i++) _cleanName(i, d[i])];
      }
    } catch (_) {}
    return List.of(defaultNames);
  }

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  BotDifficulty difficulty = BotDifficulty.normal;
  int matchTarget = 100;
  List<String> playerNames = List.of(defaultNames);
  String themeId = 'habana';
  String tileStyleId = 'hueso';
  String tableAccentId = 'laton';
  CustomClubTheme? customTheme;
  bool pro = false;

  ClubThemeDef get theme =>
      ClubThemes.byId(themeId, custom: customTheme);
  TileStyleDef get tileStyle => TileStyles.byId(tileStyleId);
  TableAccentDef get tableAccent => TableAccents.byId(tableAccentId);

  /// True when the given cosmetic is usable (free, or Pro unlocked).
  bool unlocked({required bool isProItem}) => pro || !isProItem;

  Future<void> load() async {
    musicOn = await _prefs.getBool(_kMusic) ?? true;
    sfxOn = await _prefs.getBool(_kSfx) ?? true;
    volume = await _prefs.getDouble(_kVolume) ?? 0.8;
    difficulty =
        BotDifficulty.values[(await _prefs.getInt(_kDifficulty)) ?? 1];
    matchTarget = await _prefs.getInt(_kTarget) ?? 100;
    // Player names: prefer the order-safe JSON key. Fall back to the legacy
    // StringList key once (one-time migration); it may already be scrambled
    // on Android, which is exactly the bug this replaces.
    final namesRaw = await _prefs.getString(_kNamesJson);
    if (namesRaw != null) {
      playerNames = decodePlayerNames(namesRaw);
    } else {
      final legacy = await _prefs.getStringList(_kNames);
      playerNames = (legacy != null && legacy.length == 4)
          ? [for (int i = 0; i < 4; i++) _cleanName(i, legacy[i])]
          : List.of(defaultNames);
      // Persist through the new key immediately and drop the legacy one.
      await _prefs.setString(_kNamesJson, encodePlayerNames(playerNames));
      await _prefs.remove(_kNames);
    }
    themeId = await _prefs.getString(_kTheme) ?? 'habana';
    tileStyleId = await _prefs.getString(_kTileStyle) ?? 'hueso';
    tableAccentId = await _prefs.getString(_kAccent) ?? 'laton';
    final customJson = await _prefs.getString(_kCustom);
    if (customJson != null) {
      try {
        customTheme = CustomClubTheme.fromJson(
            Map<String, dynamic>.from(jsonDecode(customJson) as Map));
      } catch (_) {
        customTheme = null;
      }
    }
    pro = await _prefs.getBool(_kPro) ?? false;
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

  Future<void> setPlayerName(int slot, String name) async {
    final clean = name.trim().isEmpty ? defaultNames[slot] : name.trim();
    playerNames[slot] = clean;
    await _prefs.setString(_kNamesJson, encodePlayerNames(playerNames));
    await _prefs.remove(_kNames); // drop the legacy unordered key for good
    notifyListeners();
  }

  Future<void> setThemeId(String id) async {
    themeId = id;
    await _prefs.setString(_kTheme, id);
    notifyListeners();
  }

  Future<void> setTileStyleId(String id) async {
    tileStyleId = id;
    await _prefs.setString(_kTileStyle, id);
    notifyListeners();
  }

  Future<void> setTableAccentId(String id) async {
    tableAccentId = id;
    await _prefs.setString(_kAccent, id);
    notifyListeners();
  }

  Future<void> setCustomTheme(CustomClubTheme? c) async {
    customTheme = c;
    if (c == null) {
      await _prefs.remove(_kCustom);
    } else {
      await _prefs.setString(_kCustom, jsonEncode(c.toJson()));
    }
    notifyListeners();
  }

  Future<void> setPro(bool v) async {
    pro = v;
    await _prefs.setBool(_kPro, v);
    notifyListeners();
  }
}
