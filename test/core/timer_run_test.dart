import 'package:flutter_test/flutter_test.dart';
import 'package:pizzalator/core/presets.dart';
import 'package:pizzalator/core/routine.dart';
import 'package:pizzalator/core/timer_run.dart';

const _a = StepKind.active;
const _r = StepKind.rest;
const mix = RoutineStep(name: 'Mix', kind: _a, minutes: 5);
const restA = RoutineStep(name: 'Rest A', kind: _r, minutes: 30);
const restB = RoutineStep(name: 'Rest B', kind: _r, minutes: 15);
const knead = RoutineStep(name: 'Knead', kind: _a, minutes: 10);
const bulk = RoutineStep(
  name: 'Bulk',
  kind: _r,
  minutes: 240,
  bindsToPlan: true,
);
const divide = RoutineStep(name: 'Divide', kind: _a, minutes: 5);

final t0 = DateTime(2026, 10, 24, 9);
DateTime at(int minutes) => t0.add(Duration(minutes: minutes));
const min = Duration(minutes: 1);

TimerRun run(
  List<RoutineStep> steps, {
  int index = 0,
  DateTime? endsAt,
  Duration? left,
  bool autoStart = false,
  bool cold = false,
}) => TimerRun(
  steps: steps,
  index: index,
  endsAt: endsAt,
  left: left,
  autoStart: autoStart,
  cold: cold,
);

