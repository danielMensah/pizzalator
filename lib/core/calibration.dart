// Pure Dart. No Flutter imports. Calibration hints: spec/PRD.md §5,
// mockups/BakeLog.dc.html. Suggest-only: a hint returns edited copies and
// changes nothing until the UI applies it.
import 'dart:math';

import 'bake_log.dart';
import 'calc.dart';
import 'oven.dart';

// ponytail: calibration knob. Newest bakes at the current value that must all
// agree before a rule speaks.
const int kHintMinLogs = 2;
// ponytail: calibration knob. Hydration step for "too wet" / "too dry", pp.
const double kHintHydrationStepPp = 2;
// ponytail: calibration knob. Yeast knob step for under / over proofed.
const double kHintYeastKnobStep = 0.15;
// ponytail: calibration knob. What the yeast knob may reach (FR5 panel range).
const double kYeastKnobMin = 0.5, kYeastKnobMax = 2.0;
// ponytail: calibration knob. Sugar step for a pale crust in a home oven, %.
const double kHintSugarStepPct = 1;
// ponytail: calibration knob. Diastatic malt step for Roman teglia, %.
const double kHintMaltStepPct = 0.5;
// ponytail: calibration knob. Max temperature drop for a burnt bottom on steel.
const int kHintSteelCoolerC = 25;

/// One rule's suggestion with its one-tap edit: [apply] for the recipe or
/// [applyOven] for the oven, never both.
class CalibrationHint {
  const CalibrationHint({
    required this.id,
    required this.title,
    required this.text,
    required this.applyLabel,
    required this.done,
    this.apply,
    this.applyOven,
  });

  /// Rule and the newest bake it read: a newer log raises a dismissed hint
  /// again.
  final String id;

  /// Card label, e.g. "Calibration hint · Friday NY".
  final String title;
  final String text, applyLabel;

  /// Toast once applied.
  final String done;
  final RecipeInputs Function(RecipeInputs)? apply;
  final OvenSetup Function(OvenSetup)? applyOven;
}

/// Flours by name and share, order aside.
String _mix(RecipeInputs i) => ([
  for (final f in i.flours) '${f.flour.name}:${f.sharePct}',
]..sort()).join('|');

String _knob(double v) => '${(v * 100).round()}%';

