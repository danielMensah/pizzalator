// Pure Dart. No Flutter imports. Dough handling routine: spec/PRD.md §4.7.
import 'presets.dart';

enum StepKind { active, rest }

class RoutineStep {
  const RoutineStep({
    required this.name,
    required this.kind,
    required this.minutes,
    this.note = '',
    this.bindsToPlan = false,
  });

  factory RoutineStep.fromJson(Map<String, Object?> json) => RoutineStep(
    name: json['name'] as String,
    kind: StepKind.values.byName(json['kind'] as String),
    minutes: json['minutes'] as int,
    note: json['note'] as String? ?? '',
    bindsToPlan: json['bindsToPlan'] as bool? ?? false,
  );

  final String name;
  final StepKind kind;

  /// Planned length. Untimed active steps keep an estimate for planning.
  final int minutes;
  final String note;

  /// Duration comes from the fermentation plan (step 10, bulk).
  final bool bindsToPlan;

  RoutineStep copyWith({
    String? name,
    StepKind? kind,
    int? minutes,
    String? note,
    bool? bindsToPlan,
  }) => RoutineStep(
    name: name ?? this.name,
    kind: kind ?? this.kind,
    minutes: minutes ?? this.minutes,
    note: note ?? this.note,
    bindsToPlan: bindsToPlan ?? this.bindsToPlan,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'kind': kind.name,
    'minutes': minutes,
    'note': note,
    'bindsToPlan': bindsToPlan,
  };
}

class RoutinePreset {
  const RoutinePreset({
    required this.name,
    required this.steps,
    this.builtIn = false,
  });

  /// Anything read back from disk is a user preset.
  factory RoutinePreset.fromJson(Map<String, Object?> json) => RoutinePreset(
    name: json['name'] as String,
    steps: [
      for (final s in json['steps'] as List<Object?>)
        RoutineStep.fromJson(s as Map<String, Object?>),
    ],
  );

  final String name;
  final List<RoutineStep> steps;

  /// The built-in default: read-only, cannot be deleted.
  final bool builtIn;

  Map<String, Object?> toJson() => {
    'name': name,
    'steps': [for (final s in steps) s.toJson()],
  };
}

const _a = StepKind.active;
const _r = StepKind.rest;

/// The user's own sequence, PRD §4.7 table.
const defaultRoutine = RoutinePreset(
  name: 'My default',
  builtIn: true,
  steps: [
    RoutineStep(
      name: 'Mix all ingredients',
      kind: _a,
      minutes: 5,
      note: 'Water, yeast, sugar, flour; salt and oil after a short rest',
    ),
    RoutineStep(
      name: 'Rest in bowl, covered',
      kind: _r,
      minutes: 30,
      note: 'Cover with napkins / cloth',
    ),
    RoutineStep(name: 'Fold in bowl 4–6×', kind: _a, minutes: 2),
    RoutineStep(name: 'Rest, covered', kind: _r, minutes: 15),
    RoutineStep(name: 'Fold in bowl again', kind: _a, minutes: 2),
    RoutineStep(name: 'Rest, covered', kind: _r, minutes: 15),
    RoutineStep(
      name: 'Knead on the counter',
      kind: _a,
      minutes: 10,
      note: 'Timed active step',
    ),
    RoutineStep(name: 'Rest on counter, covered', kind: _r, minutes: 30),
    RoutineStep(
      name: 'Stretch, fold, shape one ball',
      kind: _a,
      minutes: 5,
      note: 'Folding traps air; into the container',
    ),
    RoutineStep(
      name: 'Bulk in container',
      kind: _r,
      minutes: 240,
      note: 'Room bulk from the plan; a cold plan then goes in the fridge.',
      bindsToPlan: true,
    ),
    RoutineStep(
      name: 'Divide into balls',
      kind: _a,
      minutes: 5,
      note: 'Then final proof per plan',
    ),
  ],
);

/// Room bulk and fridge minutes of [plan], read like the Ferment screen: the
/// dough bulks in its container, then (cold plan) goes in the fridge, then
/// is divided. A warm-up follows dividing, so it is not part of the routine.
({int room, int fridge}) bulkMinutes(List<Stage> plan) {
  final p = StagePlan.of(plan);
  return (room: (p.roomH * 60).round(), fridge: (p.fridgeH * 60).round());
}

/// A bound step lasts the plan's room bulk plus its fridge hours. No plan:
/// its own minutes.
Duration stepDuration(RoutineStep step, List<Stage> plan) {
  if (!step.bindsToPlan || plan.isEmpty) return Duration(minutes: step.minutes);
  final b = bulkMinutes(plan);
  return Duration(minutes: b.room + b.fridge);
}

/// Mix + hands-on: every step before the bound one (all steps if none binds).
Duration handsOnDuration(List<RoutineStep> steps) => Duration(
  minutes: steps
      .takeWhile((s) => !s.bindsToPlan)
      .fold(0, (m, s) => m + s.minutes),
);

/// Every step after the bound one (divide, by default); zero if none binds.
Duration afterBulkDuration(List<RoutineStep> steps) => Duration(
  minutes: steps
      .skipWhile((s) => !s.bindsToPlan)
      .skip(1)
      .fold(0, (m, s) => m + s.minutes),
);

Duration routineTotal(List<RoutineStep> steps, List<Stage> plan) =>
    steps.fold(Duration.zero, (t, s) => t + stepDuration(s, plan));
