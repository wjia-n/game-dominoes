import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/domino_engine.dart';

/// Mid-round persistence (RULES T15): the full engine state serializes to
/// shared_preferences so a game survives backgrounding and restarts.
class SaveStore {
  static const _kSave = 'dominoes.save.v1';
  static const _kMeta = 'dominoes.save.meta';

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  Future<void> save(DominoEngine e) async {
    if (e.matchOver || e.roundOver) {
      // Nothing resumable: a finished round/match clears the save.
      await clear();
      return;
    }
    await _prefs.setString(_kSave, jsonEncode(e.toJson()));
    await _prefs.setString(
        _kMeta,
        jsonEncode({
          'at': DateTime.now().toIso8601String(),
          'round': e.round,
          'mode': e.mode.index,
          'players': e.names,
        }));
  }

  Future<DominoEngine?> load() async {
    final raw = await _prefs.getString(_kSave);
    if (raw == null) return null;
    try {
      return DominoSave.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> meta() async {
    final raw = await _prefs.getString(_kMeta);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasSave() async => (await _prefs.getString(_kSave)) != null;

  Future<void> clear() async {
    await _prefs.remove(_kSave);
    await _prefs.remove(_kMeta);
  }
}
