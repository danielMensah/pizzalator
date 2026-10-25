import 'package:flutter_test/flutter_test.dart';
import 'package:pizzalator/core/live_timer.dart';
import 'package:pizzalator/core/presets.dart';
import 'package:pizzalator/core/routine.dart';
import 'package:pizzalator/core/timer_run.dart';

const _a = StepKind.active;
const _r = StepKind.rest;
const restA = RoutineStep(name: 'Rest A', kind: _r, minutes: 30);
const restB = RoutineStep(name: 'Rest B', kind: _r, minutes: 15);
const knead = RoutineStep(name: 'Knead', kind: _a, minutes: 10);
const fold = RoutineStep(name: 'Fold', kind: _a, minutes: 2);
const warm = [Stage(4, 22)];
const cold = [Stage(2, 20), Stage(24, 4)];

final t0 = DateTime(2026, 10, 24, 9);
DateTime at(num minutes) => t0.add(Duration(seconds: (minutes * 60).round()));

/// One frame per line: start–end (or the button it waits for), ♪ when it
/// chimes, title | text. Minutes from the leg's start.
List<List<String>> lines(List<List<LiveFrame>> legs) => [
  for (final leg in legs)
    [
      for (final f in leg)
        '${f.at.inMinutes}'
            '${f.end == null ? ' ${f.go!.name}' : '–${f.end!.inMinutes}'}'
            '${f.chime ? ' ♪' : ''} ${f.title} | ${f.text}',
    ],
];

TimerRun routine(List<Stage> plan, {bool autoStart = false}) =>
    TimerRun.fromRoutine(
      defaultRoutine.steps,
      plan,
      autoStart: autoStart,
    ).start(t0);

/// LiveTimerState.kt, line for line: what the native side does with the
/// legs while the app is hidden.
class Native {
  Native(this.legs, this.legStart, {this.pausedAt});

  final List<List<LiveFrame>> legs;
  DateTime legStart;
  DateTime? pausedAt;
  var leg = 0, frame = 0;
  var shift = Duration.zero;
  final log = <LiveAction>[];

  bool get done => leg >= legs.length;

  int _index(DateTime now) {
    final t = (pausedAt ?? now).difference(legStart) - shift;
    var i = frame;
    while (i + 1 < legs[leg].length && legs[leg][i + 1].at <= t) {
      i++;
    }
    return i;
  }

  LiveFrame? current(DateTime now) => done ? null : legs[leg][_index(now)];

  /// The current timer's end, were it resumed at [now].
  DateTime? endAt(DateTime now) => switch (current(now)?.end) {
    null => null,
    final end => legStart.add(
      shift +
          end +
          (pausedAt == null ? Duration.zero : now.difference(pausedAt!)),
    ),
  };

  void pause(DateTime now) => _timer(now, () {
    pausedAt = now;
    log.add(LiveAction(LiveTap.pause, now));
  });

  void extend(DateTime now) => _timer(now, () {
    shift += kExtendBy;
    log.add(LiveAction(LiveTap.extend, now));
  });

  void resume(DateTime now) {
    if (pausedAt == null) return;
    shift += now.difference(pausedAt!);
    pausedAt = null;
    log.add(LiveAction(LiveTap.resume, now));
  }

  void go(DateTime now) {
    if (done || pausedAt != null) return;
    final g = legs[leg][_index(now)].go;
    if (g == null) return;
    log.add(LiveAction(g == LiveGo.start ? LiveTap.start : LiveTap.next, now));
    leg++;
    frame = 0;
    legStart = now;
    shift = Duration.zero;
  }

  void _timer(DateTime now, void Function() change) {
    if (done || pausedAt != null) return;
    final i = _index(now);
    if (legs[leg][i].end == null) return;
    frame = i;
    change();
  }
}

