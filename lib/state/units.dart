import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/presets.dart';

export '../core/presets.dart' show LengthUnit;

final lengthUnitProvider = NotifierProvider<LengthUnitNotifier, LengthUnit>(
  LengthUnitNotifier.new,
);

class LengthUnitNotifier extends Notifier<LengthUnit> {
  @override
  LengthUnit build() => LengthUnit.cm;

  void toggle() =>
      state = state == LengthUnit.cm ? LengthUnit.inch : LengthUnit.cm;
}
