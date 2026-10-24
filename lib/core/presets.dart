// Pure Dart. No Flutter imports. Numbers from spec/PRD.md §4.2, §4.3, §4.5.
import 'dart:math';

enum Shape { round, rect }

/// Display unit for pizza and pan sizes (FR7). Ingredients are always grams;
/// recipe inputs always hold cm.
enum LengthUnit {
  cm('cm', 1),
  inch('in', 2.54);

  const LengthUnit(this.label, this.cmPerUnit);
  final String label;
  final double cmPerUnit;

  double fromCm(double cm) => cm / cmPerUnit;
  double toCm(double value) => value * cmPerUnit;
}

enum PizzaStyle {
  neapolitan(
    'Neapolitan',
    hydration: 62,
    hMin: 58,
    hMax: 65,
    salt: 2.8,
    oil: 0,
    sugar: 0,
    idyRef: 0.10,
    // 250 g / 30 cm (PRD §4.2).
    gPerCm2: 0.354,
    shape: Shape.round,
    residue: 0,
    plan: [Stage(2, 20), Stage(24, 4)],
  ),
  newYork(
    'New York',
    hydration: 63,
    hMin: 60,
    hMax: 67,
    salt: 2.2,
    oil: 2.5,
    sugar: 1.5,
    idyRef: 0.30,
    gPerCm2: 0.37,
    shape: Shape.round,
    residue: 0,
    plan: [Stage(1, 20), Stage(48, 4)],
    diameterCm: 35,
  ),
  detroit(
    'Detroit',
    hydration: 72,
    hMin: 70,
    hMax: 75,
    salt: 2.2,
    oil: 3,
    sugar: 1,
    idyRef: 0.60,
    gPerCm2: 0.457,
    shape: Shape.rect,
    residue: 10,
    plan: [Stage(1, 20), Stage(24, 4)],
  ),
  roman(
    'Roman teglia',
    hydration: 80,
    hMin: 75,
    hMax: 85,
    salt: 2.5,
    oil: 2.5,
    sugar: 0.5,
    idyRef: 0.30,
    gPerCm2: 0.55,
    shape: Shape.rect,
    residue: 10,
    plan: [Stage(1, 20), Stage(48, 4)],
    panWCm: 30,
    panLCm: 40,
  ),
  sicilian(
    'Sicilian / focaccia',
    hydration: 70,
    hMin: 65,
    hMax: 75,
    salt: 2.2,
    oil: 4,
    sugar: 1,
    idyRef: 0.50,
    gPerCm2: 0.50,
    shape: Shape.rect,
    residue: 10,
    plan: [Stage(1, 20), Stage(24, 4)],
    panWCm: 33,
    panLCm: 46,
  ),
  thin(
    'Thin / tavern',
    hydration: 52,
    hMin: 48,
    hMax: 55,
    salt: 2.0,
    oil: 4,
    sugar: 1,
    idyRef: 0.30,
    gPerCm2: 0.26,
    shape: Shape.round,
    residue: 0,
    plan: [Stage(1, 20), Stage(48, 4)],
  );

  const PizzaStyle(
    this.label, {
    required this.hydration,
    required this.hMin,
    required this.hMax,
    required this.salt,
    required this.oil,
    required this.sugar,
    required this.idyRef,
    required this.gPerCm2,
    required this.shape,
    required this.residue,
    required this.plan,
    this.diameterCm = 30,
    this.panWCm = 25,
    this.panLCm = 35,
  });

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

  /// Size the style starts on (mockups/Main.dc.html), cm.
  final double diameterCm, panWCm, panLCm;
}

/// One fermentation stage. `fridge` is true below 10 °C.
class Stage {
  const Stage(this.hours, this.tempC);
  final double hours, tempC;
  bool get fridge => tempC < 10;

  @override
  bool operator ==(Object other) =>
      other is Stage && other.hours == hours && other.tempC == tempC;

  @override
  int get hashCode => Object.hash(hours, tempC);
}

/// How the Ferment screen, schedule and routine all read a plan: bulk is the
/// stages before the first fridge stage, fridge runs to the last fridge stage,
/// warm-up is what follows. An empty fridge stage still splits bulk from a
/// warm-up (StagePlan.stages writes one).
({List<Stage> bulk, List<Stage> fridge, List<Stage> warm}) splitPlan(
  List<Stage> plan,
) {
  final first = plan.indexWhere((s) => s.fridge);
  final a = first < 0 ? plan.length : first;
  final b = max(a, plan.lastIndexWhere((s) => s.fridge) + 1);
  return (
    bulk: plan.sublist(0, a),
    fridge: plan.sublist(a, b),
    warm: plan.sublist(b),
  );
}

