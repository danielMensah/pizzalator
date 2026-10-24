// Pure Dart. No Flutter imports. Saved recipes and their JSON: spec/PRD.md
// §5 (save/load), FR9 (export/import for backup).
import 'dart:convert';

import 'calc.dart';
import 'oven.dart';
import 'routine.dart';

/// From the clock, so ids sort by age; bumped past any already [taken].
String clockId(DateTime now, bool Function(String id) taken) {
  var n = now.microsecondsSinceEpoch;
  while (taken(n.toRadixString(36))) {
    n++;
  }
  return n.toRadixString(36);
}

/// What an export says it is.
const kRecipesFormat = 'pizzalator.recipes';
const kRecipesVersion = 1;

/// Every input, overrides and knobs included; flours as snapshots.
Map<String, Object?> inputsToJson(RecipeInputs i) => {
  'style': i.style.name,
  'mode': i.mode.name,
  'flourG': i.flourG,
  'pizzas': i.pizzas,
  'diameterCm': i.diameterCm,
  'panWCm': i.panWCm,
  'panLCm': i.panLCm,
  'thickness': i.thickness,
  'flours': [
    for (final f in i.flours)
      {'flour': f.flour.toJson(), 'sharePct': f.sharePct},
  ],
  'plan': i.plan == null
      ? null
      : [
          for (final s in i.plan!) {'hours': s.hours, 'tempC': s.tempC},
        ],
  'yeast': i.yeast.name,
  'preferment': {
    'kind': i.preferment.kind.name,
    'flourShare': i.preferment.flourShare,
    'hydration': i.preferment.hydration,
    'hours': i.preferment.hours,
    'tempC': i.preferment.tempC,
  },
  'hydrationPct': i.hydrationOverride,
  'saltPct': i.saltPct,
  'oilPct': i.oilPct,
  'sugarPct': i.sugarPct,
  'residuePct': i.residuePct,
  'yeastKnob': i.yeastKnob,
  'hydrationSlope': i.hydrationSlope,
  'wholegrainAbsorption': i.wholegrainAbsorption,
  // In Pct order, so equal inputs always write equal JSON.
  'fromTip': [
    for (final p in Pct.values)
      if (i.fromTip.contains(p)) p.name,
  ],
};

/// Throws an [Error] on a wrong shape, or on values no stepper can reach
/// and calc() cannot compute (a hand-edited or truncated backup).
RecipeInputs inputsFromJson(Map<String, Object?> j) {
  final i = _inputsFromJson(j);
  final sizes = [i.flourG, i.diameterCm, i.panWCm, i.panLCm, i.thickness];
  if (i.flours.isEmpty ||
      i.flours.length > kMaxFlours ||
      i.pizzas < 1 ||
      !sizes.every((v) => v.isFinite && v > 0)) {
    throw ArgumentError('Inputs out of range');
  }
  calc(i); // anything else calc() throws on is refused too
  return i;
}

RecipeInputs _inputsFromJson(Map<String, Object?> j) {
  double n(String key) => _num(j, key);
  double? opt(String key) => (j[key] as num?)?.toDouble();
  final p = _map(j['preferment']);
  final plan = switch (j['plan']) {
    null => null,
    final list => [
      for (final s in list as List<Object?>)
        Stage(_num(_map(s), 'hours'), _num(_map(s), 'tempC')),
    ],
  };
  return RecipeInputs(
    style: PizzaStyle.values.byName(j['style']! as String),
    mode: EntryMode.values.byName(j['mode']! as String),
    flourG: n('flourG'),
    pizzas: (j['pizzas']! as num).toInt(),
    diameterCm: n('diameterCm'),
    panWCm: n('panWCm'),
    panLCm: n('panLCm'),
    thickness: n('thickness'),
    flours: [
      for (final f in j['flours']! as List<Object?>)
        FlourShare(
          Flour.fromJson(_map(_map(f)['flour'])),
          _num(_map(f), 'sharePct'),
        ),
    ],
    // withYeast tells the sourdough plan it set by identity.
    plan: plan != null && _samePlan(plan, kSourdoughPlan)
        ? kSourdoughPlan
        : plan,
    yeast: Yeast.values.byName(j['yeast']! as String),
    preferment: Preferment(
      PrefermentKind.values.byName(p['kind']! as String),
      flourShare: _num(p, 'flourShare'),
      hydration: _num(p, 'hydration'),
      hours: _num(p, 'hours'),
      tempC: _num(p, 'tempC'),
    ),
    hydrationOverride: opt('hydrationPct'),
    saltPct: opt('saltPct'),
    oilPct: opt('oilPct'),
    sugarPct: opt('sugarPct'),
    residuePct: opt('residuePct'),
    yeastKnob: n('yeastKnob'),
    hydrationSlope: n('hydrationSlope'),
    wholegrainAbsorption: n('wholegrainAbsorption'),
    fromTip: {
      for (final t in j['fromTip']! as List<Object?>)
        Pct.values.byName(t! as String),
    },
  );
}

