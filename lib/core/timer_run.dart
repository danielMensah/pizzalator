// Pure Dart. No Flutter imports. Chained routine timers: spec/PRD.md §4.7.
import 'presets.dart';
import 'routine.dart';

// ponytail: calibration knob. Active steps at least this long count down
// (knead 10 min); shorter ones are "~N min" instructions. Swap for a per-step
// flag on RoutineStep if a short step ever needs a timer.
const int kTimedActiveMinutes = 10;

/// The fridge rest of a cold plan.
const kFridgeNote = 'In the container, covered; then out to divide.';

/// What the +5 button adds.
const Duration kExtendBy = Duration(minutes: 5);

bool isTimed(RoutineStep step) =>
    step.kind == StepKind.rest || step.minutes >= kTimedActiveMinutes;

enum RunPhase { ready, running, paused, ended }

/// What a timer end is called: the live notification's wording.
class RunAlarm {
  const RunAlarm(this.title, this.body);
  final String title, body;
}

/// One run through a routine. Immutable; every transition takes `now`.
/// Running: [endsAt] set. Paused: [left] set. Ready: neither. Ended: running
/// with [endsAt] in the past, waiting for a tap.
class TimerRun {
  const TimerRun({
    required this.steps,
    this.cold = false,
    this.autoStart = false,
    this.index = 0,
    this.endsAt,
    this.left,
  });

  /// Snapshots [steps] with the bound step's length taken from [plan], so
  /// later routine or plan edits do not move a running timer. On a cold plan
  /// with room bulk the bound step is two rests, room then fridge, so the
  /// "into the fridge" moment gets its own alarm.
  factory TimerRun.fromRoutine(
    List<RoutineStep> steps,
    List<Stage> plan, {
    bool autoStart = false,
  }) {
    final b = bulkMinutes(plan);
    return TimerRun(
      steps: [
        for (final s in steps)
          if (s.bindsToPlan && b.room > 0 && b.fridge > 0) ...[
            s.copyWith(minutes: b.room),
            s.copyWith(name: 'Fridge', minutes: b.fridge, note: kFridgeNote),
          ] else
            s.copyWith(minutes: stepDuration(s, plan).inMinutes),
      ],
      cold: plan.any((s) => s.fridge && s.hours > 0),
      autoStart: autoStart,
    );
  }

  factory TimerRun.fromJson(Map<String, Object?> json) {
    final steps = [
      for (final s in json['steps'] as List<Object?>)
        RoutineStep.fromJson(s as Map<String, Object?>),
    ];
    final index = json['index'] as int;
    RangeError.checkValidIndex(index, steps);
    final endsAt = json['endsAt'] as int?;
    final left = json['leftMs'] as int?;
    return TimerRun(
      steps: steps,
      cold: json['cold'] as bool? ?? false,
      autoStart: json['autoStart'] as bool? ?? false,
      index: index,
      endsAt: endsAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(endsAt),
      left: left == null ? null : Duration(milliseconds: left),
    );
  }

  /// Minutes already resolved against the plan.
  final List<RoutineStep> steps;

  /// The plan has a fridge stage: the bound step ends with "take out of fridge".
  final bool cold;

  /// Every timer starts on its own; only untimed steps wait for a tap.
  final bool autoStart;
  final int index;
  final DateTime? endsAt;
  final Duration? left;

  RoutineStep get step => steps[index];
  RoutineStep? get nextStep => isLast ? null : steps[index + 1];
  bool get isLast => index == steps.length - 1;

  Duration get total => steps.fold(Duration.zero, (t, s) => t + _length(s));

  RunPhase phaseAt(DateTime now) => endsAt != null
      ? (endsAt!.isAfter(now) ? RunPhase.running : RunPhase.ended)
      : left != null
      ? RunPhase.paused
      : RunPhase.ready;

  Duration remainingAt(DateTime now) => switch (phaseAt(now)) {
    RunPhase.running => endsAt!.difference(now),
    RunPhase.ended => Duration.zero,
    RunPhase.paused => left!,
    RunPhase.ready => _length(step),
  };

