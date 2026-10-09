// Procedural audio synthesizer for Dominoes — Club de Dominó Habana.
// Generates all SFX + music loops as 22050 Hz mono 16-bit WAVs into assets/audio/.
// Physical identity: ivory tile clacks, walnut knocks, warm brass chimes,
// soft tungsten-hall ambience. Deterministic (seeded) so builds are reproducible.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int sr = 22050;
final Random rng = Random(1948);

typedef Buf = Float64List;

Buf make(double seconds) => Float64List((seconds * sr).round());

void addSine(Buf b, double freq, double start, double dur, double amp,
    {double decay = 8.0, double attack = 0.004, double detune = 0.0}) {
  final s0 = (start * sr).round(), n = (dur * sr).round();
  for (int i = 0; i < n; i++) {
    final idx = s0 + i;
    if (idx < 0 || idx >= b.length) continue;
    final t = i / sr;
    final env = (1 - exp(-t / max(attack, 1e-4))) * exp(-t * decay);
    b[idx] += amp * env * sin(2 * pi * (freq + detune) * t);
  }
}

/// Warm pluck: decaying harmonic stack (ivory/brass body).
void addPluck(Buf b, double freq, double start, double amp,
    {double dur = 1.2, double brightness = 0.35}) {
  for (int k = 1; k <= 6; k++) {
    addSine(b, freq * k, start, dur, amp * brightness / k,
        decay: 3.0 + k * 1.6, attack: 0.003);
  }
}

/// Filtered noise burst (tile knock transient / felt rub).
void addNoise(Buf b, double start, double dur, double amp,
    {double decay = 60.0, double smooth = 0.25}) {
  final s0 = (start * sr).round(), n = (dur * sr).round();
  double lp = 0;
  for (int i = 0; i < n; i++) {
    final idx = s0 + i;
    if (idx < 0 || idx >= b.length) continue;
    final t = i / sr;
    final w = (rng.nextDouble() * 2 - 1);
    lp += smooth * (w - lp);
    b[idx] += amp * exp(-t * decay) * lp * 2.2;
  }
}

void normalizeBuf(Buf b, double peak) {
  double m = 0;
  for (final v in b) {
    m = max(m, v.abs());
  }
  if (m < 1e-6) return;
  final g = peak / m;
  for (int i = 0; i < b.length; i++) {
    b[i] *= g;
  }
}

