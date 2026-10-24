// Pure Dart. No Flutter imports. Formulas: spec/PRD.md §4.
import 'dart:math';

import 'presets.dart';

export 'presets.dart';

// ponytail: calibration knob. Hydration pp per 1 % protein above 12.5.
const double kHydrationSlope = 1.0;
// ponytail: calibration knob. Absorption floor for wholegrain flour, %.
const double kWholegrainAbsorption = 75;
// ponytail: calibration knob. Yeast activity doubles every this many °C.
// Placeholder until the TXCraig1 table is fitted (PRD §11).
const double kYeastDoublingC = 10;
// ponytail: calibration knob. Fridge-only plans under-dose; PRD §4.5.
const double kFridgeOnlyBoost = 1.30;
// ponytail: calibration knob. Final-dough yeast share when a preferment exists.
const double kPrefermentFinalYeast = 0.5;

class FlourShare {
  const FlourShare(this.flour, this.sharePct);
  final Flour flour;
  final double sharePct;
}

enum EntryMode { flour, pizzas }

class RecipeInputs {
  const RecipeInputs({
    required this.style,
    this.mode = EntryMode.flour,
    this.flourG = 1000,
    this.pizzas = 4,
    this.diameterCm = 30,
    this.panWCm = 25,
    this.panLCm = 35,
    this.thickness = 1.0,
    this.flours = const [FlourShare(Flour.ukStrong, 100)],
    this.plan,
    this.yeast = Yeast.idy,
    this.preferment = Preferment.none,
    this.hydrationOverride,
    this.saltPct,
    this.oilPct,
    this.sugarPct,
    this.residuePct,
    this.yeastKnob = 1.0,
  });

  final PizzaStyle style;
  final EntryMode mode;
  final double flourG;
  final int pizzas;
  final double diameterCm, panWCm, panLCm;
  /// ×0.85 thin, ×1.0 std, ×1.15 thick.
  final double thickness;
  final List<FlourShare> flours;
  final List<Stage>? plan;
  final Yeast yeast;
  final Preferment preferment;
  /// Hydration % as typed by the user; skips the flour model.
  final double? hydrationOverride;
  final double? saltPct, oilPct, sugarPct, residuePct;
  /// "My kitchen runs fast/slow". 1.0 = model as is.
  final double yeastKnob;
}

class Line {
  const Line(this.name, this.grams);
  final String name;
  final double grams;
  @override
  String toString() => '$name $grams g';
}

class RecipeOutputs {
  const RecipeOutputs({
    required this.preferment,
    required this.finalDough,
    required this.totalFlourG,
    required this.totalDoughG,
    required this.ballWeightG,
    required this.ballCount,
    required this.hydrationPct,
    required this.proteinPct,
    required this.yeastPct,
    required this.warnings,
  });
  /// Empty when no preferment.
  final List<Line> preferment;
  final List<Line> finalDough;
  final double totalFlourG, totalDoughG, ballWeightG;
  final int ballCount;
  /// Effective (displayed) hydration and protein of the blend.
  final double hydrationPct, proteinPct;
  /// Whole-plan yeast % of total flour, in the chosen yeast type.
  final double yeastPct;
  final List<String> warnings;
}

double _r(double v, double step) => (v / step).round() * step;
double r1(double v) => _r(v, 1);
double r01(double v) => double.parse(_r(v, 0.1).toStringAsFixed(1));
double r001(double v) => double.parse(_r(v, 0.01).toStringAsFixed(2));

/// Effective protein over white flours only (renormalised). PRD §4.3.
double effectiveProtein(List<FlourShare> flours) {
  final white = flours.where((f) => !f.flour.wholegrain);
  final share = white.fold(0.0, (s, f) => s + f.sharePct);
  if (share == 0) return flours.first.flour.proteinPct;
  return white.fold(0.0, (s, f) => s + f.sharePct * f.flour.proteinPct) / share;
}

/// Displayed hydration % for the blend. PRD §4.3.
double blendHydration(PizzaStyle style, List<FlourShare> flours) {
  final hWhite = (style.hydration + kHydrationSlope * (effectiveProtein(flours) - 12.5))
      .clamp(style.hMin, style.hMax);
  return flours.fold(0.0, (w, f) {
    final h = f.flour.wholegrain ? max(hWhite + 10, kWholegrainAbsorption) : hWhite;
    return w + f.sharePct * h / 100;
  });
}

/// IDY % of total flour for the whole plan. PRD §4.5.
double idyPct(PizzaStyle style, List<Stage> plan) {
  // Each stage converted to equivalent hours at 20 °C, then yeast ∝ 1/time.
  final eqHours = plan.fold(0.0, (s, st) => s + st.hours * pow(2, (st.tempC - 20) / kYeastDoublingC));
  var idy = style.idyRef * 24 / max(eqHours, 0.5);
  if (plan.every((s) => s.fridge)) idy *= kFridgeOnlyBoost;
  return idy;
}