Map<String, Object?> _map(Object? json) => json! as Map<String, Object?>;

/// A hand-edited file may say 800 for 800.0.
double _num(Map<String, Object?> j, String key) => (j[key]! as num).toDouble();

bool _samePlan(List<Stage> a, List<Stage> b) =>
    a.length == b.length && a.indexed.every((s) => s.$2 == b[s.$1]);

Map<String, Object?> ovenToJson(OvenSetup o) => {
  'kind': o.kind.name,
  'surface': o.surface.name,
  'maxTempC': o.maxTempC,
};

OvenSetup ovenFromJson(Map<String, Object?> j) => OvenSetup(
  kind: OvenKind.values.byName(j['kind']! as String),
  surface: Surface.values.byName(j['surface']! as String),
  maxTempC: (j['maxTempC']! as num).toInt(),
);

/// A named recipe (PRD §5): inputs, oven and the routine it bakes with.
class SavedRecipe {
  const SavedRecipe({
    required this.id,
    required this.name,
    required this.inputs,
    required this.oven,
    this.routine,
    required this.savedAt,
  });

  /// Throws on a wrong shape; [parseRecipe] does not.
  factory SavedRecipe.fromJson(Map<String, Object?> j) => SavedRecipe(
    id: j['id']! as String,
    name: j['name']! as String,
    inputs: inputsFromJson(_map(j['inputs'])),
    oven: ovenFromJson(_map(j['oven'])),
    routine: switch (j['routine']) {
      null => null,
      // No steps: the routines file refuses it, and timers cannot run it.
      final r => switch (RoutinePreset.fromJson(_map(r))) {
        final p when p.steps.isNotEmpty => p,
        _ => throw ArgumentError('Routine without steps'),
      },
    },
    savedAt: DateTime.parse(j['savedAt']! as String),
  );

  final String id, name;
  final RecipeInputs inputs;
  final OvenSetup oven;

  /// Null: the built-in routine.
  final RoutinePreset? routine;
  final DateTime savedAt;

  SavedRecipe copyWith({String? id, String? name, DateTime? savedAt}) =>
      SavedRecipe(
        id: id ?? this.id,
        name: name ?? this.name,
        inputs: inputs,
        oven: oven,
        routine: routine,
        savedAt: savedAt ?? this.savedAt,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'inputs': inputsToJson(inputs),
    'oven': ovenToJson(oven),
    'routine': routine?.toJson(),
    // UTC, so an export reads the same on a phone in another time zone.
    'savedAt': savedAt.toUtc().toIso8601String(),
  };
}

/// Null for anything that is not a recipe this build can read.
SavedRecipe? parseRecipe(Object? json) {
  try {
    return SavedRecipe.fromJson(_map(json));
  } on Error {
    return null; // wrong shape: older, newer or hand-edited
  } on FormatException {
    return null; // a date that is not one
  }
}

/// FR9 backup: pretty-printed, so it reads in a notes app.
String exportRecipes(List<SavedRecipe> recipes) =>
    const JsonEncoder.withIndent('  ').convert({
      'format': kRecipesFormat,
      'version': kRecipesVersion,
      'recipes': [for (final r in recipes) r.toJson()],
    });

/// The recipes in an export; ones that do not read are skipped. Throws a
/// [FormatException] when [text] is not an export.
List<SavedRecipe> importRecipes(String text) {
  final json = jsonDecode(text);
  if (json case {
    'format': kRecipesFormat,
    'version': kRecipesVersion,
    'recipes': final List<Object?> list,
  }) {
    return [for (final r in list) ?parseRecipe(r)];
  }
  throw const FormatException('Not a Pizzalator recipe export');
}
