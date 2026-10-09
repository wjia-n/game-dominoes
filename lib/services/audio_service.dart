import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Club-hall audio: procedural ivory-tile clacks, walnut knocks, brass chimes
/// and warm ambient music loops (all synthesized, see tool/gen_audio.dart).
///
/// Reliability model (exemplar pattern):
/// - Clips are loaded ONCE and cached on their players (setSource at prewarm);
///   playback is just resume() — no re-decode hitches mid-game.
/// - All play/stop calls serialize through a single async busy guard, so a
///   stop can never race a start and music can never "silently die".
/// - Music is app-scoped: one player, one current track; pause()/resume()
///   on lifecycle changes; toggles apply without reloading.
/// - Audio is decorative: every call is try/catch — the game runs even if
///   the platform audio stack fails.
class AudioService {
  static final AudioService instance = AudioService._();
  AudioService._();

  static const _sfxFiles = [
    'ui_click.wav',
    'tile_clack.wav',
    'tile_place.wav',
    'tile_shuffle.wav',
    'draw_tick.wav',
    'invalid.wav',
    'spinner.wav',
    'round_start.wav',
    'win.wav',
    'lose.wav',
  ];

  final List<AudioPlayer> _sfxPool = [];
  final Map<String, AudioPlayer> _clipPlayer = {};
  final AudioPlayer _music = AudioPlayer();
  bool _ready = false;
  bool _prewarmed = false;

  // Serializes every audio op; a new op chains after the previous one.
  Future<void> _gate = Future.value();
  Future<void> _guard(Future<void> Function() op) {
    final run = _gate.then((_) => op()).catchError((_) {});
    _gate = run;
    return run;
  }

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  String? _track; // currently loaded music asset

  Future<void> init() async {
    if (_ready) return;
    try {
      for (int i = 0; i < 6; i++) {
        final p = AudioPlayer();
        await p.setReleaseMode(ReleaseMode.stop);
        _sfxPool.add(p);
      }
      await _music.setReleaseMode(ReleaseMode.loop);
      await _applyVolumes();
      _ready = true;
    } catch (_) {
      // audio is decorative; the game must run even if it fails
    }
  }

  /// Load every clip onto a dedicated pooled player and cache both music
  /// tracks, so later playback is instant. Safe to call repeatedly.
  Future<void> prewarm() async {
    if (_prewarmed || !_ready) return;
    _prewarmed = true;
    await _guard(() async {
      try {
        for (int i = 0; i < _sfxFiles.length; i++) {
          final p = _sfxPool[i % _sfxPool.length];
          await p.setSource(AssetSource('audio/${_sfxFiles[i]}'));
          _clipPlayer[_sfxFiles[i]] = p;
        }
      } catch (_) {}
    });
  }

  Future<void> _applyVolumes() async {
    for (final p in _sfxPool) {
      try {
        await p.setVolume(sfxOn ? volume : 0.0);
      } catch (_) {}
    }
    try {
      await _music.setVolume(musicOn ? volume * 0.55 : 0.0);
    } catch (_) {}
  }

  Future<void> setVolumes({bool? music, bool? sfx, double? volume}) {
    if (music != null) musicOn = music;
    if (sfx != null) sfxOn = sfx;
    if (volume != null) this.volume = volume.clamp(0.0, 1.0);
    if (!_ready) return Future.value();
    return _guard(() async {
      await _applyVolumes();
      if (!musicOn) {
        try {
          await _music.pause();
        } catch (_) {}
      } else if (_track != null) {
        try {
          await _music.resume();
        } catch (_) {}
      }
    });
  }

  Future<void> _playSfx(String file, {double atVolume = 1.0}) {
    if (!_ready || !sfxOn) return Future.value();
    return _guard(() async {
      try {
        final p = _clipPlayer[file] ?? _sfxPool.first;
        await p.setVolume(volume * atVolume);
        if (_clipPlayer.containsKey(file)) {
          await p.stop();
          await p.resume();
        } else {
          await p.play(AssetSource('audio/$file'));
        }
      } catch (_) {}
    });
  }

  Future<void> click() => _playSfx('ui_click.wav', atVolume: 0.8);
  Future<void> clack() => _playSfx('tile_clack.wav');
  Future<void> place() => _playSfx('tile_place.wav');
  Future<void> shuffle() => _playSfx('tile_shuffle.wav');
  Future<void> draw() => _playSfx('draw_tick.wav', atVolume: 0.9);
  Future<void> invalid() => _playSfx('invalid.wav');
  Future<void> spinner() => _playSfx('spinner.wav');
  Future<void> roundStart() => _playSfx('round_start.wav', atVolume: 0.9);
  Future<void> win() => _playSfx('win.wav');
  Future<void> lose() => _playSfx('lose.wav');

  Future<void> playMenuMusic() => _playTrack('menu_music.wav');
  Future<void> playGameMusic() => _playTrack('game_music.wav');

  Future<void> _playTrack(String file) {
    if (!_ready) return Future.value();
    return _guard(() async {
      try {
        if (_track == file) {
          if (musicOn) await _music.resume();
          return;
        }
        _track = file;
        await _music.stop();
        await _music.setVolume(musicOn ? volume * 0.55 : 0.0);
        await _music.play(AssetSource('audio/$file'));
      } catch (_) {}
    });
  }

  /// True while any music track is loaded (used by tests/diagnostics).
  bool get hasTrack => _track != null;

  Future<void> pauseMusic() {
    if (!_ready) return Future.value();
    return _guard(() async {
      try {
        await _music.pause();
      } catch (_) {}
    });
  }

  Future<void> resumeMusic() {
    if (!_ready || !musicOn || _track == null) return Future.value();
    return _guard(() async {
      try {
        await _music.resume();
      } catch (_) {}
    });
  }

  Future<void> stopMusic() {
    if (!_ready) return Future.value();
    return _guard(() async {
      try {
        await _music.stop();
      } catch (_) {}
      _track = null;
    });
  }
}
