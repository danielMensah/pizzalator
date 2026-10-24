// Pure Dart. No Flutter imports. Oven model: spec/PRD.md §4.4.
// Suggest-only: nothing here changes a formula; tips return edited copies.
import 'calc.dart';

// ponytail: calibration knob. Home Neapolitan browning enrichment, %.
const double kHomeOilPct = 1.5;
// ponytail: calibration knob.
const double kHomeSugarPct = 1.0;
// ponytail: calibration knob. Diastatic malt alternative to sugar, % (text only).
const double kHomeMaltPct = 0.5;
// ponytail: calibration knob. Home Neapolitan hydration cap, steel and tray.
const double kHydrationCap = 65;
// ponytail: calibration knob. Stone browns the base slower than steel.
const double kHydrationCapStone = 63;
// ponytail: calibration knob. Below this a home oven cannot do Neapolitan.
const int kNeapolitanMinC = 260;

enum OvenKind { home, outdoor }

/// Baking surface; only meaningful for a home oven.
enum Surface {
  steel('Steel'),
  stone('Stone'),
  none('Tray');

  const Surface(this.label);
  final String label;
}

class OvenSetup {
  const OvenSetup({
    required this.kind,
    this.surface = Surface.none,
    required this.maxTempC,
  });

  final OvenKind kind;
  final Surface surface;
  final int maxTempC;

  /// PRD §2 first-launch default.
  static const homeSteel = OvenSetup(
    kind: OvenKind.home,
    surface: Surface.steel,
    maxTempC: 275,
  );
  static const homeStone = OvenSetup(
    kind: OvenKind.home,
    surface: Surface.stone,
    maxTempC: 275,
  );
  static const homeTray = OvenSetup(kind: OvenKind.home, maxTempC: 275);
  static const outdoor = OvenSetup(kind: OvenKind.outdoor, maxTempC: 450);

  /// Picker order in mockups/Main.dc.html.
  static const presets = [homeSteel, homeStone, homeTray, outdoor];

  bool get isHome => kind == OvenKind.home;

  /// What the max-temperature stepper allows for this kind, °C.
  (int, int) get maxTempRange => isHome ? (200, 300) : (300, 500);

  /// Short picker name: Steel, Stone, Tray, Outdoor.
  String get name => isHome ? surface.label : 'Outdoor';

  /// Card title, e.g. "Home oven · steel".
  String get label =>
      isHome ? 'Home oven · ${surface.label.toLowerCase()}' : 'Outdoor oven';

  OvenSetup copyWith({OvenKind? kind, Surface? surface, int? maxTempC}) =>
      OvenSetup(
        kind: kind ?? this.kind,
        surface: surface ?? this.surface,
        maxTempC: maxTempC ?? this.maxTempC,
      );

  @override
  String toString() => '$label ${maxTempC}C';
}

/// One-tap suggested edit. [apply] returns an edited copy; the UI decides.
class OvenTip {
  const OvenTip(
    this.text,
    this.applyLabel,
    this.apply, {
    this.title = 'Oven suggestion',
  });
  final String text;
  final String applyLabel;
  final RecipeInputs Function(RecipeInputs) apply;

  /// Card label.
  final String title;
}

// ponytail: calibration knob. What the weak-flour tip takes off hydration, pp.
const double kWeakFlourHydrationDropPp = 2;

/// Home Neapolitan hydration cap for this oven's surface.
double hydrationCap(OvenSetup oven) =>
    oven.surface == Surface.stone ? kHydrationCapStone : kHydrationCap;

bool _pan(PizzaStyle s) => s.shape == Shape.rect;

/// Flour advice with a one-tap edit (mockups/Main.dc.html): weak flour for
/// the style lowers hydration until the user sets it themselves.
List<OvenTip> doughTips(RecipeInputs inputs, RecipeOutputs outputs) => [
  if (inputs.hydrationOverride == null &&
      weakFlour(inputs.style, outputs.proteinPct, outputs.hydrationPct))
    OvenTip(
      'Weak flour for this style: expect tearing and a flat crust. Blend in '
          'strong flour or lower hydration.',
      'Lower hydration ${pctText(kWeakFlourHydrationDropPp)} pp',
      (i) => i.set(
        Pct.hydration,
        outputs.hydrationPct - kWeakFlourHydrationDropPp,
        tip: true,
      ),
      title: 'Flour suggestion',
    ),
];

List<OvenTip> ovenTips(
  RecipeInputs inputs,
  RecipeOutputs outputs,
  OvenSetup oven,
) {
  final s = inputs.style;
  final oil = inputs.oilPct ?? s.oil;
  final sugar = inputs.sugarPct ?? s.sugar;
  final tips = <OvenTip>[];

  if (oven.isHome && s == PizzaStyle.neapolitan) {
    final cap = hydrationCap(oven);
    if (oil >= kHomeOilPct && sugar >= kHomeSugarPct) {
      tips.add(
        OvenTip(
          'Oil and sugar applied for browning. Revert any time; '
              'the style default stays untouched.',
          'Revert to style',
          // Only what the enrichment tip set; other edits stay.
          (i) => i.clear({Pct.oil, Pct.sugar}),
        ),
      );
    } else {
      tips.add(
        OvenTip(
          'Home ovens cannot brown a lean Neapolitan dough in time. '
              'Add ${pctText(kHomeOilPct)}% oil and ${pctText(kHomeSugarPct)}% '
              'sugar (or ${pctText(kHomeMaltPct)}% diastatic malt) and keep '
              'hydration at or below ${pctText(cap)}%.',
          'Apply +${pctText(kHomeOilPct)}% oil, '
              '+${pctText(kHomeSugarPct)}% sugar',
          // A value the user already raised stays theirs.
          (i) {
            var r = i;
            if (oil < kHomeOilPct) r = r.set(Pct.oil, kHomeOilPct, tip: true);
            if (sugar < kHomeSugarPct) {
              r = r.set(Pct.sugar, kHomeSugarPct, tip: true);
            }
            return r;
          },
        ),
      );
    }
    if (outputs.hydrationPct > cap) {
      tips.add(
        OvenTip(
          'A wet dough steams before the base browns in a home oven. '
              'Keep hydration at or below ${pctText(cap)}%.',
          'Cap hydration at ${pctText(cap)}%',
          (i) => i.set(Pct.hydration, cap, tip: true),
        ),
      );
    }
  }

  if (!oven.isHome && !_pan(s) && sugar > 0) {
    tips.add(
      OvenTip(
        'Sugar burns above 400 °C. For an outdoor oven set sugar to 0 '
            'and shorten the bake.',
        'Set sugar to 0',
        (i) => i.set(Pct.sugar, 0, tip: true),
      ),
    );
  }
  return tips;
}

