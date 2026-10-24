// Pure Dart. No Flutter imports. Numbers from spec/PRD.md §4.2, §4.3, §4.5.

enum Shape { round, rect }

enum PizzaStyle {
  neapolitan('Neapolitan', hydration: 62, hMin: 58, hMax: 65, salt: 2.8,
      oil: 0, sugar: 0, idyRef: 0.10,
      // PRD says 0.34 g/cm² and 250 g / 30 cm; 250 g wins (that is what gets baked).
      gPerCm2: 0.354, shape: Shape.round, residue: 0,
      plan: [Stage(2, 20), Stage(24, 4)]),
  newYork('New York', hydration: 63, hMin: 60, hMax: 67, salt: 2.2,
      oil: 2.5, sugar: 1.5, idyRef: 0.30,
      gPerCm2: 0.37, shape: Shape.round, residue: 0,
      plan: [Stage(1, 20), Stage(48, 4)]),
  detroit('Detroit', hydration: 72, hMin: 70, hMax: 75, salt: 2.2,
      oil: 3, sugar: 1, idyRef: 0.60,
      gPerCm2: 0.457, shape: Shape.rect, residue: 10,
      plan: [Stage(1, 20), Stage(24, 4)]),
  roman('Roman teglia', hydration: 80, hMin: 75, hMax: 85, salt: 2.5,
      oil: 2.5, sugar: 0.5, idyRef: 0.30,
      gPerCm2: 0.55, shape: Shape.rect, residue: 10,
      plan: [Stage(1, 20), Stage(48, 4)]),
  sicilian('Sicilian / focaccia', hydration: 70, hMin: 65, hMax: 75, salt: 2.2,
      oil: 4, sugar: 1, idyRef: 0.50,
      gPerCm2: 0.50, shape: Shape.rect, residue: 10,
      plan: [Stage(1, 20), Stage(24, 4)]),
  thin('Thin / tavern', hydration: 52, hMin: 48, hMax: 55, salt: 2.0,
      oil: 4, sugar: 1, idyRef: 0.30,
      gPerCm2: 0.26, shape: Shape.round, residue: 0,
      plan: [Stage(1, 20), Stage(48, 4)]);

  const PizzaStyle(this.label,
      {required this.hydration,
      required this.hMin,
      required this.hMax,
      required this.salt,
      required this.oil,
      required this.sugar,
      required this.idyRef,
      required this.gPerCm2,
      required this.shape,
      required this.residue,
      required this.plan});

  final String label;
  final double hydration, hMin, hMax, salt, oil, sugar;
  /// IDY % for 24 h @ 20 °C.
  final double idyRef;
  /// Dough weight per cm² of pizza at standard thickness.
  final double gPerCm2;
  final Shape shape;
  /// Bowl residue % (sticky doughs).
  final double residue;
  final List<Stage> plan;
}

/// One fermentation stage. `fridge` is true below 10 °C.
class Stage {
  const Stage(this.hours, this.tempC);
  final double hours, tempC;
  bool get fridge => tempC < 10;
}

class Flour {
  const Flour(this.name, this.proteinPct, {this.wholegrain = false});
  final String name;
  final double proteinPct;
  final bool wholegrain;

  static const presets = [
    Flour('Italian 00 pizza', 12.5),
    Flour('Italian 00 weak', 10.5),
    Flour('Italian 0 / Manitoba', 14),
    Flour('UK plain', 10),
    Flour('UK strong white', 13),
    Flour('UK very strong / Canadian', 14.5),
    Flour('US all-purpose', 11.5),
    Flour('US bread flour', 12.7),
    Flour('Wholemeal', 13, wholegrain: true),
    Flour('Semolina rimacinata', 12.5),
  ];
  static const ukStrong = Flour('UK strong white', 13);
}

enum Yeast {
  idy(1.0),
  ady(1.25),
  fresh(3.0),
  sourdough(0);

  const Yeast(this.factor);
  /// Multiplier on IDY %.
  final double factor;
}

enum PrefermentKind { none, poolish, biga, sourdough }

class Preferment {
  const Preferment(this.kind,
      {required this.flourShare,
      required this.hydration,
      required this.hours,
      required this.tempC,
      this.idyPctOfPrefFlour = 0});
  final PrefermentKind kind;
  /// % of total flour that goes into the preferment.
  final double flourShare;
  final double hydration, hours, tempC;
  /// IDY as % of preferment flour (0 for sourdough).
  final double idyPctOfPrefFlour;

  static const none = Preferment(PrefermentKind.none,
      flourShare: 0, hydration: 0, hours: 0, tempC: 0);
  static const poolish = Preferment(PrefermentKind.poolish,
      flourShare: 30, hydration: 100, hours: 14, tempC: 20,
      idyPctOfPrefFlour: 0.1);
  static const biga = Preferment(PrefermentKind.biga,
      flourShare: 50, hydration: 50, hours: 18, tempC: 17,
      idyPctOfPrefFlour: 0.7);
  static const sourdough = Preferment(PrefermentKind.sourdough,
      flourShare: 15, hydration: 100, hours: 0, tempC: 0);
}
