// Pure Dart. No Flutter imports. Recipe wording shared by the Recipe screen
// and the plain-text export (PRD §4.6 "Copy as plain text").
import 'calc.dart';
import 'oven.dart';
import 'schedule.dart';

String prefermentLabel(PrefermentKind kind) => switch (kind) {
  PrefermentKind.poolish => 'Poolish',
  PrefermentKind.biga => 'Biga',
  PrefermentKind.sourdough => 'Starter',
  PrefermentKind.none => 'Preferment',
};

/// Display name for a calc line; yeast types are spelled out.
String lineLabel(Line l) => switch (l.name) {
  'IDY' => 'Instant yeast',
  'ADY' => 'Active dry yeast',
  'FRESH' => 'Fresh yeast',
  _ => l.name,
};

/// Grams at the step calc rounded to (FR6).
String gramsText(Line l) => '${l.grams.toStringAsFixed(l.decimals)} g';

/// Baker's % of total flour, as the formula has it (not from rounded grams).
String pctOfFlour(Line l) => '${pctText(l.pct)}%';

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Fri 19:00".
String clockText(DateTime t) =>
    '${_days[t.weekday - 1]} ${_two(t.hour)}:${_two(t.minute)}';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "Fri 17 Oct" (bake log).
String dayText(DateTime t) =>
    '${_days[t.weekday - 1]} ${t.day} ${_months[t.month - 1]}';

/// Absolute start when a bake time is set, else the offset from the start.
String whenText(ScheduleItem item) {
  final at = item.at;
  if (at != null) return clockText(at);
  return item.startOffset == Duration.zero
      ? 'Start'
      : '+${hmText(item.startOffset)}';
}

/// "New York · 2 × 35 cm · UK strong white · steel". Sizes to one decimal in
/// the chosen [unit].
String summaryText(
  RecipeInputs i,
  RecipeOutputs o,
  OvenSetup oven, {
  LengthUnit unit = LengthUnit.cm,
}) {
  String len(double cm) => pctText(r01(unit.fromCm(cm)));
  final size = i.style.shape == Shape.round
      ? len(i.diameterCm)
      : '${len(i.panWCm)}×${len(i.panLCm)}';
  final flour = i.flours.map((f) => f.flour.name).join(' + ');
  return '${i.style.label} · ${o.ballCount} × $size ${unit.label} · $flour · '
      '${oven.name.toLowerCase()}';
}

/// "2 balls · 370 g" or "1 pan · 413 g".
String yieldText(RecipeInputs i, RecipeOutputs o) {
  final unit = i.style.shape == Shape.round ? 'ball' : 'pan';
  final n = o.ballCount;
  return '$n ${n == 1 ? unit : '${unit}s'} · '
      '${o.ballWeightG.toStringAsFixed(0)} g';
}

/// Short rule-based explanation: flour protein → hydration, enrichments
/// against the oven heat, surface against hydration.
String whyTheseNumbers(RecipeInputs i, RecipeOutputs o, OvenSetup oven) {
  final s = i.style;
  final hyd = pctText(o.hydrationPct);
  final out = <String>[];

  if (i.hydrationOverride != null) {
    out.add('Hydration set by hand to $hyd%, so the flour model is skipped.');
  } else {
    final flour = i.flours.length == 1
        ? i.flours.single.flour.name
        : 'Your blend';
    final head = '$flour at ${pctText(o.proteinPct)}% protein';
    final d = o.hydrationPct - s.hydration;
    out.add(
      d.abs() < 0.05
          ? '$head keeps ${s.label} at its $hyd% base hydration.'
          : '$head ${d > 0 ? 'lifts' : 'lowers'} ${s.label} hydration '
                '${pctText(d.abs())} pp to $hyd%.',
    );
    if (i.flours.any((f) => f.flour.wholegrain)) {
      out.add(
        'The wholegrain share absorbs more water, so it gets at least '
        '${pctText(i.wholegrainAbsorption)}%.',
      );
    }
  }

  final sugar = i.sugarPct ?? s.sugar;
  final oil = i.oilPct ?? s.oil;
  final sweet = sweetenerName(s);
  final heat = '${oven.maxTempC} °C';
  if (!oven.isHome) {
    out.add(
      sugar > 0
          ? '$sweet ${pctText(sugar)}% can scorch at $heat; watch the rim.'
          : 'At $heat the crust colours from heat alone.',
    );
    return out.join(' ');
  }
  final enrich = [
    if (sugar > 0) '$sweet ${pctText(sugar)}%',
    if (oil > 0) 'oil ${pctText(oil)}%',
  ];
  if (enrich.isEmpty) {
    out.add('A lean dough browns slowly at $heat.');
  } else {
    final list = enrich.join(' and ');
    out.add(
      '${list[0].toUpperCase()}${list.substring(1)} '
      '${enrich.length == 1 ? 'gives' : 'give'} colour at $heat that a lean '
      'dough would not get.',
    );
  }

  final cap = hydrationCap(oven);
  if (s.shape == Shape.rect) {
    out.add('In the pan, oil fries the base, so the surface matters less.');
  } else if (s == PizzaStyle.neapolitan && o.hydrationPct > cap) {
    out.add(
      'Above ${pctText(cap)}% the base steams before it browns in a home oven.',
    );
  } else {
    out.add(switch (oven.surface) {
      Surface.steel =>
        'Steel browns the base in time, so no need to lower hydration.',
      Surface.stone =>
        'Stone browns the base slower than steel, so the bake runs a little '
            'longer.',
      Surface.none => 'A tray heats the base slowly, so the bake runs longer.',
    });
  }
  return out.join(' ');
}

/// The whole recipe as plain text for the clipboard.
String recipeText({
  required RecipeInputs inputs,
  required RecipeOutputs outputs,
  required OvenSetup oven,
  required List<ScheduleItem> schedule,
  required ({int celsius, String caption}) water,
  LengthUnit unit = LengthUnit.cm,
}) {
  final o = outputs;
  final bake = bakeCard(inputs.style, oven);
  String table(String title, List<Line> lines) => [
    title,
    for (final l in lines)
      '- ${lineLabel(l)}: ${gramsText(l)} (${pctOfFlour(l)})',
    '',
  ].join('\n');

  return [
    summaryText(inputs, o, oven, unit: unit),
    'Hydration ${pctText(o.hydrationPct)}% · '
        'protein ${pctText(o.proteinPct)}%',
    '',
    if (o.preferment.isNotEmpty)
      table(prefermentLabel(effectivePreferment(inputs).kind), o.preferment),
    table('Final dough', o.finalDough),
    'Water ${water.celsius} °C ${water.caption}',
    'Yield ${yieldText(inputs, o)} · '
        'total dough ${o.totalDoughG.toStringAsFixed(0)} g',
    '',
    'Schedule',
    for (final s in schedule) '- ${whenText(s)} ${s.name}. ${s.note}',
    '',
    'Bake: ${bake.title}',
    bake.subtitle,
    for (final (n, step) in bake.steps.indexed) '${n + 1}. $step',
    '',
  ].join('\n');
}

String _two(int n) => '$n'.padLeft(2, '0');