void main() {
  group('fromRoutine', () {
    test('cold plan: room bulk, then a fridge rest, then divide', () {
      final r = TimerRun.fromRoutine(
        [mix, bulk, divide],
        const [Stage(2, 20), Stage(24, 4)],
      );
      expect(r.steps.map((s) => s.minutes), [5, 120, 1440, 5]);
      expect(r.steps.map((s) => s.name), ['Mix', 'Bulk', 'Fridge', 'Divide']);
      expect(r.steps.map((s) => s.kind), [_a, _r, _r, _a]);
      expect(r.steps[1].bindsToPlan, isTrue);
      expect(r.steps[2].bindsToPlan, isTrue);
      expect(
        r.total,
        routineTotal([mix, bulk, divide], const [Stage(2, 20), Stage(24, 4)]),
      );
      expect(r.cold, isTrue);
      expect(r.index, 0);
      expect(r.autoStart, isFalse);
      expect(r.phaseAt(t0), RunPhase.ready);
    });

    test('fridge-only plan: the bound step is the fridge rest', () {
      final r = TimerRun.fromRoutine([bulk, divide], const [Stage(48, 4)]);
      expect(r.steps.map((s) => s.minutes), [2880, 5]);
      expect(r.steps.first.name, 'Bulk');
      expect(r.cold, isTrue);
    });

    test('no plan: the bound step keeps its own minutes', () {
      final r = TimerRun.fromRoutine([bulk], const []);
      expect(r.steps.single.minutes, 240);
    });

    test('same-day plan: bulk hours, not cold', () {
      final r = TimerRun.fromRoutine(
        [bulk],
        const [Stage(4, 22)],
        autoStart: true,
      );
      expect(r.steps.single.minutes, 240);
      expect(r.cold, isFalse);
      expect(r.autoStart, isTrue);
    });
  });

  test('rests and long active steps are timed; short active ones are not', () {
    expect(isTimed(restB), isTrue);
    expect(isTimed(knead), isTrue);
    expect(isTimed(mix), isFalse);
    expect(kTimedActiveMinutes, 10);
  });

  test('untimed active step: start is a no-op, next starts the rest', () {
    final r = run([mix, restA]);
    expect(r.start(t0), same(r));
    expect(r.remainingAt(t0), const Duration(minutes: 5));
    final n = r.next(at(4))!;
    expect(n.index, 1);
    expect(n.phaseAt(at(4)), RunPhase.running);
    expect(n.endsAt, at(34));
  });

  test('rest: pause keeps the remaining time, resume restarts from it', () {
    final r = run([restA, mix], endsAt: at(30));
    expect(r.phaseAt(at(10)), RunPhase.running);
    expect(r.remainingAt(at(10)), const Duration(minutes: 20));
    expect(r.start(at(10)), same(r));
    final p = r.pause(at(10));
    expect(p.phaseAt(at(50)), RunPhase.paused);
    expect(p.left, const Duration(minutes: 20));
    expect(p.endsAt, isNull);
    expect(p.remainingAt(at(50)), const Duration(minutes: 20));
    expect(p.pause(at(60)), same(p));
    final resumed = p.start(at(60));
    expect(resumed.endsAt, at(80));
    expect(resumed.left, isNull);
  });

  test('rest to active waits for the tap; timed active waits for Start', () {
    final r = run([restA, knead, restB], endsAt: at(30));
    expect(r.phaseAt(at(30)), RunPhase.ended);
    expect(r.remainingAt(at(31)), Duration.zero);
    expect(r.settle(at(90)), same(r));
    expect(r.pause(at(31)), same(r));
    final k = r.next(at(32))!;
    expect(k.index, 1);
    expect(k.phaseAt(at(32)), RunPhase.ready);
    final going = k.start(at(33));
    expect(going.endsAt, at(43));
  });

  test('active to rest also waits for the tap', () {
    final r = run([knead, restA], endsAt: at(10));
    expect(r.settle(at(60)), same(r));
    expect(r.next(at(12))!.endsAt, at(42));
  });

  test('catch-up chains elapsed rests and stops before an active step', () {
    final r = run([mix, restA, restB, restA, knead], index: 1, endsAt: at(30));
    expect(r.settle(at(29)), same(r));
    final mid = r.settle(at(40));
    expect(mid.index, 2);
    expect(mid.endsAt, at(45), reason: 'chained from the end, not from now');
    final s = r.settle(at(500));
    expect(s.index, 3);
    expect(s.endsAt, at(75));
    expect(s.phaseAt(at(500)), RunPhase.ended);
  });

  test('auto-start: rest end starts a timed active step, then its rest', () {
    final r = run([restA, knead, restB, mix], endsAt: at(30), autoStart: true);
    final s = r.settle(at(41));
    expect(s.index, 2);
    expect(s.endsAt, at(55));
    final u = r.settle(at(100));
    expect(u.index, 3, reason: 'untimed step shows, waits for Done');
    expect(u.phaseAt(at(100)), RunPhase.ready);
    expect(u.endsAt, isNull);
  });

  test('auto-start: entering a timed active step via next starts it', () {
    final r = run([mix, knead], autoStart: true);
    expect(r.next(t0)!.endsAt, at(10));
    expect(run([mix, knead]).next(t0)!.endsAt, isNull);
  });

  test('withAutoStart copies the run', () {
    final r = run([restA, knead], endsAt: at(30), cold: true);
    final on = r.withAutoStart(true, at(20));
    expect(on.autoStart, isTrue);
    expect(on.cold, isTrue);
    expect(on.endsAt, at(30));
    expect(on.settle(at(31)).index, 1);
    expect(on.withAutoStart(false, at(40)).endsAt, at(30));
  });

  test('auto-start on after a timer ended chains from the toggle', () {
    // Rest A ended at 15 and waited; switching on at 35 must not count
    // Knead as done or back-date Rest B.
    final r = run([
      restA.copyWith(minutes: 15),
      knead,
      restB.copyWith(minutes: 30),
    ], endsAt: at(15));
    final on = r.withAutoStart(true, at(35)).settle(at(35));
    expect(on.index, 1);
    expect(on.step.name, 'Knead');
    expect(on.endsAt, at(45));
    expect(on.settle(at(46)).endsAt, at(75));
  });

  group('+5 always leaves it running', () {
    test('running', () {
      expect(run([restA], endsAt: at(30)).extend(at(10)).endsAt, at(35));
    });
    test('ended', () {
      expect(run([restA], endsAt: at(30)).extend(at(40)).endsAt, at(45));
    });
    test('paused', () {
      final p = run([restA], left: const Duration(minutes: 12));
      final e = p.extend(at(50));
      expect(e.endsAt, at(67));
      expect(e.left, isNull);
    });
    test('ready', () {
      expect(run([knead]).extend(t0).endsAt, at(15));
    });
  });

  test('next on the last step finishes the run', () {
    expect(run([divide]).next(t0), isNull);
  });

  test('totals, progress and the ready time', () {
    final r = run([mix, restA, restB], index: 1, endsAt: at(35));
    expect(r.total, const Duration(minutes: 50));
    expect(r.totalLeftAt(at(15)), const Duration(minutes: 35));
    expect(r.progressAt(at(15)), closeTo(0.3, 1e-9));
    expect(r.readyAt(at(15)), at(50));
    expect(r.step, same(restA));
    expect(r.nextStep, same(restB));
    expect(r.isLast, isFalse);
    final last = run([mix, restA], index: 1, endsAt: at(35));
    expect(last.nextStep, isNull);
    expect(last.isLast, isTrue);
    expect(last.progressAt(at(40)), 1);
  });

  test('progress of an empty-length routine is 1, not NaN', () {
    expect(run([mix.copyWith(minutes: 0)]).progressAt(t0), 1);
  });

  test('endedBetween is true when the end falls in (from, to]', () {
    final r = run([restA], endsAt: at(30));
    expect(r.endedBetween(at(29), at(30)), isTrue);
    expect(r.endedBetween(at(30), at(31)), isFalse);
    expect(r.endedBetween(at(20), at(29)), isFalse);
    expect(run([restA]).endedBetween(t0, at(60)), isFalse);
  });

  group('alarms', () {
    test('one per timer end in the automatic chain', () {
      final r = run([restA, restB, knead], endsAt: at(30));
      final a = r.alarms(at(5));
      expect(a.map((x) => x.at), [at(30), at(45)]);
      expect(a.map((x) => x.title), ['Rest over', 'Rest over']);
      expect(a.map((x) => x.body), ['Next: Rest B', 'Next: Knead']);
    });

    test('settles first: elapsed ends are not alarmed', () {
      final r = run([restA, restB, knead], endsAt: at(30));
      expect(r.alarms(at(31)).map((x) => x.at), [at(45)]);
      expect(r.alarms(at(46)), isEmpty);
    });

    test('active timer end and routine end', () {
      final a = run([knead], endsAt: at(10)).alarms(t0).single;
      expect(a.title, 'Knead done');
      expect(a.body, 'Routine done');
    });

    test('cold plan: into the fridge, then take out', () {
      final r = TimerRun.fromRoutine(
        [bulk, divide],
        const [Stage(2, 20), Stage(24, 4)],
      ).start(t0);
      expect(
        [for (final a in r.alarms(t0)) (a.at, a.title, a.body)],
        [
          (at(120), 'Into the fridge', 'Next: Fridge'),
          (at(1560), 'Take out of fridge', 'Next: Divide'),
        ],
      );
    });

    test('cold bound step says take out of fridge', () {
      final r = run([bulk, divide], endsAt: at(1440), cold: true);
      expect(r.alarms(t0).single.title, 'Take out of fridge');
      final warm = run([bulk, divide], endsAt: at(240));
      expect(warm.alarms(t0).single.title, 'Rest over');
    });

    test('auto-start chains through to the untimed step', () {
      final r = run(
        [restA, knead, restB, mix],
        endsAt: at(30),
        autoStart: true,
      );
      expect(r.alarms(t0).map((x) => x.at), [at(30), at(40), at(55)]);
      expect(r.alarms(t0)[1].title, 'Knead done');
    });

    test('nothing pending when paused, ready or ended', () {
      expect(run([restA], left: min).alarms(t0), isEmpty);
      expect(run([knead]).alarms(t0), isEmpty);
      expect(run([restA, mix], endsAt: at(30)).alarms(at(31)), isEmpty);
    });
  });

  group('json', () {
    test('round trip', () {
      final r = run(
        [mix, bulk],
        index: 1,
        endsAt: at(30),
        autoStart: true,
        cold: true,
      );
      final back = TimerRun.fromJson(r.toJson());
      expect(back.toJson(), r.toJson());
      expect(back.endsAt, at(30));
      expect(back.steps[1].bindsToPlan, isTrue);
      final p = TimerRun.fromJson(
        run([restA], left: const Duration(seconds: 90)).toJson(),
      );
      expect(p.left, const Duration(seconds: 90));
      expect(p.endsAt, isNull);
      expect(p.autoStart, isFalse);
      expect(p.cold, isFalse);
    });

    test('an index outside the steps is rejected', () {
      final j = run([mix]).toJson()..['index'] = 3;
      expect(() => TimerRun.fromJson(j), throwsRangeError);
    });
  });
}