/// A plan as the Ferment screen edits it: room bulk → fridge → warm-up.
class StagePlan {
  const StagePlan({
    required this.roomH,
    required this.fridgeH,
    required this.warmH,
    this.roomC = defaultRoomC,
    this.fridgeC = defaultFridgeC,
  });

  factory StagePlan.of(List<Stage> plan) {
    final p = splitPlan(plan);
    double hours(List<Stage> s) => s.fold(0.0, (h, st) => h + st.hours);
    return StagePlan(
      roomH: hours(p.bulk),
      fridgeH: hours(p.fridge),
      warmH: hours(p.warm),
      roomC: plan.where((s) => !s.fridge).firstOrNull?.tempC ?? defaultRoomC,
      fridgeC: plan.where((s) => s.fridge).firstOrNull?.tempC ?? defaultFridgeC,
    );
  }

  /// Room temperature when a plan has no room stage, °C.
  static const defaultRoomC = 20.0;

  /// Room temperatures the yeast model covers (PRD §4.5), and so what the
  /// kitchen temperature controls allow, °C.
  static const roomMinC = 16.0, roomMaxC = 30.0;

  // ponytail: calibration knob. Fridge temperature when a plan has none, °C.
  static const defaultFridgeC = 4.0;

  final double roomH, fridgeH, warmH, roomC, fridgeC;

  double get totalH => roomH + fridgeH + warmH;

  /// Empty room stages drop out (a fridge-only plan stays fridge-only); an
  /// empty fridge stage stays when it separates bulk from a warm-up.
  List<Stage> get stages => [
    if (roomH > 0) Stage(roomH, roomC),
    if (fridgeH > 0 || warmH > 0) Stage(fridgeH, fridgeC),
    if (warmH > 0) Stage(warmH, roomC),
  ];

  StagePlan copyWith({
    double? roomH,
    double? fridgeH,
    double? warmH,
    double? roomC,
    double? fridgeC,
  }) => StagePlan(
    roomH: roomH ?? this.roomH,
    fridgeH: fridgeH ?? this.fridgeH,
    warmH: warmH ?? this.warmH,
    roomC: roomC ?? this.roomC,
    fridgeC: fridgeC ?? this.fridgeC,
  );
}

// ponytail: calibration knob. Fibre per 100 g from which a label reads as
// wholegrain: white flours sit near 3 g, wholemeal 7–11 g (PRD §4.3).
const double kWholegrainFibreG = 6;

bool wholegrainFromFibre(double fibreG) => fibreG >= kWholegrainFibreG;

// ponytail: calibration knob. Label values a flour can have, g per 100 g
// (PRD §4.8 confidence limits): (min, max).
const kProteinRangeG = (5.0, 20.0), kFibreRangeG = (0.0, 15.0);

bool inLabelRange(double? g, (double, double) range) =>
    g != null && g >= range.$1 && g <= range.$2;

/// A preset or the user's own flour (PRD §4.3). Equal by what the formula
/// and the label read (name, protein, wholegrain, fibre), never by [note],
/// so a recipe's snapshot still matches its flour.
class Flour {
  const Flour(
    this.name,
    this.proteinPct, {
    this.wholegrain = false,
    this.fibrePct,
    this.note = '',
  });

  factory Flour.fromJson(Map<String, Object?> json) => Flour(
    json['name'] as String,
    (json['proteinPct'] as num).toDouble(),
    wholegrain: json['wholegrain'] as bool? ?? false,
    fibrePct: (json['fibrePct'] as num?)?.toDouble(),
    note: json['note'] as String? ?? '',
  );

  final String name;
  final double proteinPct;
  final bool wholegrain;

  /// Fibre off the label, g per 100 g; null when not known.
  final double? fibrePct;

  /// The grey sub-line on Settings › Flours: brands, use, "scanned".
  final String note;

  Map<String, Object?> toJson() => {
    'name': name,
    'proteinPct': proteinPct,
    'wholegrain': wholegrain,
    'fibrePct': fibrePct,
    'note': note,
  };

  @override
  bool operator ==(Object other) =>
      other is Flour &&
      other.name == name &&
      other.proteinPct == proteinPct &&
      other.wholegrain == wholegrain &&
      other.fibrePct == fibrePct;

  @override
  int get hashCode => Object.hash(name, proteinPct, wholegrain, fibrePct);

