// Pure Dart. No Flutter imports. Formulas: spec/PRD.md §4.
import 'dart:math';

import 'presets.dart';

export 'presets.dart';

// ponytail: calibration knob. Default k: hydration pp per 1 % protein above
// kRefProteinPct. The Advanced panel can change it per recipe.
const double kHydrationSlope = 1.0;
// ponytail: calibration knob. Protein the style hydrations are written for.
const double kRefProteinPct = 12.5;
// ponytail: calibration knob. Default absorption floor for wholegrain flour, %.
const double kWholegrainAbsorption = 75;
// ponytail: calibration knob. Wholegrain takes this many pp over the white.
const double kWholegrainExtraPp = 10;
// ponytail: calibration knob. Yeast activity doubles every this many °C.
// Mockup model until the TXCraig1 table is fitted (PRD §11).
const double kYeastDoublingC = 8;
// ponytail: calibration knob. Plans shorter than this count as this long.
const double kMinEqHours = 2;
// ponytail: calibration knob. Model IDY is kept inside this range, %.
const double kIdyMinPct = 0.03, kIdyMaxPct = 1.2;
// ponytail: calibration knob. Fridge-only plans under-dose; PRD §4.5.
const double kFridgeOnlyBoost = 1.30;
// ponytail: calibration knob. Final-dough yeast share when a preferment exists.
const double kPrefermentFinalYeast = 0.5;
// ponytail: calibration knob. Gluten warning thresholds, PRD §4.3.
const double kWeakProteinPct = 11;
const double kWetDoughHydration = 70, kWetDoughProteinPct = 12;
// ponytail: calibration knob. Below this much yeast, weigh a pinch, g.
const double kPinchG = 0.1;

const kPinchNote =
    'Yeast under 0.1 g: use a pinch, make a yeast slurry, or scale the batch up.';

class FlourShare {
  const FlourShare(this.flour, this.sharePct);
  final Flour flour;
  final double sharePct;
}

enum EntryMode { flour, pizzas }

/// A baker's % the Advanced panel or a tip can override.
enum Pct {
  hydration('Hydration'),
  salt('Salt'),
  oil('Oil'),
  sugar('Sugar'),
  residue('Bowl residue');

  const Pct(this.label);
  final String label;

  /// The override, or null on the style default.
  double? of(RecipeInputs i) => switch (this) {
    hydration => i.hydrationOverride,
    salt => i.saltPct,
    oil => i.oilPct,
    sugar => i.sugarPct,
    residue => i.residuePct,
  };

  /// Without an override: the style's own %, or the flour model's hydration.
  double base(RecipeInputs i) => switch (this) {
    hydration => blendHydration(
      i.style,
      i.flours,
      k: i.hydrationSlope,
      absorption: i.wholegrainAbsorption,
    ),
    salt => i.style.salt,
    oil => i.style.oil,
    sugar => i.style.sugar,
    residue => i.style.residue,
  };

