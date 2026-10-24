import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pizzalator/core/calc.dart';
import 'package:pizzalator/core/routine.dart';
import 'package:pizzalator/core/schedule.dart';
import 'package:pizzalator/core/timer_run.dart';
import 'package:pizzalator/services/json_store.dart';
import 'package:pizzalator/state/recipe.dart';
import 'package:pizzalator/state/routine.dart';
import 'package:pizzalator/state/schedule.dart';
import 'package:pizzalator/state/timer_run.dart';

void main() {
  late ProviderContainer c;
  setUp(() => c = ProviderContainer.test());

  BakeSetupNotifier n() => c.read(bakeSetupProvider.notifier);
  void recipe(RecipeInputs Function(RecipeInputs) change) =>
      c.read(recipeProvider.notifier).update(change);

  group('bakeSetup', () {
    test('defaults: no bake time, flour 20, by hand', () {
      final s = c.read(bakeSetupProvider);
      expect(s.bakeAt, isNull);
      expect(s.flourC, kDefaultFlourC);
      expect(s.mixer, isFalse);
      expect(kDefaultFlourC, 20);
    });

    test('setters keep the other fields', () {
      final at = DateTime(2026, 10, 30, 19);
      n().setBakeAt(at);
      n().setFlourC(18);
      n().setMixer(true);
      final s = c.read(bakeSetupProvider);
      expect(s.bakeAt, at);
      expect(s.flourC, 18);
      expect(s.mixer, isTrue);
    });

    test('flour temperature clamps to the kitchen range', () {
      n().setFlourC(-5);
      expect(c.read(bakeSetupProvider).flourC, kKitchenMinC);
      n().setFlourC(99);
      expect(c.read(bakeSetupProvider).flourC, kKitchenMaxC);
    });
  });

  group('waterTemp', () {
    test('3-factor by hand at the plan room temp: 72 - 20 - 20 - 2 = 30', () {
      expect(c.read(waterTempProvider), (
        celsius: 30,
        caption: 'for 24 °C dough · flour 20 °C · room 20 °C · hand mix',
      ));
    });

    test('mixer friction', () {
      n().setMixer(true);
      final w = c.read(waterTempProvider);
      expect(w.celsius, 26);
      expect(w.caption, endsWith('room 20 °C · mixer'));
    });

    test('one kitchen: the plan room temp drives yeast and water', () {
      final before = c.read(outputsProvider).yeastPct;
      c.read(recipeProvider.notifier).setRoomC(26);
      expect(c.read(waterTempProvider).celsius, 72 - 20 - 26 - 2);
      expect(c.read(waterTempProvider).caption, contains('room 26 °C'));
      expect(c.read(outputsProvider).yeastPct, lessThan(before));
    });

    test('follows the flour temperature', () {
      n().setFlourC(10);
      expect(c.read(waterTempProvider).celsius, 40);
    });

    test('poolish: 4-factor at its fermenting temperature', () {
      recipe((i) => i.copyWith(preferment: Preferment.poolish));
      expect(c.read(waterTempProvider), (
        celsius: 34,
        caption:
            'for 24 °C dough · flour 20 °C · room 20 °C · poolish 20 °C · '
            'hand mix',
      ));
    });

    test('starter has no temperature of its own: room temperature', () {
      recipe((i) => withYeast(i, Yeast.sourdough));
      expect(c.read(waterTempProvider).celsius, 34);
      expect(c.read(waterTempProvider).caption, contains('starter 20 °C'));
      c.read(recipeProvider.notifier).setRoomC(24);
      expect(c.read(waterTempProvider).celsius, 96 - 20 - 24 - 2 - 24);
    });
  });

  group('schedule', () {
    List<String> names() => [for (final i in c.read(scheduleProvider)) i.name];

    test('style plan, routine hands-on time, relative without bake time', () {
      expect(names(), [
        'Mix + dough routine',
        'Bulk in container',
        'Fridge',
        'Divide into balls',
        'Bake',
      ]);
      final items = c.read(scheduleProvider);
      expect(items.first.duration, handsOnDuration(defaultRoutine.steps));
      expect(items.first.duration, const Duration(minutes: 114));
      expect(items[3].duration, const Duration(minutes: 5));
      expect(items.every((i) => i.at == null), isTrue);
    });

    test('bake time fills absolute times', () {
      final at = DateTime(2026, 10, 30, 19);
      n().setBakeAt(at);
      final items = c.read(scheduleProvider);
      expect(items.last.at, at);
      // 1 h 54 + 2 h + 24 h + 5 min before Friday 19:00.
      expect(items.first.at, DateTime(2026, 10, 29, 15, 1));
    });

    test('custom plan and preferment', () {
      recipe(
        (i) => i.copyWith(
          plan: const [Stage(1, 21), Stage(48, 4), Stage(2, 21)],
          preferment: Preferment.poolish,
        ),
      );
      expect(names(), [
        'Mix poolish',
        'Mix + dough routine',
        'Bulk in container',
        'Fridge',
        'Divide into balls',
        'Warm up',
        'Bake',
      ]);
    });

    test('sourdough: the starter is fed first', () {
      recipe((i) => withYeast(i, Yeast.sourdough));
      expect(names().first, 'Feed starter');
    });

    test('follows routine edits', () async {
      final dir = Directory.systemTemp.createTempSync('schedule_state_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      c = ProviderContainer.test(
        overrides: [jsonStoreProvider.overrideWithValue(JsonStore(dir))],
      );
      await c.read(routineProvider.notifier).setMinutes(0, 15);
      expect(
        c.read(scheduleProvider).first.duration,
        const Duration(minutes: 124),
      );
    });

    test('timers and schedule agree on every default plan (PRD §4.7)', () {
      n().setBakeAt(DateTime(2026, 10, 30, 19));
      final plans = [
        for (final s in PizzaStyle.values) s.plan,
        kSourdoughPlan,
        const [Stage(4, 22)],
        const [Stage(48, 4)],
        const [Stage(2, 20), Stage(24, 4), Stage(2, 20)],
      ];
      for (final plan in plans) {
        recipe((i) => i.copyWith(plan: plan));
        final items = c.read(scheduleProvider);
        final run = c.read(previewRunProvider);
        ScheduleItem item(ScheduleStep s) =>
            items.firstWhere((i) => i.step == s);
        final mixAt = item(ScheduleStep.mix).at!;
        final divide = item(ScheduleStep.ball);

        // Each timer as if run on time from the mix: when its alarm rings.
        final rings = <String, DateTime>{};
        var t = mixAt;
        for (final (k, s) in run.steps.indexed) {
          final end = t.add(Duration(minutes: s.minutes));
          final r = TimerRun(
            steps: run.steps,
            cold: run.cold,
            index: k,
            endsAt: end,
          );
          rings[r.alarms(t).first.title] = end;
          t = end;
        }
        final why = [for (final s in plan) '${s.hours}@${s.tempC}'].join(' ');
        expect(t, divide.at!.add(divide.duration), reason: why);
        // Dividing starts when the last plan-bound timer ends.
        final bulkEnd = run.steps
            .take(run.steps.lastIndexWhere((s) => s.bindsToPlan) + 1)
            .fold(0, (m, s) => m + s.minutes);
        expect(mixAt.add(Duration(minutes: bulkEnd)), divide.at, reason: why);
        if (run.cold) {
          expect(rings['Take out of fridge'], divide.at, reason: why);
        }
        if (rings['Into the fridge'] case final into?) {
          expect(into, item(ScheduleStep.fridge).at, reason: why);
        }
      }
    });
  });
}
