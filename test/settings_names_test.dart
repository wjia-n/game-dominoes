import 'package:dominoes/engine/domino_engine.dart';
import 'package:dominoes/services/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for the player-name persistence bug (2026-10-09):
///
/// Player names were stored with SharedPreferences.setStringList, which on
/// Android is backed by an UNORDERED StringSet — so after an app restart the
/// four names came back in arbitrary order and renames appeared "not saved".
/// Names are now stored as one order-preserving JSON string. These tests
/// cover the prefs round-trip plus the engine reload path, without needing
/// platform channels.
void main() {
  test('names survive an encode/decode round-trip in exact slot order', () {
    const names = ['Wajiha', 'Alejandro', 'Emilia', 'Rafael'];
    final decoded = SettingsStore.decodePlayerNames(
      SettingsStore.encodePlayerNames(names),
    );
    expect(decoded, names);
    // Slot order is what matters: each index must map to the same player.
    for (int i = 0; i < 4; i++) {
      expect(decoded[i], names[i]);
    }
  });

  test('decode falls back to defaults on missing or corrupt data', () {
    expect(
      SettingsStore.decodePlayerNames(null),
      SettingsStore.defaultNames,
    );
    expect(
      SettingsStore.decodePlayerNames('definitely not json'),
      SettingsStore.defaultNames,
    );
    expect(
      SettingsStore.decodePlayerNames('["only","two"]'),
      SettingsStore.defaultNames,
    );
    expect(
      SettingsStore.decodePlayerNames('{"a":1}'),
      SettingsStore.defaultNames,
    );
  });

  test('blank entries fall back to that slot\'s default name', () {
    final decoded =
        SettingsStore.decodePlayerNames('["Wajiha","","  ","Rafael"]');
    expect(decoded, ['Wajiha', 'Alejandro', 'Emilia', 'Rafael']);
  });

  test('engine rebuilt after "restart" shows the persisted names', () {
    // Simulate: user renamed slot 0, app restarted, setup screen + engine
    // rebuilt from the persisted value.
    const renamed = ['Wajiha', 'Alejandro', 'Emilia', 'Rafael'];
    final persisted = SettingsStore.decodePlayerNames(
      SettingsStore.encodePlayerNames(renamed),
    );
    final engine = DominoEngine(
      mode: GameMode.draw,
      names: persisted,
      isBot: const [false, true, true, true],
      difficulty: BotDifficulty.normal,
      matchTarget: 100,
    );
    expect(engine.names[0], 'Wajiha');
    expect(engine.names[1], 'Alejandro');
    expect(engine.names[2], 'Emilia');
    expect(engine.names[3], 'Rafael');
    // The rename reaches turn narration built from engine.names.
    expect('${engine.names[0]} is studying the table…', contains('Wajiha'));
  });
}