  double value(RecipeInputs i) => of(i) ?? base(i);
}

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
    this.hydrationSlope = kHydrationSlope,
    this.wholegrainAbsorption = kWholegrainAbsorption,
    this.fromTip = const {},
  });

  final PizzaStyle style;
  final EntryMode mode;
  final double flourG;
  final int pizzas;
  final double diameterCm, panWCm, panLCm;

  /// Weight factor; see [thicknessPresets].
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

  /// `k` and the wholegrain absorption of PRD §4.3 (FR5).
  final double hydrationSlope, wholegrainAbsorption;

  /// Overrides a tip applied rather than the user: a style switch drops them
  /// and keeps the rest (FR1).
  final Set<Pct> fromTip;

  List<Stage> get activePlan => plan ?? style.plan;

  RecipeInputs copyWith({
    PizzaStyle? style,
    EntryMode? mode,
    double? flourG,
    int? pizzas,
    double? diameterCm,
    double? panWCm,
    double? panLCm,
    double? thickness,
    List<FlourShare>? flours,
    List<Stage>? plan,
    Yeast? yeast,
    Preferment? preferment,
    double? hydrationOverride,
    double? saltPct,
    double? oilPct,
    double? sugarPct,
    double? residuePct,
    double? yeastKnob,
    double? hydrationSlope,
    double? wholegrainAbsorption,
    Set<Pct>? fromTip,
  }) => RecipeInputs(
    style: style ?? this.style,
    mode: mode ?? this.mode,
    flourG: flourG ?? this.flourG,
    pizzas: pizzas ?? this.pizzas,
    diameterCm: diameterCm ?? this.diameterCm,
    panWCm: panWCm ?? this.panWCm,
    panLCm: panLCm ?? this.panLCm,
    thickness: thickness ?? this.thickness,
    flours: flours ?? this.flours,
    plan: plan ?? this.plan,
    yeast: yeast ?? this.yeast,
    preferment: preferment ?? this.preferment,
    hydrationOverride: hydrationOverride ?? this.hydrationOverride,
    saltPct: saltPct ?? this.saltPct,
    oilPct: oilPct ?? this.oilPct,
    sugarPct: sugarPct ?? this.sugarPct,
    residuePct: residuePct ?? this.residuePct,
    yeastKnob: yeastKnob ?? this.yeastKnob,
    hydrationSlope: hydrationSlope ?? this.hydrationSlope,
    wholegrainAbsorption: wholegrainAbsorption ?? this.wholegrainAbsorption,
    fromTip: fromTip ?? this.fromTip,
  );

  /// [p] set to [v]: by hand (explicit, survives a style switch) or by a tip.
  RecipeInputs set(Pct p, double v, {bool tip = false}) {
    final from = tip ? {...fromTip, p} : fromTip.difference({p});
    return switch (p) {
      Pct.hydration => copyWith(hydrationOverride: v, fromTip: from),
      Pct.salt => copyWith(saltPct: v, fromTip: from),
      Pct.oil => copyWith(oilPct: v, fromTip: from),
      Pct.sugar => copyWith(sugarPct: v, fromTip: from),
      Pct.residue => copyWith(residuePct: v, fromTip: from),
    };
  }

  /// The named overrides back on the style default; [plan] too if asked.
  RecipeInputs clear(Set<Pct> pcts, {bool plan = false}) => RecipeInputs(
    style: style,
    mode: mode,
    flourG: flourG,
    pizzas: pizzas,
    diameterCm: diameterCm,
    panWCm: panWCm,
    panLCm: panLCm,
    thickness: thickness,
    flours: flours,
    plan: plan ? null : this.plan,
    yeast: yeast,
    preferment: preferment,
    hydrationOverride: pcts.contains(Pct.hydration) ? null : hydrationOverride,
    saltPct: pcts.contains(Pct.salt) ? null : saltPct,
    oilPct: pcts.contains(Pct.oil) ? null : oilPct,
    sugarPct: pcts.contains(Pct.sugar) ? null : sugarPct,
    residuePct: pcts.contains(Pct.residue) ? null : residuePct,
    yeastKnob: yeastKnob,
    hydrationSlope: hydrationSlope,
    wholegrainAbsorption: wholegrainAbsorption,
    fromTip: fromTip.difference(pcts),
  );

  /// Back on the style's own baker's %: every override cleared (FR1 "reset
  /// to style"). Amounts, sizes, flours, plan, leavening and knobs stay.
  RecipeInputs resetToStyle() => clear(Pct.values.toSet());
}

/// What a line is, so screens never match on names.
enum LineKind { flour, water, salt, yeast, starter, oil, sugar }

class Line {
  const Line(this.kind, this.name, this.grams, this.pct, [this.decimals = 0]);
  final LineKind kind;
  final String name;

  /// Rounded to the FR6 step; [decimals] says which one.
  final double grams;

  /// Unrounded baker's % of total flour.
  final double pct;
  final int decimals;
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
    required this.notes,
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

  /// Problems with the formula as entered.
  final List<String> warnings;

  /// Technique advice: nothing is wrong.
  final List<String> notes;
}

double _r(double v, double step) => (v / step).round() * step;

/// A number for display: one decimal from 1, two below, zeros trimmed.
/// 100 → "100", 62.50 → "62.5", 0.25 → "0.25". Percentages, hours, grams.
String pctText(double v) {
  final s = v.toStringAsFixed(v < 1 ? 2 : 1);
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}

double r1(double v) => _r(v, 1);
double r01(double v) => double.parse(_r(v, 0.1).toStringAsFixed(1));
double r001(double v) => double.parse(_r(v, 0.01).toStringAsFixed(2));

/// Malt for Roman teglia, sugar for the rest.
String sweetenerName(PizzaStyle s) => s == PizzaStyle.roman ? 'Malt' : 'Sugar';

/// Thin / standard / thick weight factors. Detroit's are its 2.75 / 2.95 /
/// 3.15 g/in² over the 2.95 its weight rule uses (PRD §4.2).
List<double> thicknessPresets(PizzaStyle s) => s == PizzaStyle.detroit
    ? const [2.75 / 2.95, 1, 3.15 / 2.95]
    : const [0.85, 1, 1.15];

/// FR2: up to three flours, shares in whole steps.
const kMaxFlours = 3;
const double kFlourStepPct = 5;

