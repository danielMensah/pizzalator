import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/make_ding.dart';

void main() {
  test('the committed chime is what tool/make_ding.dart writes', () {
    final file = File(dingPath).readAsBytesSync();
    final made = ding();
    expect(file.length, made.length);
    final a = ByteData.sublistView(file), b = ByteData.sublistView(made);
    // Header exactly; samples to within rounding across platforms' sin/exp.
    expect(file.sublist(0, 44), made.sublist(0, 44));
    for (var i = 44; i < file.length; i += 2) {
      final d = a.getInt16(i, Endian.little) - b.getInt16(i, Endian.little);
      if (d.abs() > 1) fail('sample ${(i - 44) ~/ 2} differs by $d');
    }
  });

  test('three strikes, 8 s of 22.05 kHz mono 16-bit PCM, never clipping', () {
    final w = ByteData.sublistView(ding());
    String tag(int at) => String.fromCharCodes(w.buffer.asUint8List(at, 4));
    expect(
      [tag(0), tag(8), tag(12), tag(36)],
      ['RIFF', 'WAVE', 'fmt ', 'data'],
    );
    expect(w.getUint16(20, Endian.little), 1, reason: 'PCM');
    expect(w.getUint16(22, Endian.little), 1, reason: 'mono');
    expect(w.getUint32(24, Endian.little), 22050);
    expect(w.getUint16(34, Endian.little), 16);
    final n = w.getUint32(40, Endian.little) ~/ 2;
    expect(n, 8 * 22050);
    expect(w.getUint32(4, Endian.little), 36 + n * 2);
    int peak(double from, double to) {
      var p = 0;
      for (var i = (from * 22050).round(); i < (to * 22050).round(); i++) {
        final v = w.getInt16(44 + i * 2, Endian.little).abs();
        if (v > p) p = v;
      }
      return p;
    }

    final loud = peak(0, 8);
    expect(loud, inInclusiveRange(20000, 32000));
    // Each strike starts loud, its tail dies away before the next.
    for (final t in [0.0, 2.8, 5.6]) {
      expect(peak(t, t + 0.1), greaterThan(loud * 0.8), reason: 'strike $t');
      expect(peak(t + 2, t + 2.3), lessThan(loud * 0.15), reason: 'tail $t');
    }
    expect(peak(7.95, 8), lessThan(loud * 0.01), reason: 'fades, no click');
  });
}