  /// Current step's remaining time plus every later step.
  Duration totalLeftAt(DateTime now) =>
      steps.skip(index + 1).fold(remainingAt(now), (t, s) => t + _length(s));

  /// Whole-routine progress, 0..1.
  double progressAt(DateTime now) => total == Duration.zero
      ? 1
      : (1 - totalLeftAt(now).inMilliseconds / total.inMilliseconds).clamp(
          0.0,
          1.0,
        );

  /// Projected "balls ready at".
  DateTime readyAt(DateTime now) => now.add(totalLeftAt(now));

  /// The current timer ended in (from, to]; drives the haptic tick.
  bool endedBetween(DateTime from, DateTime to) =>
      endsAt != null && endsAt!.isAfter(from) && !endsAt!.isAfter(to);

  /// Starts a ready step or resumes a paused one. Untimed steps have no timer.
  TimerRun start(DateTime now) => !isTimed(step) || endsAt != null
      ? this
      : _copy(endsAt: now.add(remainingAt(now)));

  TimerRun pause(DateTime now) => phaseAt(now) == RunPhase.running
      ? _copy(left: endsAt!.difference(now))
      : this;

  /// +5 min; always leaves the timer running.
  TimerRun extend(DateTime now) =>
      _copy(endsAt: now.add(remainingAt(now) + kExtendBy));

  /// Done, next / Skip. Null when the routine is finished.
  TimerRun? next(DateTime now) => isLast ? null : _enter(index + 1, now);

  /// Switching on with a timer already over chains from [now], not from
  /// when it ended: the steps after it are still to do.
  TimerRun withAutoStart(bool on, DateTime now) => TimerRun(
    steps: steps,
    cold: cold,
    autoStart: on,
    index: index,
    endsAt: on && phaseAt(now) == RunPhase.ended ? now : endsAt,
    left: left,
  );

  /// Applies every automatic transition up to [now]: catch-up after the app
  /// was killed. Rest-to-rest chains on its own; anything else waits for a
  /// tap unless [autoStart].
  TimerRun settle(DateTime now) {
    var r = this;
    while (r.phaseAt(now) == RunPhase.ended) {
      final n = r._chained();
      if (n == null) break;
      r = n;
    }
    return r;
  }

  /// How the end of the current step's timer is announced.
  RunAlarm get alarm => RunAlarm(
    step.bindsToPlan && cold
        ? (nextStep?.bindsToPlan ?? false)
              ? 'Into the fridge'
              : 'Take out of fridge'
        : step.kind == StepKind.rest
        ? 'Rest over'
        : '${step.name} done',
    isLast ? 'Routine done' : 'Next: ${nextStep!.name}',
  );

  Map<String, Object?> toJson() => {
    'steps': [for (final s in steps) s.toJson()],
    'cold': cold,
    'autoStart': autoStart,
    'index': index,
    'endsAt': endsAt?.millisecondsSinceEpoch,
    'leftMs': left?.inMilliseconds,
  };

  static Duration _length(RoutineStep s) => Duration(minutes: s.minutes);

  /// Enters step [i] at [at]. Rests always start; timed active steps start
  /// only under auto-start.
  TimerRun _enter(int i, DateTime at) {
    final s = steps[i];
    final go = s.kind == StepKind.rest || (autoStart && isTimed(s));
    return TimerRun(
      steps: steps,
      cold: cold,
      autoStart: autoStart,
      index: i,
      endsAt: go ? at.add(_length(s)) : null,
    );
  }

  /// The run after the current timer ends by itself, or null if it waits.
  TimerRun? _chained() {
    final n = nextStep;
    if (endsAt == null || n == null) return null;
    final restToRest = step.kind == StepKind.rest && n.kind == StepKind.rest;
    return autoStart || restToRest ? _enter(index + 1, endsAt!) : null;
  }

  TimerRun _copy({DateTime? endsAt, Duration? left}) => TimerRun(
    steps: steps,
    cold: cold,
    autoStart: autoStart,
    index: index,
    endsAt: endsAt,
    left: left,
  );
}