/// What the bake [log] (newest first) says about the current [inputs] and
/// [oven]; [name] labels the cards. Only bakes of the same style and flour
/// mix count, and each rule reads only those logged at the current value of
/// what it tunes, so an applied hint goes away until new bakes back it.
List<CalibrationHint> calibrationHints(
  List<BakeEntry> log,
  RecipeInputs inputs,
  OvenSetup oven, {
  required String name,
}) {
  final mix = _mix(inputs);
  final relevant = [
    for (final e in log)
      if (e.inputs.style == inputs.style && _mix(e.inputs) == mix) e,
  ];
  final title = 'Calibration hint · $name';
  final two = kHintMinLogs == 2 ? 'Two' : '$kHintMinLogs';
  final hints = <CalibrationHint>[];

  /// Adds the hint when the newest [kHintMinLogs] relevant bakes at the
  /// current [value] (and [where] they apply) all logged [choice] for [o].
  void rule(
    Outcome o,
    int choice,
    Object Function(RecipeInputs, OvenSetup) value,
    CalibrationHint Function(String id) hint, {
    bool Function(BakeEntry)? where,
  }) {
    final now = value(inputs, oven);
    final at = relevant
        .where(
          (e) => (where?.call(e) ?? true) && value(e.inputs, e.oven) == now,
        )
        .take(kHintMinLogs)
        .toList();
    if (at.length == kHintMinLogs && at.every((e) => e.choice(o) == choice)) {
      hints.add(hint('${o.name}$choice:${at.first.id}'));
    }
  }

  // Dough feel: hydration as displayed, so a 0.04 % model drift is no change.
  final hyd = r01(Pct.hydration.value(inputs));
  final flours = [for (final f in inputs.flours) f.flour.name].join(' + ');
  for (final (choice, sign) in const [(0, -1), (2, 1)]) {
    final to = r01(hyd + sign * kHintHydrationStepPp);
    rule(
      Outcome.dough,
      choice,
      (i, _) => r01(Pct.hydration.value(i)),
      (id) => CalibrationHint(
        id: id,
        title: title,
        text:
            '$two bakes logged "${Outcome.dough.tags[choice]}" with $flours. '
            'Suggest hydration ${pctText(hyd)}% → ${pctText(to)}% on this '
            'recipe.',
        applyLabel:
            'Apply ${sign < 0 ? '−' : '+'}${pctText(kHintHydrationStepPp)} pp',
        done: 'Hydration now ${pctText(to)}%',
        apply: (i) => i.set(Pct.hydration, to),
      ),
    );
  }

  // Proof: the yeast knob, which moves no starter.
  if (inputs.yeast != Yeast.sourdough) {
    final knob = r001(inputs.yeastKnob);
    for (final (choice, sign) in const [(0, 1), (2, -1)]) {
      final to = r001(
        (knob + sign * kHintYeastKnobStep).clamp(kYeastKnobMin, kYeastKnobMax),
      );
      // At the end of the range a hint would change nothing, forever.
      if (to == knob) continue;
      rule(
        Outcome.proof,
        choice,
        (i, _) => r001(i.yeastKnob),
        (id) => CalibrationHint(
          id: id,
          title: title,
          text:
              '$two bakes logged "${Outcome.proof.tags[choice]}" at yeast '
              'knob ${_knob(knob)}. Suggest ${_knob(to)} on this recipe.',
          applyLabel:
              'Apply ${sign < 0 ? '−' : '+'}${_knob(kHintYeastKnobStep)}',
          done: 'Yeast knob now ${_knob(to)}',
          apply: (i) => i.copyWith(yeastKnob: to),
        ),
      );
    }
  }

  // Pale crust in a home oven: more sugar, or malt for Roman.
  if (oven.isHome) {
    final roman = inputs.style == PizzaStyle.roman;
    final step = roman ? kHintMaltStepPct : kHintSugarStepPct;
    final what = sweetenerName(inputs.style).toLowerCase();
    final sugar = r01(Pct.sugar.value(inputs));
    final to = r01(sugar + step);
    rule(
      Outcome.crust,
      0,
      (i, _) => r01(Pct.sugar.value(i)),
      where: (e) => e.oven.isHome,
      (id) => CalibrationHint(
        id: id,
        title: title,
        text:
            '$two bakes came out pale in a home oven. Suggest $what '
            '${pctText(sugar)}% → ${pctText(to)}% on this recipe.',
        applyLabel: 'Apply +${pctText(step)}% $what',
        done: '${sweetenerName(inputs.style)} now ${pctText(to)}%',
        apply: (i) => i.set(Pct.sugar, to),
      ),
    );
  }

  // Burnt bottom on a home steel: bake cooler.
  bool steel(OvenSetup o) => o.isHome && o.surface == Surface.steel;
  if (steel(oven)) {
    final to = max(oven.maxTempRange.$1, oven.maxTempC - kHintSteelCoolerC);
    if (to != oven.maxTempC) {
      rule(
        Outcome.bottom,
        2,
        (_, o) => o.maxTempC,
        where: (e) => steel(e.oven),
        (id) => CalibrationHint(
          id: id,
          title: title,
          text:
              '$two bakes logged "${Outcome.bottom.tags[2]}" on the steel. '
              'Raise it a rack or bake cooler: max ${oven.maxTempC} °C → '
              '$to °C.',
          applyLabel: 'Apply −$kHintSteelCoolerC °C',
          done: 'Max temp now $to °C',
          applyOven: (o) => o.copyWith(maxTempC: to),
        ),
      );
    }
  }
  return hints;
}