/// FR2: the last row takes whatever the others leave.
List<FlourShare> balanceFlours(List<FlourShare> rows) {
  final others = rows.take(rows.length - 1).toList();
  final used = others.fold(0.0, (s, f) => s + f.sharePct);
  return [...others, FlourShare(rows.last.flour, 100 - used)];
}

/// [flour] as a new last row with up to 20 % from the old last row, in whole
/// steps. Null when there is no room: three rows, or nothing to split.
List<FlourShare>? addFlour(List<FlourShare> rows, Flour flour) {
  final last = rows.last;
  final take =
      (min(20.0, last.sharePct / 2) / kFlourStepPct).floor() * kFlourStepPct;
  if (rows.length >= kMaxFlours || take == 0) return null;
  return balanceFlours([
    ...rows.take(rows.length - 1),
    FlourShare(last.flour, last.sharePct - take),
    FlourShare(flour, 0),
  ]);
}

/// Effective protein over white flours only (renormalised). PRD §4.3.
double effectiveProtein(List<FlourShare> flours) {
  final white = flours.where((f) => !f.flour.wholegrain);
  final share = white.fold(0.0, (s, f) => s + f.sharePct);
  if (share == 0) return flours.first.flour.proteinPct;
  return white.fold(0.0, (s, f) => s + f.sharePct * f.flour.proteinPct) / share;
}

/// Displayed hydration % for the blend. PRD §4.3.
double blendHydration(
  PizzaStyle style,
  List<FlourShare> flours, {
  double k = kHydrationSlope,
  double absorption = kWholegrainAbsorption,
}) {
  final hWhite =
      (style.hydration + k * (effectiveProtein(flours) - kRefProteinPct)).clamp(
        style.hMin,
        style.hMax,
      );
  return flours.fold(0.0, (w, f) {
    final h = f.flour.wholegrain
        ? max(hWhite + kWholegrainExtraPp, absorption)
        : hWhite;
    return w + f.sharePct * h / 100;
  });
}

/// PRD §4.3 gluten warning.
bool weakFlour(PizzaStyle s, double proteinPct, double hydrationPct) =>
    proteinPct < kWeakProteinPct &&
        s != PizzaStyle.neapolitan &&
        s != PizzaStyle.thin ||
    hydrationPct > kWetDoughHydration && proteinPct < kWetDoughProteinPct;

/// IDY % of total flour for the whole plan. PRD §4.5, mockups/Ferment.dc.html.
double idyPct(PizzaStyle style, List<Stage> plan) {
  // Each stage converted to equivalent hours at 20 °C, then yeast ∝ 1/time.
  final eqHours = plan.fold(
    0.0,
    (s, st) => s + st.hours * pow(2, (st.tempC - 20) / kYeastDoublingC),
  );
  final idy = (style.idyRef * 24 / max(eqHours, kMinEqHours)).clamp(
    kIdyMinPct,
    kIdyMaxPct,
  );
  return fridgeOnly(plan) ? idy * kFridgeOnlyBoost : idy;
}

/// Every stage with hours is in the fridge. An empty or all-zero plan is not.
bool fridgeOnly(List<Stage> plan) {
  final live = plan.where((s) => s.hours > 0);
  return live.isNotEmpty && live.every((s) => s.fridge);
}

/// The preferment calc() uses. Sourdough always means a starter (it
/// excludes commercial-yeast preferments, PRD §4.1); a starter without
/// sourdough is no preferment.
Preferment effectivePreferment(RecipeInputs i) {
  final starter = i.preferment.kind == PrefermentKind.sourdough;
  if (i.yeast == Yeast.sourdough) {
    return starter ? i.preferment : Preferment.sourdough;
  }
  return starter ? Preferment.none : i.preferment;
}

/// Highest share for [p] before it holds more water than the whole dough at
/// [hydrationPct].
double maxPrefermentShare(Preferment p, double hydrationPct) {
  final h = p.hydration / 100;
  if (h == 0) return 100;
  final share = hydrationPct / h;
  return p.kind == PrefermentKind.sourdough ? share * (1 + h) : share;
}

/// Sourdough brings its starter and, on the style plan, the PRD §4.5
/// sourdough plan; leaving drops both. Commercial types keep a poolish or
/// biga. A plan the user set stays either way.
RecipeInputs withYeast(RecipeInputs i, Yeast y) {
  if (y == i.yeast) return i;
  if (y == Yeast.sourdough) {
    return i.copyWith(
      yeast: y,
      preferment: Preferment.sourdough,
      plan: i.plan ?? kSourdoughPlan,
    );
  }
  if (i.yeast != Yeast.sourdough) return i.copyWith(yeast: y);
  return i
      .clear(const {}, plan: identical(i.plan, kSourdoughPlan))
      .copyWith(yeast: y, preferment: Preferment.none);
}