void main() {
  group('liveLegs', () {
    test('default routine, warm plan: one leg per tap', () {
      expect(lines(liveLegs(routine(warm), t0)), [
        [
          '0 next Mix all ingredients | Water, yeast, sugar, flour; salt and '
              'oil after a short rest',
        ],
        [
          '0–30 Rest in bowl, covered | Next: Fold in bowl 4–6×',
          '30 next ♪ Rest over | Next: Fold in bowl 4–6×',
        ],
        ['0 next Fold in bowl 4–6× | Tap Done, next when finished'],
        [
          '0–15 Rest, covered | Next: Fold in bowl again',
          '15 next ♪ Rest over | Next: Fold in bowl again',
        ],
        ['0 next Fold in bowl again | Tap Done, next when finished'],
        [
          '0–15 Rest, covered | Next: Knead on the counter',
          '15 next ♪ Rest over | Next: Knead on the counter',
        ],
        ['0 start Knead on the counter | Timed active step'],
        [
          '0–10 Knead on the counter | Next: Rest on counter, covered',
          '10 next ♪ Knead on the counter done | Next: Rest on counter, '
              'covered',
        ],
        [
          '0–30 Rest on counter, covered | Next: Stretch, fold, shape one ball',
          '30 next ♪ Rest over | Next: Stretch, fold, shape one ball',
        ],
        [
          '0 next Stretch, fold, shape one ball | Folding traps air; into '
              'the container',
        ],
        [
          '0–240 Bulk in container | Next: Divide into balls',
          '240 next ♪ Rest over | Next: Divide into balls',
        ],
        ['0 finish Divide into balls | Then final proof per plan'],
      ]);
    });

    test('cold plan: into the fridge chains, take out waits', () {
      final legs = lines(liveLegs(routine(cold), t0));
      expect(legs, hasLength(12));
      expect(legs[10], [
        '0–120 Bulk in container | Next: Fridge',
        '120–1560 ♪ Fridge | Into the fridge · Next: Divide into balls',
        '1560 next ♪ Take out of fridge | Next: Divide into balls',
      ]);
    });

    test('auto-start: timers chain until an untimed step', () {
      expect(lines(liveLegs(routine(warm, autoStart: true), t0)).skip(1), [
        [
          '0–30 Rest in bowl, covered | Next: Fold in bowl 4–6×',
          '30 next ♪ Fold in bowl 4–6× | Rest over · Tap Done, next when '
              'finished',
        ],
        [
          '0–15 Rest, covered | Next: Fold in bowl again',
          '15 next ♪ Fold in bowl again | Rest over · Tap Done, next when '
              'finished',
        ],
        [
          '0–15 Rest, covered | Next: Knead on the counter',
          '15–25 ♪ Knead on the counter | Rest over · Next: Rest on '
              'counter, covered',
          '25–55 ♪ Rest on counter, covered | Knead on the counter done · '
              'Next: Stretch, fold, shape one ball',
          '55 next ♪ Stretch, fold, shape one ball | Rest over · Folding '
              'traps air; into the container',
        ],
        [
          '0–240 Bulk in container | Next: Divide into balls',
          '240 finish ♪ Divide into balls | Rest over · Then final proof '
              'per plan',
        ],
      ]);
    });

    test('paused: laid out as if resumed now', () {
      final r = TimerRun(
        steps: const [restA, fold],
        left: const Duration(minutes: 12),
      );
      expect(lines(liveLegs(r, t0)), [
        ['0–12 Rest A | Next: Fold', '12 next ♪ Rest over | Next: Fold'],
        ['0 finish Fold | Tap Finish when finished'],
      ]);
    });

    test('ready timed step waits for Start; a timed last step finishes', () {
      expect(lines(liveLegs(const TimerRun(steps: [knead, restB]), t0)), [
        ['0 start Knead | Tap Start when ready'],
        ['0–10 Knead | Next: Rest B', '10 next ♪ Knead done | Next: Rest B'],
        ['0–15 Rest B | Last step', '15 finish ♪ Rest over | Routine done'],
      ]);
    });

    test('settles first; offsets count from now', () {
      final r = TimerRun(steps: const [restA, restB, fold], endsAt: at(30));
      expect(lines(liveLegs(r, at(40))), [
        ['0–5 Rest B | Next: Fold', '5 next ♪ Rest over | Next: Fold'],
        ['0 finish Fold | Tap Finish when finished'],
      ]);
      // Already over and waiting: no chime, it rang on screen.
      expect(lines(liveLegs(r, at(50))).first, [
        '0 next Rest over | Next: Fold',
      ]);
    });

    test('offsets keep the seconds', () {
      final r = TimerRun(steps: const [restA, fold], endsAt: at(30));
      final f = liveLegs(r, at(0.5)).first;
      expect(f[0].end, const Duration(minutes: 29, seconds: 30));
      expect(f[1].at, const Duration(minutes: 29, seconds: 30));
    });
  });

  group('json, the wire format to Kotlin', () {
    test('frames', () {
      final legs = liveLegs(const TimerRun(steps: [knead, restB]), t0);
      expect(legs[0][0].toJson(), {
        'at': 0,
        'end': null,
        'title': 'Knead',
        'text': 'Tap Start when ready',
        'chime': false,
        'go': 'start',
      });
      expect(legs[1][1].toJson(), {
        'at': 600000,
        'end': null,
        'title': 'Knead done',
        'text': 'Next: Rest B',
        'chime': true,
        'go': 'next',
      });
      expect(legs[1][0].toJson()['end'], 600000);
      expect(legs[1][0].toJson()['go'], isNull);
    });

    test('actions', () {
      final a = LiveAction.fromJson({
        'type': 'extend',
        'at': at(3).millisecondsSinceEpoch,
      });
      expect(a.type, LiveTap.extend);
      expect(a.at, at(3));
    });
  });

  group('replayLive', () {
    final run = TimerRun(steps: const [restA, knead, restB], endsAt: at(30));

    test('no taps: the same run', () {
      expect(replayLive(run, const []), same(run));
    });

    test('each tap acts on the run settled at its time', () {
      final r = replayLive(run, [
        LiveAction(LiveTap.pause, at(10)), // 20 left
        LiveAction(LiveTap.resume, at(15)), // ends 35
        LiveAction(LiveTap.extend, at(20)), // ends 40
        LiveAction(LiveTap.next, at(41)), // Knead, ready
        LiveAction(LiveTap.start, at(42)), // ends 52
      ])!;
      expect(r.index, 1);
      expect(r.endsAt, at(52));
    });

    test('next on the last step ends it; later taps are moot', () {
      final last = TimerRun(steps: const [restA], endsAt: at(30));
      expect(
        replayLive(last, [
          LiveAction(LiveTap.next, at(31)),
          LiveAction(LiveTap.pause, at(32)),
        ]),
        isNull,
      );
    });
  });

  group('contract: the native state machine agrees with replayLive', () {
    // Drives Native through pause, resume, +5 and the waiting buttons, and
    // after every step compares its frame with a fresh layout of the
    // replayed run: same step, same end, same button.
    void drive(TimerRun run, {bool paused = false}) {
      final n = Native(liveLegs(run, t0), t0, pausedAt: paused ? t0 : null);
      LiveFrame? seen;
      var chained = false;
      for (var m = 0.0; m < 5000 && !n.done; m += 0.5) {
        final now = at(m);
        final whole = m.truncate();
        if (m == whole) {
          // Some land on the wrong frame (+5 while paused, pause while
          // waiting); native ignores those and so must the replay. +5 just
          // after a chained timer begins must not bring back the one before.
          if (whole % 59 == 3) n.pause(now);
          if (whole % 59 == 9) n.resume(now);
          if (whole % 97 == 5 || chained) n.extend(now);
          if (whole % 7 == 1) n.go(now);
          chained = false;
        }
        final r = replayLive(run, n.log)?.settle(now);
        final f = n.current(now);
        if (f != seen && f != null && f.chime && f.end != null) chained = true;
        seen = f;
        if (r == null) {
          expect(f, isNull, reason: 'at $m');
          continue;
        }
        final want = liveLegs(r, now).first.first;
        final reason = 'at $m, ${n.log.length} taps';
        expect(f!.title, want.title, reason: reason);
        expect(f.go, want.go, reason: reason);
        expect(
          n.endAt(now),
          want.end == null ? null : now.add(want.end!),
          reason: reason,
        );
        expect(
          n.pausedAt != null,
          r.phaseAt(now) == RunPhase.paused,
          reason: reason,
        );
      }
      expect(n.done, isTrue, reason: 'the script reaches Finish');
      expect(replayLive(run, n.log), isNull);
    }

    test('default routine, cold plan', () => drive(routine(cold)));
    test('auto-start', () => drive(routine(warm, autoStart: true)));
    test('starts paused', () {
      drive(
        TimerRun(
          steps: const [restA, restB, knead, fold],
          left: const Duration(minutes: 7),
        ),
        paused: true,
      );
    });
  });
}
