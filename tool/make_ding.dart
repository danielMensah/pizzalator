// Writes the timer chime, android/app/src/main/res/raw/timer_ding.wav: three
// bell strikes like a kitchen timer's ding, 8 s, 22.05 kHz mono 16-bit PCM.
// Usage: dart run tool/make_ding.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const dingPath = 'android/app/src/main/res/raw/timer_ding.wav';
const _rate = 22050;
const _seconds = 8;
const _strikes = [0.0, 2.8, 5.6];

/// (Hz, level, decay in s): a bright fundamental and two inharmonic
/// overtones that die away faster, as on a struck bell.
const _partials = [
  (1760.0, 1.0, 0.7),
  (4110.0, 0.35, 0.3),
  (7350.0, 0.12, 0.15),
];

Uint8List ding() {
  const n = _rate * _seconds;
  final s = Float64List(n);
  for (final strike in _strikes) {
    final first = (strike * _rate).round();
    for (var i = first; i < n; i++) {
      final t = (i - first) / _rate;
      final attack = min(1.0, t / 0.002);
      for (final (hz, level, decay) in _partials) {
        s[i] += attack * level * exp(-t / decay) * sin(2 * pi * hz * t);
      }
    }
  }
  // The last 0.3 s fade out: a cut-off tail clicks.
  const fade = _rate * 3 ~/ 10;
  for (var i = n - fade; i < n; i++) {
    s[i] *= (n - i) / fade;
  }
  final peak = s.fold(0.0, (m, x) => max(m, x.abs()));
  final w = ByteData(44 + n * 2);
  void tag(int at, String id) {
    for (var k = 0; k < 4; k++) {
      w.setUint8(at + k, id.codeUnitAt(k));
    }
  }

  const le = Endian.little;
  tag(0, 'RIFF');
  w.setUint32(4, 36 + n * 2, le);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  w
    ..setUint32(16, 16, le) // fmt chunk size
    ..setUint16(20, 1, le) // PCM
    ..setUint16(22, 1, le) // mono
    ..setUint32(24, _rate, le)
    ..setUint32(28, _rate * 2, le) // bytes per second
    ..setUint16(32, 2, le) // bytes per sample
    ..setUint16(34, 16, le);
  tag(36, 'data');
  w.setUint32(40, n * 2, le);
  for (var i = 0; i < n; i++) {
    w.setInt16(44 + i * 2, (s[i] / peak * 0.8 * 32767).round(), le);
  }
  return w.buffer.asUint8List();
}

void main() => File(dingPath)
  ..parent.createSync(recursive: true)
  ..writeAsBytesSync(ding());
