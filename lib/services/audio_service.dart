import 'package:audioplayers/audioplayers.dart';

/// Club-hall audio: procedural ivory-tile clacks, walnut knocks, brass chimes
/// and warm ambient music loops (all synthesized, see tool/gen_audio.dart).
class AudioService {
  static final AudioService instance = AudioService._();
  AudioService._();

  final List<AudioPlayer> _sfxPool = [];
  int _cursor = 0;
  final AudioPlayer _music = AudioPlayer();
  bool _ready = false;

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  String? _track; // currently loaded music asset

  Future<void> init() async {
    if (_ready) return;
    try {
      for (int i = 0; i < 5; i++) {
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

  Future<void> _applyVolumes() async {
    for (final p in _sfxPool) {
      await p.setVolume(sfxOn ? volume : 0.0);
    }
    await _music.setVolume(musicOn ? volume * 0.55 : 0.0);
  }

  Future<void> setVolumes(
      {bool? music, bool? sfx, double? volume}) async {
    if (music != null) musicOn = music;
    if (sfx != null) sfxOn = sfx;
    if (volume != null) this.volume = volume;
    if (!_ready) return;
    await _applyVolumes();
    if (!musicOn) {
      await _music.pause();
    } else if (_track != null) {
      await _music.resume();
    }
  }

  Future<void> _playSfx(String file, {double atVolume = 1.0}) async {
    if (!_ready || !sfxOn) return;
    try {
      final p = _sfxPool[_cursor++ % _sfxPool.length];
      await p.setVolume(volume * atVolume);
      await p.play(AssetSource('audio/$file'));
    } catch (_) {}
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

  Future<void> _playTrack(String file) async {
    if (!_ready) return;
    if (_track == file) {
      if (musicOn) {
        try {
          await _music.resume();
        } catch (_) {}
      }
      return;
    }
    _track = file;
    try {
      await _music.stop();
      await _music.setVolume(musicOn ? volume * 0.55 : 0.0);
      await _music.play(AssetSource('audio/$file'));
    } catch (_) {}
  }

  Future<void> pauseMusic() async {
    if (!_ready) return;
    try {
      await _music.pause();
    } catch (_) {}
  }

  Future<void> resumeMusic() async {
    if (!_ready || !musicOn || _track == null) return;
    try {
      await _music.resume();
    } catch (_) {}
  }
}