RecipeOutputs calc(RecipeInputs i) {
  final s = i.style;
  final warnings = <String>[];
  final notes = <String>[];

  final hyd = Pct.hydration.value(i);
  final salt = Pct.salt.value(i);
  final oil = Pct.oil.value(i);
  final sugar = Pct.sugar.value(i);
  final residue = Pct.residue.value(i);
  final protein = effectiveProtein(i.flours);

  final sour = i.yeast == Yeast.sourdough;
  final pref = effectivePreferment(i);
  final hasPref = pref.kind != PrefermentKind.none;

  var yeastPct = sour
      ? 0.0
      : idyPct(s, i.activePlan) * i.yeast.factor * i.yeastKnob;
  if (hasPref && !sour) yeastPct *= kPrefermentFinalYeast;

  // Total dough per 100 g flour.
  final pctSum = 100 + hyd + salt + oil + sugar + yeastPct;
  final areaCm2 = s.shape == Shape.round
      ? pi * pow(i.diameterCm / 2, 2)
      : i.panWCm * i.panLCm;
  var ballWeight = areaCm2 * s.gPerCm2 * i.thickness;

  double totalFlour;
  int balls;
  if (i.mode == EntryMode.flour) {
    totalFlour = i.flourG;
    final dough = totalFlour * pctSum / 100 / (1 + residue / 100);
    balls = max(1, (dough / ballWeight).round());
    ballWeight = dough / balls;
  } else {
    balls = i.pizzas;
    totalFlour = ballWeight * balls * (1 + residue / 100) / (pctSum / 100);
  }

  final totalWater = totalFlour * hyd / 100;
  var share = hasPref ? pref.flourShare : 0.0;
  final cap = maxPrefermentShare(pref, hyd);
  if (share > cap) {
    share = cap;
    final name = pref.kind.name;
    warnings.add(
      '${name[0].toUpperCase()}${name.substring(1)} holds more water than '
      'the dough: lower its share. Capped at ${r01(cap)}% for now.',
    );
  }
  final h = pref.hydration / 100;
  final prefFlour = pref.kind == PrefermentKind.sourdough
      ? totalFlour * share / 100 / (1 + h)
      : totalFlour * share / 100;
  final prefWater = prefFlour * h;

  // FR6 steps: flour/water/starter 1 g, salt/oil/sugar 0.1 g, yeast 0.01 g.
  final pct = 100 / totalFlour;
  Line g1(LineKind k, String name, double g) => Line(k, name, r1(g), g * pct);
  Line g01(LineKind k, String name, double g) =>
      Line(k, name, r01(g), g * pct, 1);
  Line g001(LineKind k, String name, double g) =>
      Line(k, name, r001(g), g * pct, 2);
  final yeastName = i.yeast.name.toUpperCase();

  /// One line per flour type for a blend (PRD §4.6), one "Flour" otherwise.
  List<Line> flourLines(double grams, {required String single}) => [
    if (i.flours.length == 1)
      g1(LineKind.flour, single, grams)
    else
      for (final f in i.flours)
        g1(LineKind.flour, f.flour.name, grams * f.sharePct / 100),
  ];

  final prefLines = <Line>[];
  if (hasPref) {
    prefLines.addAll(flourLines(prefFlour, single: 'Flour'));
    prefLines.add(g1(LineKind.water, 'Water', prefWater));
    if (pref.idyPctOfPrefFlour > 0) {
      prefLines.add(
        g001(
          LineKind.yeast,
          yeastName,
          prefFlour * pref.idyPctOfPrefFlour / 100 * i.yeast.factor,
        ),
      );
    }
  }

  final finalLines = <Line>[
    ...flourLines(totalFlour - prefFlour, single: i.flours.first.flour.name),
    g1(LineKind.water, 'Water', totalWater - prefWater),
    g01(LineKind.salt, 'Salt', totalFlour * salt / 100),
    if (sour)
      g1(LineKind.starter, 'Starter', prefFlour + prefWater)
    else
      g001(LineKind.yeast, yeastName, totalFlour * yeastPct / 100),
    if (oil > 0) g01(LineKind.oil, 'Oil', totalFlour * oil / 100),
    if (sugar > 0)
      g01(LineKind.sugar, sweetenerName(s), totalFlour * sugar / 100),
  ];

  if (i.flours.any((f) => f.flour.wholegrain)) {
    notes.add(
      'Wholegrain in the mix: autolyse or soak the bran 30 min before adding salt and yeast.',
    );
  }
  if (!sour && totalFlour * yeastPct / 100 < kPinchG) notes.add(kPinchNote);

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
    notes: notes,
  );
}
