import 'package:flutter_test/flutter_test.dart';
import 'package:pizzalator/core/presets.dart';
import 'package:pizzalator/core/routine.dart';

void main() {
  const coldPlan = [Stage(2, 20), Stage(24, 4)];
  const sameDayPlan = [Stage(4, 22), Stage(2, 22)];
  final bulk = defaultRoutine.steps[9];

  group('defaultRoutine', () {
    test('is the 11 steps of PRD 4.7', () {
      final s = defaultRoutine.steps;
      expect(s.map((x) => x.name), [
        'Mix all ingredients',
        'Rest in bowl, covered',
        'Fold in bowl 4–6×',
        'Rest, covered',
        'Fold in bowl again',
        'Rest, covered',
        'Knead on the counter',
        'Rest on counter, covered',
        'Stretch, fold, shape one ball',
        'Bulk in container',
        'Divide into balls',
      ]);
      expect(s.map((x) => x.minutes), [5, 30, 2, 15, 2, 15, 10, 30, 5, 240, 5]);
      expect(s.map((x) => x.kind == StepKind.rest), [
        false,
        true,
        false,
        true,
        false,
        true,
        false,
        true,
        false,
        true,
        false,
      ]);
      expect(s[0].note, startsWith('Water, yeast, sugar, flour'));
      expect(s[6].note, 'Timed active step');
      expect(s[2].note, isEmpty);
      expect(s.where((x) => x.bindsToPlan), [bulk]);
      expect(defaultRoutine.builtIn, isTrue);
    });
  });

  group('stepDuration', () {
    test('unbound step uses its own minutes, whatever the plan', () {
      expect(
        stepDuration(defaultRoutine.steps[6], coldPlan),
        const Duration(minutes: 10),
      );
    });

    test('bound step on a cold plan: room bulk, then the fridge', () {
      // Bulk in the container, then into the fridge, then divide (PRD §4.7).
      expect(stepDuration(bulk, coldPlan), const Duration(hours: 26));
      expect(
        stepDuration(bulk, const [Stage(1, 20), Stage(24, 4), Stage(24, 5)]),
        const Duration(hours: 49),
      );
      expect(
        stepDuration(bulk, const [Stage(48, 4), Stage(2, 20)]),
        const Duration(hours: 48),
        reason: 'the warm-up comes after dividing',
      );
    });

    test('bound step on a same-day plan takes the room bulk hours', () {
      // Every room stage before a fridge stage is bulk, as Ferment and the
      // schedule read it.
      expect(stepDuration(bulk, sameDayPlan), const Duration(hours: 6));
      expect(
        stepDuration(bulk, const [Stage(1.5, 24)]),
        const Duration(minutes: 90),
      );
    });

    test('an empty fridge stage does not make the plan cold', () {
      expect(
        stepDuration(bulk, const [Stage(3, 21), Stage(0, 4)]),
        const Duration(hours: 3),
      );
    });

    test('a warm-up after an empty fridge stage is not bulk', () {
      // Ferment writes room 2 h, fridge 0 h, warm-up 1 h like this.
      expect(
        stepDuration(bulk, const [Stage(2, 20), Stage(0, 4), Stage(1, 20)]),
        const Duration(hours: 2),
      );
      expect(
        stepDuration(bulk, const [Stage(0, 4), Stage(3, 20)]),
        Duration.zero,
      );
    });

    test('bound step with no plan falls back to its own minutes', () {
      expect(stepDuration(bulk, const []), const Duration(hours: 4));
    });
  });

  group('totals', () {
    test('handsOnDuration sums the steps before the bound step', () {
      expect(
        handsOnDuration(defaultRoutine.steps),
        const Duration(minutes: 114),
      );
    });

    test('handsOnDuration with no bound step sums every step', () {
      final steps = defaultRoutine.steps.take(3).toList();
      expect(handsOnDuration(steps), const Duration(minutes: 37));
    });

    test('afterBulkDuration sums the steps after the bound step', () {
      expect(
        afterBulkDuration(defaultRoutine.steps),
        const Duration(minutes: 5),
      );
      expect(
        afterBulkDuration(defaultRoutine.steps.take(3).toList()),
        Duration.zero,
      );
    });

    test('routineTotal binds step 10 to the plan', () {
      expect(
        routineTotal(defaultRoutine.steps, coldPlan),
        const Duration(minutes: 114 + 26 * 60 + 5),
      );
      expect(
        routineTotal(defaultRoutine.steps, sameDayPlan),
        const Duration(minutes: 114 + 360 + 5),
      );
    });
  });

  group('RoutineStep', () {
    test('copyWith changes only the given fields', () {
      final s = bulk.copyWith(minutes: 60);
      expect(s.minutes, 60);
      expect(s.name, bulk.name);
      expect(s.bindsToPlan, isTrue);
      final t = bulk.copyWith(
        name: 'Proof',
        kind: StepKind.active,
        note: 'n',
        bindsToPlan: false,
      );
      expect(t.toJson(), {
        'name': 'Proof',
        'kind': 'active',
        'minutes': 240,
        'note': 'n',
        'bindsToPlan': false,
      });
    });

    test('JSON round trip keeps every field', () {
      expect(RoutineStep.fromJson(bulk.toJson()).toJson(), bulk.toJson());
    });

    test('fromJson defaults note and bindsToPlan when missing', () {
      final s = RoutineStep.fromJson(const {
        'name': 'Rest',
        'kind': 'rest',
        'minutes': 15,
      });
      expect(s.note, '');
      expect(s.bindsToPlan, isFalse);
    });
  });

  group('RoutinePreset', () {
    test('JSON round trip; anything read back is a user preset', () {
      final p = RoutinePreset.fromJson(defaultRoutine.toJson());
      expect(p.name, defaultRoutine.name);
      expect(p.builtIn, isFalse);
      expect(p.toJson(), defaultRoutine.toJson());
    });
  });
}
