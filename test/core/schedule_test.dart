import 'package:flutter_test/flutter_test.dart';
import 'package:pizzalator/core/presets.dart';
import 'package:pizzalator/core/schedule.dart';

const routine = Duration(hours: 1, minutes: 55);
const divide = Duration(minutes: 5);

List<String> names(List<ScheduleItem> items) => [for (final i in items) i.name];

void main() {
  group('waterTempC', () {
    test('3-factor form with defaults: 3 x 24 - 20 - 20 - 2 = 30', () {
      expect(waterTempC(flourC: 20, roomC: 20), 30);
    });

    test('mixer friction and custom target', () {
      expect(
        waterTempC(
          targetC: 25,
          flourC: 18,
          roomC: 21,
          frictionC: kFrictionMixerC,
        ),
        3 * 25 - 18 - 21 - 6,
      );
    });

    test('4-factor form when a preferment temperature is given', () {
      expect(
        waterTempC(flourC: 20, roomC: 20, prefermentC: 18),
        4 * 24 - 20 - 20 - 2 - 18,
      );
    });

    test('knobs', () {
      expect(kFrictionHandC, 2);
      expect(kFrictionMixerC, 6);
      expect(kTargetDoughC, 24);
    });
  });

  group('buildSchedule', () {
    // Recipe mockup: NY, 1 h bulk at 21, 48 h fridge at 4, 2 h warm-up.
    final bakeAt = DateTime(2026, 10, 30, 19);
    final cold = buildSchedule(
      plan: const [Stage(1, 21), Stage(48, 4), Stage(2, 21)],
      preferment: Preferment.none,
      handsOn: routine,
      afterBulk: divide,
      bakeAt: bakeAt,
    );

    test('cold plan follows the routine: bulk, fridge, then divide', () {
      expect(names(cold), [
        'Mix + dough routine',
        'Bulk in container',
        'Fridge',
        'Divide into balls',
        'Warm up',
        'Bake',
      ]);
      expect(
        [for (final i in cold) i.step],
        [
          ScheduleStep.mix,
          ScheduleStep.bulk,
          ScheduleStep.fridge,
          ScheduleStep.ball,
          ScheduleStep.warmUp,
          ScheduleStep.bake,
        ],
      );
      expect(
        [for (final i in cold) i.note],
        [
          'Timers run it: 1 h 55.',
          '1 h at 21 °C, covered.',
          '48 h at 4 °C, in the container.',
          'Into oiled tubs, covered.',
          '2 h before bake, on the counter: balls reach 15 °C and relax.',
          'See bake card.',
        ],
      );
      expect(kWarmUpTargetC, 15);
    });

    test('offsets accumulate from the start of the process', () {
      expect(
        [for (final i in cold) i.startOffset],
        const [
          Duration.zero,
          routine,
          Duration(hours: 2, minutes: 55),
          Duration(hours: 50, minutes: 55),
          Duration(hours: 51),
          Duration(hours: 53),
        ],
      );
      expect(
        [for (final i in cold) i.duration],
        const [
          routine,
          Duration(hours: 1),
          Duration(hours: 48),
          divide,
          Duration(hours: 2),
          Duration.zero,
        ],
      );
    });

    test('absolute times work backwards from bakeAt', () {
      expect(cold.first.at, DateTime(2026, 10, 28, 14));
      expect(cold.last.at, bakeAt);
      expect(cold[4].at, DateTime(2026, 10, 30, 17));
      for (final i in cold) {
        expect(i.at, cold.first.at!.add(i.startOffset));
      }
    });

    test('no bakeAt leaves every at null', () {
      final s = buildSchedule(
        plan: PizzaStyle.newYork.plan,
        preferment: Preferment.none,
        handsOn: routine,
        afterBulk: divide,
      );
      expect(s.every((i) => i.at == null), isTrue);
    });

    test('same-day plan has no fridge or warm-up', () {
      final s = buildSchedule(
        plan: const [Stage(1, 20), Stage(1.5, 24)],
        preferment: Preferment.none,
        handsOn: const Duration(minutes: 45),
        afterBulk: divide,
      );
      expect(names(s), [
        'Mix + dough routine',
        'Bulk in container',
        'Divide into balls',
        'Bake',
      ]);
      expect(s[0].note, 'Timers run it: 45 min.');
      expect(s[1].note, '1 h at 20 °C, 1 h 30 at 24 °C, covered.');
      expect(s[1].duration, const Duration(hours: 2, minutes: 30));
      expect(s.last.startOffset, const Duration(hours: 3, minutes: 20));
    });

    test('fridge-only plan skips bulk; zero-hour stages are dropped', () {
      final s = buildSchedule(
        plan: const [Stage(0, 21), Stage(48, 4), Stage(0, 21)],
        preferment: Preferment.none,
        handsOn: routine,
        afterBulk: divide,
      );
      expect(names(s), [
        'Mix + dough routine',
        'Fridge',
        'Divide into balls',
        'Bake',
      ]);
    });

    test('a warm-up after an empty fridge stage proofs the balls', () {
      // Ferment writes room 2 h, fridge 0 h, warm-up 1 h like this.
      final s = buildSchedule(
        plan: const [Stage(2, 20), Stage(0, 4), Stage(1, 20)],
        preferment: Preferment.none,
        handsOn: routine,
        afterBulk: divide,
      );
      expect(names(s), [
        'Mix + dough routine',
        'Bulk in container',
        'Divide into balls',
        'Proof balls',
        'Bake',
      ]);
      expect(s[1].duration, const Duration(hours: 2));
      expect(s[3].step, ScheduleStep.warmUp);
      expect(s[3].duration, const Duration(hours: 1));
      expect(s[3].note, '1 h at 20 °C on the counter, covered.');
    });

    test('hmText: "45 min", "2 h", "1 h 05"', () {
      expect(hmText(Duration.zero), '0 min');
      expect(hmText(const Duration(minutes: 45)), '45 min');
      expect(hmText(const Duration(hours: 2)), '2 h');
      expect(hmText(const Duration(hours: 1, minutes: 5)), '1 h 05');
      expect(hmText(const Duration(hours: 50, minutes: 54)), '50 h 54');
    });

    test('poolish comes first with its hours', () {
      final s = buildSchedule(
        plan: PizzaStyle.neapolitan.plan,
        preferment: Preferment.poolish,
        handsOn: routine,
        afterBulk: divide,
        bakeAt: bakeAt,
      );
      expect(s.first.step, ScheduleStep.preferment);
      expect(s.first.name, 'Mix poolish');
      expect(s.first.note, '14 h at 20 °C, covered.');
      expect(s.first.duration, const Duration(hours: 14));
      expect(s[1].startOffset, const Duration(hours: 14));
      expect(s[1].at, s.first.at!.add(const Duration(hours: 14)));
      expect(
        s.last.startOffset,
        const Duration(hours: 14 + 2 + 24, minutes: 115 + 5),
      );
    });

    test('biga name; the starter is fed ahead at room temperature', () {
      List<ScheduleItem> of(Preferment p) => buildSchedule(
        plan: const [],
        preferment: p,
        handsOn: routine,
        afterBulk: divide,
      );
      expect(of(Preferment.biga).first.name, 'Mix biga');
      expect(of(Preferment.none).first.name, 'Mix + dough routine');
      final feed = of(Preferment.sourdough).first;
      expect(feed.name, 'Feed starter');
      expect(feed.note, '6 h at room temperature, covered.');
      expect(feed.duration, const Duration(hours: 6));
    });
  });
}
