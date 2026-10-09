# Dominoes — Club de Dominó Habana

Classic double-six dominoes in a vintage Havana social club: ivory tiles with
brass spinners on green baize felt, dark walnut rails, warm tungsten lamplight.

- **Modes:** Draw (boneyard) & Block, 2–4 players, pass-and-play or vs bots
- **Rules:** highest double opens; doubles are crosswise spinners whose arms
  must be satisfied before the chain continues; raw pip scoring; match target
  100/150/200 (see `../stitch-batch2/dominoes/RULES.md` — authoritative)
- **Art direction:** `../stitch-batch2/dominoes/DESIGN.md` ("Club de Dominó
  Habana" Stitch design system) — pseudo-3D physical materials, no neon
- **Audio:** fully procedural — tile clacks, brass chimes, ambient hall music
  loops, synthesized by `tool/gen_audio.dart` into `assets/audio/`
- **Tests:** `flutter test` — 22 engine tests covering the RULES.md test cases

## Project layout

```
lib/
  main.dart            app entry, walnut bezel frame, portrait lock
  theme/               ClubPalette/ClubType tokens + physical material
                       painters (felt, ivory tile, brass, walnut) & widgets
  engine/              pure-Dart rules engine (modes, spinners, scoring,
                       Easy/Normal/Hard bots, JSON serialization)
                       + serpentine chain layout (never clips)
  services/            audio_service (audioplayers), settings_store &
                       save_store (shared_preferences)
  screens/             menu, board, game-over, settings, pause overlay
assets/
  audio/               12 synthesized WAVs (SFX + 2 seamless music loops)
  fonts/               Libre Caslon Text, EB Garamond, Space Grotesk
tool/
  gen_audio.dart       deterministic audio synthesizer (Dart, no deps)
```

## Build

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release   # CI signs with the upload keystore
```

Package: `com.gameswajiha.dominoes`