List<String> ovenWarnings(RecipeInputs inputs, OvenSetup oven) {
  final s = inputs.style;
  final sugar = inputs.sugarPct ?? s.sugar;
  final neo = s == PizzaStyle.neapolitan;
  final w = <String>[];

  if (neo && !oven.isHome && sugar > 0) {
    w.add('Sugar or malt burns in a 400 °C oven. Keep Neapolitan dough lean.');
  }
  if (neo && oven.isHome && oven.surface == Surface.none) {
    w.add(
      'A tray cannot heat a Neapolitan base fast enough. '
      'Use New York instead, or bake on a steel or stone.',
    );
  } else if (neo && oven.maxTempC < kNeapolitanMinC) {
    w.add(
      'Oven tops out under $kNeapolitanMinC °C, too cool for Neapolitan. '
      'Use New York instead.',
    );
  }
  if (_pan(s) && !oven.isHome) {
    w.add(
      'Pan pizza in an outdoor oven: let it drop to 300–320 °C and bake '
      'with the door open, or bake it in a home oven.',
    );
  }
  return w;
}

class BakeCard {
  const BakeCard(this.title, this.subtitle, this.steps);
  final String title;
  final String subtitle;
  final List<String> steps;
}

// ponytail: calibration knob. Home bake minutes for round styles, by surface.
// PRD gives NY on all three and thin on steel; the rest are starting points.
const Map<Surface, Map<PizzaStyle, String>> kRoundBakeMin = {
  Surface.steel: {
    PizzaStyle.neapolitan: '4–6',
    PizzaStyle.newYork: '5–7',
    PizzaStyle.thin: '6–8',
  },
  Surface.stone: {
    PizzaStyle.neapolitan: '6–8',
    PizzaStyle.newYork: '7–9',
    PizzaStyle.thin: '8–10',
  },
  Surface.none: {
    PizzaStyle.neapolitan: '8–11',
    PizzaStyle.newYork: '9–12',
    PizzaStyle.thin: '10–12',
  },
};

// ponytail: calibration knob. Home bake minutes for pan styles, any surface.
const Map<PizzaStyle, String> kPanBakeMin = {
  PizzaStyle.detroit: '12–16',
  PizzaStyle.roman: '15–20',
  PizzaStyle.sicilian: '12–16',
};

BakeCard bakeCard(PizzaStyle style, OvenSetup oven) {
  final pan = _pan(style);
  const stretch = 'Stretch on semolina and top lightly.';
  const press = 'Press the dough into the oiled pan and top to the edges.';
  const rest = 'Rest 60 s on a rack before cutting.';
  const panRest = 'Rest 2 min, then slide out of the pan onto a rack.';

  String where;
  List<String> steps;
  if (!oven.isHome) {
    where = pan ? 'pan at 300–320 °C' : 'stone floor';
    steps = pan
        ? [
            'Let the floor settle at 300–320 °C, flame low.',
            press,
            'Bake with the door open, turning the pan every 2 min, '
                'until the base is golden.',
            panRest,
          ]
        : [
            'Heat the floor 20–30 min until it reads 400 °C or more.',
            stretch,
            'Launch. Bake 60–90 s, turning every 20–30 s.',
            rest,
          ];
  } else if (pan) {
    where = 'lower-middle rack';
    steps = [
      oven.surface == Surface.none
          ? 'Preheat 30 min at max.'
          : 'Preheat 45–60 min at max, '
                '${oven.surface.label.toLowerCase()} on the lower-middle rack.',
      press,
      'Bake ${kPanBakeMin[style]} min until the base is golden.',
      panRest,
    ];
  } else {
    final cue = style == PizzaStyle.thin
        ? 'the base is crisp'
        : 'the rim blisters';
    final launch =
        'Launch. Bake ${kRoundBakeMin[oven.surface]![style]} min until $cue.';
    switch (oven.surface) {
      case Surface.steel:
        where = '2nd rack from top';
        steps = [
          'Preheat steel 45–60 min at max, fan off.',
          stretch,
          launch,
          'Switch to grill for the last 1–2 min. '
              'Watch the rim, not the clock.',
          rest,
        ];
      case Surface.stone:
        where = 'middle rack';
        steps = [
          'Preheat stone 60 min at max on the middle rack.',
          stretch,
          launch,
          'Move to the top rack under the grill for the last 1–2 min.',
          rest,
        ];
      case Surface.none:
        where = 'middle rack';
        steps = [
          'Preheat an upside-down tray 30 min at max.',
          stretch,
          launch,
          rest,
        ];
    }
  }
  return BakeCard(oven.label, 'Max ${oven.maxTempC} °C · $where', steps);
}