  static const presets = [
    Flour('Italian 00 pizza', 12.5, note: 'Caputo Pizzeria class'),
    Flour('Italian 00 weak', 10.5, note: 'supermarket, pasta grade'),
    Flour('Italian 0 / Manitoba', 14),
    Flour('UK plain', 10),
    Flour('UK strong white', 13, note: 'Sainsbury’s 13.7, Doves 12–14'),
    Flour('UK very strong / Canadian', 14.5, note: 'Waitrose Canadian 15'),
    Flour('US all-purpose', 11.5),
    Flour('US bread flour', 12.7, note: 'King Arthur 12.7'),
    Flour('Wholemeal', 13, wholegrain: true, note: 'absorbs ~75%'),
    Flour('Semolina rimacinata', 12.5, note: '10–20% blend'),
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

/// Flour share, hydration, hours and temperature ranges per PRD §4.5.
enum PrefermentKind {
  none(0, 0, 0, 0),
  poolish(20, 50, 100, 100, hours: (8, 16), temps: (18, 22)),
  biga(30, 100, 45, 55, hours: (16, 24), temps: (16, 18)),
  sourdough(10, 25, 50, 125);

  const PrefermentKind(
    this.shareMin,
    this.shareMax,
    this.hydrationMin,
    this.hydrationMax, {
    this.hours = (0, 0),
    this.temps = (0, 0),
  });

  /// %.
  final double shareMin, shareMax, hydrationMin, hydrationMax;

  /// (min, max) hours and °C; (0, 0) when not editable. PRD gives poolish
  /// only "12–16 h @ 20 °C" and "0.25 % for 8 h"; its temperature range is a
  /// starting point.
  final (double, double) hours, temps;
}

// ponytail: calibration knob. Poolish IDY, % of its flour: PRD §4.5 gives
// 0.25 % for 8 h and 0.1 % for 12–16 h; a straight line in between.
const double kPoolishIdyShortPct = 0.25, kPoolishShortH = 8;
const double kPoolishIdyPct = 0.1, kPoolishLongH = 12;
// ponytail: calibration knob. Biga IDY, % of its flour.
const double kBigaIdyPct = 0.7;
// ponytail: calibration knob. Starter feed ahead of the mix, hours at room
// temperature (1:1:1 peaks in about 4–8 h).
const double kStarterFeedH = 6;

/// PRD §4.5 sourdough plan: 4–6 h room bulk + 12–24 h fridge.
const kSourdoughPlan = [Stage(5, 20), Stage(18, 4)];

class Preferment {
  const Preferment(
    this.kind, {
    required this.flourShare,
    required this.hydration,
    required this.hours,
    required this.tempC,
  });
  final PrefermentKind kind;

  /// % of total flour that goes into the preferment; for a starter, the
  /// starter's own mass as % of total flour (PRD §4.5 "starter 15 %").
  final double flourShare;
  final double hydration, hours;

  /// °C; 0 for a starter, which sits at room temperature.
  final double tempC;

  /// IDY as % of preferment flour (0 for sourdough). Poolish follows its
  /// hours.
  double get idyPctOfPrefFlour => switch (kind) {
    PrefermentKind.poolish =>
      kPoolishIdyShortPct +
          (kPoolishIdyPct - kPoolishIdyShortPct) *
              ((hours - kPoolishShortH) / (kPoolishLongH - kPoolishShortH))
                  .clamp(0.0, 1.0),
    PrefermentKind.biga => kBigaIdyPct,
    _ => 0,
  };

  Preferment copyWith({
    double? flourShare,
    double? hydration,
    double? hours,
    double? tempC,
  }) => Preferment(
    kind,
    flourShare: flourShare ?? this.flourShare,
    hydration: hydration ?? this.hydration,
    hours: hours ?? this.hours,
    tempC: tempC ?? this.tempC,
  );

  static const none = Preferment(
    PrefermentKind.none,
    flourShare: 0,
    hydration: 0,
    hours: 0,
    tempC: 0,
  );
  static const poolish = Preferment(
    PrefermentKind.poolish,
    flourShare: 30,
    hydration: 100,
    hours: 14,
    tempC: 20,
  );
  static const biga = Preferment(
    PrefermentKind.biga,
    flourShare: 50,
    hydration: 50,
    hours: 18,
    tempC: 17,
  );
  static const sourdough = Preferment(
    PrefermentKind.sourdough,
    flourShare: 15,
    hydration: 100,
    hours: kStarterFeedH,
    tempC: 0,
  );
}