void writeWav(String path, Buf b) {
  final n = b.length;
  final bytes = ByteData(44 + n * 2);
  void wstr(int o, String s) {
    for (int i = 0; i < s.length; i++) {
      bytes.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  wstr(0, 'RIFF');
  bytes.setUint32(4, 36 + n * 2, Endian.little);
  wstr(8, 'WAVE');
  wstr(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, sr, Endian.little);
  bytes.setUint32(28, sr * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  wstr(36, 'data');
  bytes.setUint32(40, n * 2, Endian.little);
  for (int i = 0; i < n; i++) {
    final v = (b[i].clamp(-1.0, 1.0) * 32767).round();
    bytes.setInt16(44 + i * 2, v, Endian.little);
  }
  File(path).writeAsBytesSync(bytes.buffer.asUint8List());
  // ignore: avoid_print
  print('wrote $path (${(n / sr).toStringAsFixed(2)}s)');
}

// ------------------------------------------------------------------ SFX ----

Buf sfxClick() {
  final b = make(0.10);
  addNoise(b, 0, 0.02, 0.5, decay: 220, smooth: 0.6);
  addSine(b, 1350, 0, 0.07, 0.28, decay: 55);
  addSine(b, 2020, 0.004, 0.05, 0.12, decay: 70);
  return b..normalize(0.8);
}

/// Ivory tile knock on walnut — the signature placement clack.
Buf sfxTileClack() {
  final b = make(0.30);
  addNoise(b, 0, 0.02, 0.65, decay: 160, smooth: 0.35);
  addSine(b, 185, 0, 0.24, 0.85, decay: 17);
  addSine(b, 342, 0, 0.18, 0.34, decay: 24);
  addSine(b, 92, 0, 0.28, 0.5, decay: 11);
  return b..normalize(0.85);
}

/// Deeper thock for doubles / spinner placement.
Buf sfxTilePlace() {
  final b = make(0.38);
  addNoise(b, 0, 0.025, 0.55, decay: 120, smooth: 0.3);
  addSine(b, 128, 0, 0.32, 0.9, decay: 13);
  addSine(b, 256, 0, 0.22, 0.32, decay: 19);
  addSine(b, 512, 0.002, 0.10, 0.14, decay: 40);
  return b..normalize(0.85);
}

/// Handful of tiles shuffled on felt.
Buf sfxShuffle() {
  final b = make(0.85);
  addNoise(b, 0, 0.8, 0.10, decay: 2.2, smooth: 0.12);
  for (int i = 0; i < 11; i++) {
    final t = 0.03 + rng.nextDouble() * 0.68;
    final s = 0.22 + rng.nextDouble() * 0.25;
    addNoise(b, t, 0.015, 0.4 * s, decay: 150, smooth: 0.4);
    addSine(b, 170 + rng.nextDouble() * 90, t, 0.12, 0.5 * s, decay: 22);
  }
  return b..normalize(0.8);
}

Buf sfxDrawTick() {
  final b = make(0.14);
  addNoise(b, 0, 0.012, 0.35, decay: 200, smooth: 0.5);
  addSine(b, 880, 0, 0.10, 0.30, decay: 32);
  return b..normalize(0.75);
}

Buf sfxInvalid() {
  final b = make(0.36);
  addSine(b, 108, 0, 0.30, 0.55, decay: 9);
  addSine(b, 162, 0.02, 0.26, 0.30, decay: 10);
  addSine(b, 96, 0.14, 0.20, 0.45, decay: 10);
  return b..normalize(0.8);
}

/// Brass rivet ping + knock for spinner (double) placement.
Buf sfxSpinner() {
  final b = make(0.5);
  addNoise(b, 0, 0.02, 0.55, decay: 150, smooth: 0.35);
  addSine(b, 185, 0, 0.24, 0.7, decay: 17);
  addSine(b, 2430, 0.005, 0.30, 0.20, decay: 26);
  addSine(b, 3310, 0.008, 0.24, 0.14, decay: 30);
  addSine(b, 128, 0, 0.3, 0.4, decay: 12);
  return b..normalize(0.82);
}

/// Warm brass chime — round start.
Buf sfxRoundStart() {
  final b = make(1.0);
  addPluck(b, 329.63, 0.0, 0.55); // E4
  addPluck(b, 493.88, 0.18, 0.5); // B4
  addPluck(b, 659.26, 0.36, 0.5); // E5
  addSine(b, 1318.5, 0.36, 0.5, 0.08, decay: 6);
  return b..normalize(0.8);
}

/// Victory arpeggio on the club piano.
Buf sfxWin() {
  final b = make(2.0);
  const seq = [261.63, 329.63, 392.0, 523.25, 659.26];
  for (int i = 0; i < seq.length; i++) {
    addPluck(b, seq[i], i * 0.16, 0.55, dur: 1.4);
  }
  addSine(b, 2093, 0.8, 0.9, 0.05, decay: 4);
  addSine(b, 1568, 0.96, 0.8, 0.06, decay: 4);
  return b..normalize(0.8);
}

/// Low descending phrase — match lost.
Buf sfxLose() {
  final b = make(1.6);
  const seq = [220.0, 174.61, 146.83];
  for (int i = 0; i < seq.length; i++) {
    addPluck(b, seq[i], i * 0.34, 0.5, dur: 1.1, brightness: 0.22);
  }
  addSine(b, 73.4, 1.0, 0.5, 0.25, decay: 5);
  return b..normalize(0.8);
}

// ----------------------------------------------------------------- music ---

/// Seamless warm pad loop. [chords] cycle, each [seg] seconds.
Buf musicLoop(List<List<double>> chords, double seg,
    {List<double>? pluckScale, double pluckEvery = 1.6, double tickEvery = 0}) {
  final total = seg * chords.length;
  final b = make(total);
  const fade = 2.0;
  for (int c = 0; c < chords.length; c++) {
    final chord = chords[c];
    final segStart = c * seg - fade;
    final segDur = seg + fade * 2;
    for (final f in chord) {
      // periodic raised-cosine envelope over the whole loop
      final s0 = (segStart * sr).round(), n = (segDur * sr).round();
      for (int i = 0; i < n; i++) {
        int idx = (s0 + i) % b.length;
        if (idx < 0) idx += b.length;
        final t = i / sr;
        double env;
        if (t < fade) {
          env = 0.5 - 0.5 * cos(pi * t / fade);
        } else if (t > segDur - fade) {
          env = 0.5 - 0.5 * cos(pi * (segDur - t) / fade);
        } else {
          env = 1.0;
        }
        // gentle slow swell so the pad breathes
        env *= 0.85 + 0.15 * sin(2 * pi * (idx / sr) / 7.0);
        b[idx] += 0.11 * env * sin(2 * pi * f * (idx / sr));
        b[idx] += 0.045 * env * sin(2 * pi * f * 2 * (idx / sr));
      }
    }
    // soft bass root
    final root = chord[0] / 2;
    final s0 = (segStart * sr).round(), n = (segDur * sr).round();
    for (int i = 0; i < n; i++) {
      int idx = (s0 + i) % b.length;
      if (idx < 0) idx += b.length;
      final t = i / sr;
      double env;
      if (t < fade) {
        env = 0.5 - 0.5 * cos(pi * t / fade);
      } else if (t > segDur - fade) {
        env = 0.5 - 0.5 * cos(pi * (segDur - t) / fade);
      } else {
        env = 1.0;
      }
      b[idx] += 0.09 * env * sin(2 * pi * root * (idx / sr));
    }
  }
  if (pluckScale != null) {
    double t = pluckEvery * 0.5;
    int k = 0;
    while (t < total - 1.0) {
      final f = pluckScale[(k * 5 + 3) % pluckScale.length];
      addPluck(b, f, t, 0.10, dur: 1.6, brightness: 0.25);
      t += pluckEvery * (0.8 + 0.4 * ((k * 37) % 5) / 4);
      k++;
    }
  }
  if (tickEvery > 0) {
    // soft felt tick under the music, like a distant clock in the hall
    double t = 0;
    while (t < total) {
      addNoise(b, t, 0.03, 0.05, decay: 120, smooth: 0.2);
      addSine(b, 320, t, 0.05, 0.03, decay: 60);
      t += tickEvery;
    }
  }
  return b..normalize(0.5);
}

void main() {
  final dir = Directory('assets/audio');
  dir.createSync(recursive: true);
  final out = dir.path;

  writeWav('$out/ui_click.wav', sfxClick());
  writeWav('$out/tile_clack.wav', sfxTileClack());
  writeWav('$out/tile_place.wav', sfxTilePlace());
  writeWav('$out/tile_shuffle.wav', sfxShuffle());
  writeWav('$out/draw_tick.wav', sfxDrawTick());
  writeWav('$out/invalid.wav', sfxInvalid());
  writeWav('$out/spinner.wav', sfxSpinner());
  writeWav('$out/round_start.wav', sfxRoundStart());
  writeWav('$out/win.wav', sfxWin());
  writeWav('$out/lose.wav', sfxLose());

  // Am — F — C — G : warm club ambience for the menu
  writeWav(
      '$out/menu_music.wav',
      musicLoop([
        [220.0, 261.63, 329.63], // Am
        [174.61, 220.0, 261.63], // F
        [130.81, 164.81, 196.0], // C (low voicing)
        [196.0, 246.94, 293.66], // G
      ], 6.0,
          pluckScale: [440.0, 523.25, 587.33, 659.26, 783.99, 880.0],
          pluckEvery: 2.1));

  // Em — C — G — D : slightly more motion for gameplay
  writeWav(
      '$out/game_music.wav',
      musicLoop([
        [164.81, 196.0, 246.94], // Em
        [130.81, 164.81, 196.0], // C
        [196.0, 246.94, 293.66], // G
        [146.83, 184.99, 220.0], // D
      ], 5.0,
          pluckScale: [329.63, 392.0, 440.0, 493.88, 587.33, 659.26],
          pluckEvery: 1.5,
          tickEvery: 60.0 / 92));

  // ignore: avoid_print
  print('done.');
}

extension _Norm on Buf {
  void normalize(double peak) => normalizeBuf(this, peak);
}