RecipeOutputs calc(RecipeInputs i) {
  final s = i.style;
  final plan = i.plan ?? s.plan;
  final warnings = <String>[];

  final hyd = i.hydrationOverride ?? blendHydration(s, i.flours);
  final salt = i.saltPct ?? s.salt;
  final oil = i.oilPct ?? s.oil;
  final sugar = i.sugarPct ?? s.sugar;
  final residue = i.residuePct ?? s.residue;
  final protein = effectiveProtein(i.flours);

  final sour = i.yeast == Yeast.sourdough;
  final pref = sour && i.preferment.kind == PrefermentKind.none
      ? Preferment.sourdough
      : i.preferment;
  final hasPref = pref.kind != PrefermentKind.none;

  var yeastPct = sour ? 0.0 : idyPct(s, plan) * i.yeast.factor * i.yeastKnob;
  if (hasPref && !sour) yeastPct *= kPrefermentFinalYeast;

  // Total dough per 100 g flour.
  final pctSum = 100 + hyd + salt + oil + sugar + yeastPct;

  double totalFlour;
  int balls;
  double ballWeight;
  if (i.mode == EntryMode.flour) {
    totalFlour = i.flourG;
    final dough = totalFlour * pctSum / 100 / (1 + residue / 100);
    final areaCm2 = s.shape == Shape.round ? pi * pow(i.diameterCm / 2, 2) : i.panWCm * i.panLCm;
    ballWeight = areaCm2 * s.gPerCm2 * i.thickness;
    balls = max(1, (dough / ballWeight).round());
    ballWeight = dough / balls;
  } else {
    final areaCm2 = s.shape == Shape.round ? pi * pow(i.diameterCm / 2, 2) : i.panWCm * i.panLCm;
    balls = i.pizzas;
    ballWeight = areaCm2 * s.gPerCm2 * i.thickness;
    totalFlour = ballWeight * balls * (1 + residue / 100) / (pctSum / 100);
  }

  final totalWater = totalFlour * hyd / 100;
  final prefFlour = hasPref ? totalFlour * pref.flourShare / 100 : 0.0;
  final prefWater = prefFlour * pref.hydration / 100;

  final prefLines = <Line>[];
  if (hasPref) {
    prefLines.add(Line('Flour', r1(prefFlour)));
    prefLines.add(Line('Water', r1(prefWater)));
    if (pref.idyPctOfPrefFlour > 0) {
      prefLines.add(Line('IDY', r001(prefFlour * pref.idyPctOfPrefFlour / 100)));
    }
  }

  final finalLines = <Line>[];
  final finalFlour = totalFlour - prefFlour;
  if (i.flours.length == 1) {
    finalLines.add(Line(i.flours.first.flour.name, r1(finalFlour)));
  } else {
    for (final f in i.flours) {
      finalLines.add(Line(f.flour.name, r1(finalFlour * f.sharePct / 100)));
    }
  }
  finalLines.add(Line('Water', r1(totalWater - prefWater)));
  finalLines.add(Line('Salt', r01(totalFlour * salt / 100)));
  if (sour) {
    finalLines.add(Line('Starter', r1(prefFlour + prefWater)));
  } else {
    finalLines.add(Line(i.yeast.name.toUpperCase(), r001(totalFlour * yeastPct / 100)));
  }
  if (oil > 0) finalLines.add(Line('Oil', r01(totalFlour * oil / 100)));
  if (sugar > 0) finalLines.add(Line(s == PizzaStyle.roman ? 'Malt' : 'Sugar', r01(totalFlour * sugar / 100)));

  if (protein < 11 && s != PizzaStyle.neapolitan && s != PizzaStyle.thin ||
      hyd > 70 && protein < 12) {
    warnings.add('Weak flour for this style; expect tearing or a flat crust. Blend in strong flour.');
  }
  if (i.flours.any((f) => f.flour.wholegrain)) {
    warnings.add('Wholegrain in the mix: autolyse or soak the bran 30 min before adding salt and yeast.');
  }
  if (!sour && totalFlour * yeastPct / 100 < 0.1) {
    warnings.add('Yeast under 0.1 g: use a pinch, make a yeast slurry, or scale the batch up.');
  }

  return RecipeOutputs(
    preferment: prefLines,
    finalDough: finalLines,
    totalFlourG: r1(totalFlour),
    totalDoughG: r1(totalFlour * pctSum / 100),
    ballWeightG: r1(ballWeight),
    ballCount: balls,
    hydrationPct: r01(hyd),
    proteinPct: r01(protein),
    yeastPct: r001(yeastPct),
    warnings: warnings,
  );
}
