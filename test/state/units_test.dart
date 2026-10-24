import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pizzalator/state/units.dart';

void main() {
  test('sizes start in cm and toggle to inches and back', () {
    final c = ProviderContainer.test();
    expect(c.read(lengthUnitProvider), LengthUnit.cm);
    c.read(lengthUnitProvider.notifier).toggle();
    expect(c.read(lengthUnitProvider), LengthUnit.inch);
    c.read(lengthUnitProvider.notifier).toggle();
    expect(c.read(lengthUnitProvider), LengthUnit.cm);
  });

  test('converts to and from cm', () {
    expect(LengthUnit.cm.fromCm(30), 30);
    expect(LengthUnit.cm.toCm(30), 30);
    expect(LengthUnit.inch.toCm(12), closeTo(30.48, 1e-9));
    expect(LengthUnit.inch.fromCm(35.56), closeTo(14, 1e-9));
    expect([LengthUnit.cm.label, LengthUnit.inch.label], ['cm', 'in']);
  });
}
