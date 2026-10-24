import 'package:flutter_test/flutter_test.dart';
import 'package:pizzalator/core/calc.dart';

const pizzeria = Flour('Italian 00 pizza', 12.5);
const ukPlain = Flour('UK plain', 10);
const wholemeal = Flour('Wholemeal', 13, wholegrain: true);

double g(RecipeOutputs o, String name) =>
    o.finalDough.firstWhere((l) => l.name == name).grams;

Map<String, double> grams(List<Line> lines) => {
  for (final l in lines) l.name: l.grams,
};

void main() {
  moreCases();
  goldens();
  yeastModel();
  preferments();
  overrides();

  test('Neapolitan golden: 1000 g @ 12.5% / 62% -> 620 g water, 28 g salt', () {
    final o = calc(
      const RecipeInputs(
        style: PizzaStyle.neapolitan,
        flours: [FlourShare(pizzeria, 100)],
      ),
    );
    expect(o.hydrationPct, 62);
    expect(g(o, 'Water'), 620);
    expect(g(o, 'Salt'), 28);
    expect(g(o, 'Italian 00 pizza'), 1000);
    expect(o.finalDough.any((l) => l.name == 'Oil'), isFalse);
    expect(o.ballCount, 7); // 1000 g flour ≈ 1650 g dough / 250 g
  });

  test('UK strong 13% raises Neapolitan hydration by k × 0.5', () {
    final o = calc(const RecipeInputs(style: PizzaStyle.neapolitan));
    expect(o.hydrationPct, 62.5);
  });

  test('wholemeal blend 80/20 absorbs at 75% floor', () {
    final o = calc(
      const RecipeInputs(
        style: PizzaStyle.neapolitan,
        flours: [FlourShare(Flour.ukStrong, 80), FlourShare(wholemeal, 20)],
      ),
    );
    expect(o.proteinPct, 13); // white flours only
    expect(o.hydrationPct, 65); // 0.8×62.5 + 0.2×75
    expect(g(o, 'Water'), 650);
    expect(g(o, 'UK strong white'), 800);
    expect(g(o, 'Wholemeal'), 200);
    expect(o.notes.any((w) => w.contains('Wholegrain')), isTrue);
    expect(o.warnings, isEmpty, reason: 'advice, not a problem');
  });

  test('hydration clamps to style range', () {
    final o = calc(
      const RecipeInputs(
        style: PizzaStyle.neapolitan,
        flours: [FlourShare(Flour('Very strong', 16), 100)],
      ),
    );
    expect(o.hydrationPct, 65);
  });

  test('pizzas mode: 4 × 30 cm Neapolitan ≈ 250 g each', () {
    final o = calc(
      const RecipeInputs(style: PizzaStyle.neapolitan, mode: EntryMode.pizzas),
    );
    expect(o.ballWeightG, 250);
    expect(o.ballCount, 4);
    expect(o.totalDoughG, closeTo(1000, 2));
    // flour + water + salt + yeast == dough
    final sum = o.finalDough.fold(0.0, (s, l) => s + l.grams);
    expect(sum, closeTo(1000, 2));
  });

  test('Detroit pan weight 10×14 in ≈ 413 g, 10% residue', () {
    final o = calc(
      const RecipeInputs(
        style: PizzaStyle.detroit,
        mode: EntryMode.pizzas,
        pizzas: 1,
        panWCm: 25.4,
        panLCm: 35.56,
      ),
    );
    expect(o.ballWeightG, 413);
    expect(o.totalDoughG, closeTo(413 * 1.1, 1));
  });

  test('rounding: flour/water 1 g, salt 0.1 g, yeast 0.01 g', () {
    expect(r1(619.6), 620);
    expect(r01(27.96), 28.0);
    expect(r001(1.2349), 1.23);
  });
}

/// PRD §7: one golden per style. 1000 g UK strong white, default plan, IDY.
void goldens() {
  group('style goldens', () {
    final cases = {
      PizzaStyle.neapolitan: (
        hydration: 62.5,
        idy: 0.30,
        lines: {
          'UK strong white': 1000.0,
          'Water': 625.0,
          'Salt': 28.0,
          'IDY': 3.0,
        },
        dough: 1656.0,
        balls: 7,
        ball: 237.0,
      ),
      PizzaStyle.newYork: (
        hydration: 63.5,
        idy: 0.55,
        lines: {
          'UK strong white': 1000.0,
          'Water': 635.0,
          'Salt': 22.0,
          'IDY': 5.54,
          'Oil': 25.0,
          'Sugar': 15.0,
        },
        dough: 1703.0,
        balls: 5,
        ball: 341.0,
      ),
      PizzaStyle.detroit: (
        hydration: 72.5,
        // 0.60 × 24 / 7 eq h = 2.06 %, over the clamp: idyRef is a spec
        // question (PRD §11), the clamp keeps it bakeable meanwhile.
        idy: 1.2,
        lines: {
          'UK strong white': 1000.0,
          'Water': 725.0,
          'Salt': 22.0,
          'IDY': 12.0,
          'Oil': 30.0,
          'Sugar': 10.0,
        },
        dough: 1799.0,
        balls: 4,
        ball: 409.0,
      ),
      PizzaStyle.roman: (
        hydration: 80.5,
        idy: 0.55,
        lines: {
          'UK strong white': 1000.0,
          'Water': 805.0,
          'Salt': 25.0,
          'IDY': 5.54,
          'Oil': 25.0,
          'Malt': 5.0,
        },
        dough: 1866.0,
        balls: 3,
        ball: 565.0,
      ),
      PizzaStyle.sicilian: (
        hydration: 70.5,
        idy: 1.2, // 0.50 × 24 / 7 = 1.71 %, clamped; see Detroit
        lines: {
          'UK strong white': 1000.0,
          'Water': 705.0,
          'Salt': 22.0,
          'IDY': 12.0,
          'Oil': 40.0,
          'Sugar': 10.0,
        },
        dough: 1789.0,
        balls: 2,
        ball: 813.0,
      ),
      PizzaStyle.thin: (
        hydration: 52.5,
        idy: 0.55,
        lines: {
          'UK strong white': 1000.0,
          'Water': 525.0,
          'Salt': 20.0,
          'IDY': 5.54,
          'Oil': 40.0,
          'Sugar': 10.0,
        },
        dough: 1601.0,
        balls: 9,
        ball: 178.0,
      ),
    };
    for (final MapEntry(key: s, value: want) in cases.entries) {
      test(s.label, () {
        // On the style's own size, as setStyle leaves it.
        final o = calc(
          RecipeInputs(
            style: s,
            diameterCm: s.diameterCm,
            panWCm: s.panWCm,
            panLCm: s.panLCm,
          ),
        );
        expect(o.hydrationPct, want.hydration);
        expect(o.yeastPct, want.idy);
        expect(grams(o.finalDough), want.lines);
        expect(o.preferment, isEmpty);
        expect(o.totalDoughG, want.dough);
        expect(o.ballCount, want.balls);
        expect(o.ballWeightG, want.ball);
      });
    }

    test('PRD §4.2 weight-rule examples, pizzas mode', () {
      double one(PizzaStyle s, {double? d, double? w, double? l}) => calc(
        RecipeInputs(
          style: s,
          mode: EntryMode.pizzas,
          pizzas: 1,
          diameterCm: d ?? s.diameterCm,
          panWCm: w ?? s.panWCm,
          panLCm: l ?? s.panLCm,
        ),
      ).ballWeightG;
      expect(one(PizzaStyle.neapolitan, d: 30), 250);
      expect(one(PizzaStyle.newYork, d: 35.56), closeTo(370, 5)); // 14"
      expect(one(PizzaStyle.detroit, w: 25.4, l: 35.56), 413); // 10×14"
      expect(one(PizzaStyle.roman, w: 30, l: 40), 660);
      expect(one(PizzaStyle.sicilian, w: 33, l: 46), closeTo(760, 1));
      expect(one(PizzaStyle.thin, d: 30.48), closeTo(190, 1)); // 12"
    });
  });
}

void yeastModel() {
  group('yeast model', () {
    test('reference plan returns idyRef; time scales it', () {
      expect(
        idyPct(PizzaStyle.newYork, const [Stage(24, 20)]),
        closeTo(0.30, 1e-9),
      );
      expect(
        idyPct(PizzaStyle.newYork, const [Stage(48, 20)]),
        closeTo(0.15, 1e-9),
      );
    });

    test('activity doubles every 8 °C', () {
      expect(kYeastDoublingC, 8);
      // 24 h at 4 °C is 6 equivalent hours at 20 °C, 24 h at 28 °C is 48.
      expect(
        idyPct(PizzaStyle.neapolitan, const [Stage(24, 28)]),
        closeTo(0.05, 1e-9),
      );
      expect(
        idyPct(PizzaStyle.neapolitan, const [Stage(2, 20), Stage(24, 4)]),
        closeTo(0.30, 1e-9),
      );
    });

    test('fridge-only plans get the +30 % boost over the same eq hours', () {
      // 48 h at 4 °C = 12 eq h; 12 h at 20 °C is the same time to the model.
      final fridge = idyPct(PizzaStyle.newYork, const [Stage(48, 4)]);
      final room = idyPct(PizzaStyle.newYork, const [Stage(12, 20)]);
      expect(fridge / room, closeTo(kFridgeOnlyBoost, 1e-9));
      expect(kFridgeOnlyBoost, 1.30);
      expect(fridge, closeTo(0.78, 1e-9));
    });

    test('short plans clamp to the IDY ceiling, long ones to the floor', () {
      expect([kMinEqHours, kIdyMinPct, kIdyMaxPct], [2, 0.03, 1.2]);
      // NY same day, 4 h at 20 °C: 0.3 × 24 / 4 = 1.8 %, clamped.
      expect(idyPct(PizzaStyle.newYork, const [Stage(4, 20)]), kIdyMaxPct);
      // 1 h counts as 2: 0.10 × 24 / 2 = 1.2.
      expect(
        idyPct(PizzaStyle.neapolitan, const [Stage(1, 20)]),
        closeTo(1.2, 1e-9),
      );
      expect(idyPct(PizzaStyle.neapolitan, const [Stage(96, 30)]), kIdyMinPct);
    });

    test('empty or all-zero plans are not fridge-only and stay sane', () {
      expect(fridgeOnly(const [Stage(48, 4), Stage(0, 20)]), isTrue);
      expect(fridgeOnly(const []), isFalse);
      expect(fridgeOnly(const [Stage(0, 4)]), isFalse);
      for (final plan in const [
        <Stage>[],
        [Stage(0, 4)],
      ]) {
        expect(idyPct(PizzaStyle.neapolitan, plan), closeTo(1.2, 1e-9));
        final o = calc(RecipeInputs(style: PizzaStyle.newYork, plan: plan));
        expect(o.yeastPct, 1.2);
        expect(g(o, 'IDY'), 12);
      }
    });

    test('ADY = IDY × 1.25, fresh = IDY × 3', () {
      final idy = calc(const RecipeInputs(style: PizzaStyle.newYork));
      final ady = calc(
        const RecipeInputs(style: PizzaStyle.newYork, yeast: Yeast.ady),
      );
      final fresh = calc(
        const RecipeInputs(style: PizzaStyle.newYork, yeast: Yeast.fresh),
      );
      final base = idyPct(PizzaStyle.newYork, PizzaStyle.newYork.plan);
      expect(ady.yeastPct, closeTo(base * 1.25, 0.005));
      expect(fresh.yeastPct, closeTo(base * 3, 0.005));
      expect(g(ady, 'ADY'), closeTo(g(idy, 'IDY') * 1.25, 0.01));
    });

    test('the kitchen knob scales the yeast', () {
      final base = calc(const RecipeInputs(style: PizzaStyle.newYork));
      final fast = calc(
        const RecipeInputs(style: PizzaStyle.newYork, yeastKnob: 1.2),
      );
      expect(fast.yeastPct, closeTo(base.yeastPct * 1.2, 0.005));
    });

    test('tiny batch: pinch note under kPinchG', () {
      expect(kPinchG, 0.1);
      final o = calc(
        const RecipeInputs(style: PizzaStyle.neapolitan, flourG: 30),
      );
      expect(g(o, 'IDY'), lessThan(kPinchG));
      expect(o.notes, contains(kPinchNote));
      expect(o.warnings, isEmpty);
      final big = calc(const RecipeInputs(style: PizzaStyle.neapolitan));
      expect(big.notes, isNot(contains(kPinchNote)));
    });
  });

  group('weak flour (PRD §4.3)', () {
    test('protein under 11 % for most styles', () {
      expect(weakFlour(PizzaStyle.newYork, 10, 60.5), isTrue);
      expect(weakFlour(PizzaStyle.newYork, 11, 61.5), isFalse);
    });

    test('Neapolitan and thin are exempt from the protein rule', () {
      expect(weakFlour(PizzaStyle.neapolitan, 10, 59.5), isFalse);
      expect(weakFlour(PizzaStyle.thin, 10, 49.5), isFalse);
    });

    test('wet dough on flour under 12 % warns for any style', () {
      // Roman on US all-purpose 11.5 %: 79 % hydration.
      final o = calc(
        const RecipeInputs(
          style: PizzaStyle.roman,
          flours: [FlourShare(Flour('US all-purpose', 11.5), 100)],
        ),
      );
      expect(o.hydrationPct, 79);
      expect(weakFlour(PizzaStyle.roman, o.proteinPct, o.hydrationPct), isTrue);
      expect(weakFlour(PizzaStyle.neapolitan, 11.5, 70.5), isTrue);
      expect(weakFlour(PizzaStyle.roman, 12, 79), isFalse);
      expect(weakFlour(PizzaStyle.roman, 11.5, 70), isFalse);
    });

    test('knobs', () {
      expect(
        [kWeakProteinPct, kWetDoughHydration, kWetDoughProteinPct],
        [11, 70, 12],
      );
    });
  });
}

void preferments() {
  group('preferments', () {
    test('poolish carves out of totals', () {
      final o = calc(
        const RecipeInputs(
          style: PizzaStyle.newYork,
          flours: [FlourShare(pizzeria, 100)],
          preferment: Preferment.poolish,
        ),
      );
      expect(grams(o.preferment), {'Flour': 300, 'Water': 300, 'IDY': 0.3});
      expect(g(o, 'Italian 00 pizza'), 700);
      expect(g(o, 'Water'), 330); // 630 − 300
    });

    test('biga carves out 50% flour at 50% hydration with its own IDY', () {
      final o = calc(
        const RecipeInputs(
          style: PizzaStyle.neapolitan,
          flours: [FlourShare(pizzeria, 100)],
          preferment: Preferment.biga,
        ),
      );
      expect(grams(o.preferment), {'Flour': 500, 'Water': 250, 'IDY': 3.5});
      expect(g(o, 'Water'), 370);
    });

    test('sourdough: 15 % starter is starter mass, half flour at 100 %', () {
      final o = calc(
        const RecipeInputs(
          style: PizzaStyle.neapolitan,
          flours: [FlourShare(pizzeria, 100)],
          yeast: Yeast.sourdough,
        ),
      );
      expect(o.yeastPct, 0);
      expect(grams(o.preferment), {'Flour': 75, 'Water': 75});
      expect(g(o, 'Starter'), 150);
      expect(g(o, 'Italian 00 pizza'), 925);
      expect(g(o, 'Water'), 545);
      final starter = o.finalDough.firstWhere((l) => l.name == 'Starter');
      expect(starter.pct, closeTo(15, 1e-9));
      expect(starter.kind, LineKind.starter);
    });

    test('a stiffer starter holds less water for the same mass', () {
      final o = calc(
        RecipeInputs(
          style: PizzaStyle.neapolitan,
          yeast: Yeast.sourdough,
          preferment: Preferment.sourdough.copyWith(hydration: 50),
        ),
      );
      expect(grams(o.preferment), {'Flour': 100, 'Water': 50});
      expect(g(o, 'Starter'), 150);
    });

    test('preferment yeast is in the chosen yeast type', () {
      final o = calc(
        const RecipeInputs(
          style: PizzaStyle.newYork,
          yeast: Yeast.fresh,
          preferment: Preferment.poolish,
        ),
      );
      expect(grams(o.preferment)['FRESH'], 0.9); // 0.1 % × 300 g × 3
      expect(o.preferment.any((l) => l.name == 'IDY'), isFalse);
      expect(o.preferment.last.kind, LineKind.yeast);
    });

    test('blends split the preferment flour by share too', () {
      final o = calc(
        const RecipeInputs(
          style: PizzaStyle.neapolitan,
          flours: [FlourShare(Flour.ukStrong, 80), FlourShare(wholemeal, 20)],
          preferment: Preferment.poolish,
        ),
      );
      expect(grams(o.preferment), {
        'UK strong white': 240,
        'Wholemeal': 60,
        'Water': 300,
        'IDY': 0.3,
      });
      expect(g(o, 'UK strong white'), 560);
      expect(g(o, 'Wholemeal'), 140);
      final flour = [
        for (final l in [...o.preferment, ...o.finalDough])
          if (l.kind == LineKind.flour) l.grams,
      ];
      expect(flour.fold(0.0, (a, b) => a + b), 1000);
    });

    test('a preferment never holds more water than the dough', () {
      // Thin on UK plain: 49.5 % hydration, under a 50 % poolish's 50 %.
      final thin = RecipeInputs(
        style: PizzaStyle.thin,
        flours: const [FlourShare(ukPlain, 100)],
        preferment: Preferment.poolish.copyWith(flourShare: 50),
      );
      final o = calc(thin);
      expect(o.hydrationPct, 49.5);
      expect(g(o, 'Water'), 0);
      expect(grams(o.preferment)['Flour'], 495);
      expect(o.warnings.single, contains('Poolish holds more water'));

      final biga = calc(
        thin.copyWith(preferment: Preferment.biga.copyWith(flourShare: 100)),
      );
      expect(g(biga, 'Water'), 0);
      expect(grams(biga.preferment)['Water'], 495);
      expect(biga.warnings.single, contains('Biga holds more water'));

      expect(
        calc(const RecipeInputs(style: PizzaStyle.thin)).warnings,
        isEmpty,
      );
    });

    test('maxPrefermentShare: the share whose water equals the dough', () {
      expect(maxPrefermentShare(Preferment.poolish, 49.5), 49.5);
      expect(maxPrefermentShare(Preferment.biga, 49.5), 99);
      expect(maxPrefermentShare(Preferment.sourdough, 62.5), 125);
      expect(maxPrefermentShare(Preferment.none, 62.5), 100);
    });

    test('effectivePreferment: sourdough means a starter, only then', () {
      const sour = RecipeInputs(
        style: PizzaStyle.neapolitan,
        yeast: Yeast.sourdough,
      );
      expect(effectivePreferment(sour), same(Preferment.sourdough));
      final own = Preferment.sourdough.copyWith(flourShare: 20);
      expect(effectivePreferment(sour.copyWith(preferment: own)), same(own));
      // PRD §4.1: sourdough excludes commercial-yeast preferments.
      expect(
        effectivePreferment(sour.copyWith(preferment: Preferment.biga)),
        same(Preferment.sourdough),
      );
      // A starter without sourdough selected is no preferment at all.
      expect(
        effectivePreferment(
          const RecipeInputs(
            style: PizzaStyle.neapolitan,
            preferment: Preferment.sourdough,
          ),
        ),
        same(Preferment.none),
      );
      expect(
        effectivePreferment(const RecipeInputs(style: PizzaStyle.neapolitan)),
        same(Preferment.none),
      );
    });

    test('sourdough + biga input: one starter, no commercial yeast', () {
      final o = calc(
        const RecipeInputs(
          style: PizzaStyle.neapolitan,
          flours: [FlourShare(pizzeria, 100)],
          yeast: Yeast.sourdough,
          preferment: Preferment.biga,
        ),
      );
      expect(grams(o.preferment), {'Flour': 75, 'Water': 75});
      expect(o.finalDough.where((l) => l.name == 'Starter'), hasLength(1));
      expect(
        [...o.preferment, ...o.finalDough].any((l) => l.kind == LineKind.yeast),
        isFalse,
      );
    });

    test('commercial yeast + a starter input: no starter carve-out', () {
      final o = calc(
        const RecipeInputs(
          style: PizzaStyle.neapolitan,
          preferment: Preferment.sourdough,
        ),
      );
      expect(o.preferment, isEmpty);
      expect(g(o, 'UK strong white'), 1000);
    });
  });

  group('withYeast (PRD §4.5)', () {
    const neo = RecipeInputs(style: PizzaStyle.neapolitan);

    test('sourdough brings its starter and its 5 h + 18 h plan', () {
      final s = withYeast(neo, Yeast.sourdough);
      expect(s.yeast, Yeast.sourdough);
      expect(s.preferment, same(Preferment.sourdough));
      expect(s.plan, same(kSourdoughPlan));
      expect(kSourdoughPlan, const [Stage(5, 20), Stage(18, 4)]);
      // Leaving drops both again.
      final back = withYeast(s, Yeast.idy);
      expect(back.preferment, same(Preferment.none));
      expect(back.plan, isNull);
      expect(back.activePlan, neo.style.plan);
    });

    test('a plan the user set survives the switch both ways', () {
      const own = [Stage(6, 22), Stage(12, 4)];
      final s = withYeast(neo.copyWith(plan: own), Yeast.sourdough);
      expect(s.plan, same(own));
      expect(withYeast(s, Yeast.fresh).plan, same(own));
    });

    test('commercial types keep a poolish; same type is a no-op', () {
      final p = neo.copyWith(preferment: Preferment.poolish);
      expect(withYeast(p, Yeast.ady).preferment, same(Preferment.poolish));
      expect(withYeast(p, Yeast.idy), same(p));
    });

    test('the starter is fed ahead, so the schedule shows it', () {
      expect(Preferment.sourdough.hours, kStarterFeedH);
      expect(kStarterFeedH, greaterThan(0));
    });
  });
}

void overrides() {
  group('overrides and knobs', () {
    const ny = RecipeInputs(style: PizzaStyle.newYork);

    test('Pct reads the override, the style base and the value', () {
      final i = ny.copyWith(saltPct: 2.5);
      expect(Pct.salt.of(i), 2.5);
      expect(Pct.salt.base(i), 2.2);
      expect(Pct.salt.value(i), 2.5);
      expect(Pct.oil.of(i), isNull);
      expect(Pct.oil.value(i), 2.5);
      expect(Pct.sugar.base(i), 1.5);
      expect(Pct.residue.base(i), 0);
      // Hydration's base is the flour model's value, not the style's 63.
      expect(Pct.hydration.base(i), 63.5);
    });

    test('set marks explicit edits; tips are remembered as tips', () {
      final user = ny.set(Pct.salt, 2.4);
      expect(user.saltPct, 2.4);
      expect(user.fromTip, isEmpty);
      final tip = user.set(Pct.oil, 3, tip: true);
      expect(tip.fromTip, {Pct.oil});
      // Editing a tip value by hand makes it the user's.
      expect(tip.set(Pct.oil, 3.5).fromTip, isEmpty);
    });

    test('clear drops only the named overrides', () {
      final i = ny
          .set(Pct.salt, 2.4)
          .set(Pct.oil, 3, tip: true)
          .set(Pct.hydration, 60, tip: true);
      final c = i.clear({Pct.oil});
      expect([c.saltPct, c.oilPct, c.hydrationOverride], [2.4, null, 60]);
      expect(c.fromTip, {Pct.hydration});
      expect(i.clear({Pct.hydration}).hydrationOverride, isNull);
    });

    test('every Pct maps to its field', () {
      var i = ny;
      for (final (n, p) in Pct.values.indexed) {
        i = i.set(p, n + 1.0);
      }
      expect(
        [i.hydrationOverride, i.saltPct, i.oilPct, i.sugarPct, i.residuePct],
        [1, 2, 3, 4, 5],
      );
      expect([for (final p in Pct.values) p.of(i)], [1, 2, 3, 4, 5]);
      expect(Pct.values.map((p) => p.label), [
        'Hydration',
        'Salt',
        'Oil',
        'Sugar',
        'Bowl residue',
      ]);
    });

    test('k and the wholegrain absorption are inputs, defaulting to knobs', () {
      expect(ny.hydrationSlope, kHydrationSlope);
      expect(ny.wholegrainAbsorption, kWholegrainAbsorption);
      // k = 2: 63 + 2 × 0.5 = 64.
      expect(calc(ny.copyWith(hydrationSlope: 2)).hydrationPct, 64);
      const blend = RecipeInputs(
        style: PizzaStyle.neapolitan,
        flours: [FlourShare(Flour.ukStrong, 80), FlourShare(wholemeal, 20)],
      );
      // 0.8 × 62.5 + 0.2 × max(72.5, 80) = 66.
      expect(calc(blend.copyWith(wholegrainAbsorption: 80)).hydrationPct, 66);
      expect(
        [kRefProteinPct, kWholegrainExtraPp, kWholegrainAbsorption],
        [12.5, 10, 75],
      );
    });

    test('thickness scales the weight; Detroit uses its g/in² presets', () {
      double ball(RecipeInputs i) =>
          calc(i.copyWith(mode: EntryMode.pizzas, pizzas: 1)).ballWeightG;
      expect(ball(ny.copyWith(thickness: 1.15)), closeTo(ball(ny) * 1.15, 1));
      expect(thicknessPresets(PizzaStyle.newYork), [0.85, 1, 1.15]);
      final detroit = thicknessPresets(PizzaStyle.detroit);
      expect(
        [for (final f in detroit) f * 2.95],
        [closeTo(2.75, 1e-9), closeTo(2.95, 1e-9), closeTo(3.15, 1e-9)],
      );
      // 10×14" pan at 3.15 g/in² = 441 g.
      final pan = const RecipeInputs(
        style: PizzaStyle.detroit,
        panWCm: 25.4,
        panLCm: 35.56,
      ).copyWith(thickness: detroit.last);
      expect(ball(pan), 441);
      // Flour mode: thicker pizzas, fewer of them.
      expect(
        calc(ny.copyWith(thickness: 1.15)).ballCount,
        lessThanOrEqualTo(calc(ny).ballCount),
      );
    });

    test('flour rows: the last one balances to 100 % (FR2)', () {
      const a = Flour.ukStrong;
      List<double> shares(List<FlourShare>? r) => [
        for (final f in r!) f.sharePct,
      ];
      expect(
        shares(balanceFlours(const [FlourShare(a, 70), FlourShare(a, 50)])),
        [70, 30],
      );
      expect(shares(balanceFlours(const [FlourShare(a, 40)])), [100]);
      final two = addFlour(const [FlourShare(a, 100)], wholemeal)!;
      expect(shares(two), [80, 20]);
      expect(two.last.flour, wholemeal);
      final three = addFlour(two, pizzeria)!;
      expect(shares(three), [80, 10, 10]);
      expect(addFlour(three, pizzeria), isNull, reason: 'three at most');
      expect(
        addFlour(const [FlourShare(a, 95), FlourShare(a, 5)], pizzeria),
        isNull,
        reason: 'the last row has no whole step to give',
      );
      expect([kMaxFlours, kFlourStepPct], [3, 5]);
    });

    test('activePlan is the plan or the style default', () {
      expect(ny.activePlan, PizzaStyle.newYork.plan);
      const own = [Stage(4, 22)];
      expect(ny.copyWith(plan: own).activePlan, same(own));
    });
  });
}

void moreCases() {
  test('copyWith changes only named fields', () {
    const a = RecipeInputs(style: PizzaStyle.neapolitan);
    final b = a.copyWith(style: PizzaStyle.thin, flourG: 500);
    expect(b.style, PizzaStyle.thin);
    expect(b.flourG, 500);
    expect(b.flours, a.flours);
    expect(b.yeast, a.yeast);
    expect(a.copyWith().style, PizzaStyle.neapolitan);
    final c = a.copyWith(
      hydrationSlope: 1.5,
      wholegrainAbsorption: 78,
      fromTip: {Pct.oil},
    );
    expect([c.hydrationSlope, c.wholegrainAbsorption], [1.5, 78]);
    expect(c.fromTip, {Pct.oil});
    expect(c.copyWith(flourG: 2).fromTip, {Pct.oil});
  });

  test('all-wholegrain blend uses its own protein and 75% floor', () {
    final o = calc(
      const RecipeInputs(
        style: PizzaStyle.sicilian,
        flours: [FlourShare(wholemeal, 100)],
      ),
    );
    expect(o.proteinPct, 13);
    expect(o.hydrationPct, 80.5); // max(70.5 + 10, 75)
  });

  test('Roman labels sweetener as malt; thin crust is round', () {
    expect(sweetenerName(PizzaStyle.roman), 'Malt');
    expect(sweetenerName(PizzaStyle.newYork), 'Sugar');
    final roman = calc(const RecipeInputs(style: PizzaStyle.roman));
    expect(roman.finalDough.any((l) => l.name == 'Malt'), isTrue);
    final thin = calc(
      const RecipeInputs(
        style: PizzaStyle.thin,
        mode: EntryMode.pizzas,
        diameterCm: 30.48,
      ),
    );
    expect(thin.ballWeightG, closeTo(190, 1));
  });

  test('lines carry the unrounded baker\'s %, FR6 decimals and kind', () {
    // 418 g at 63.5%: water rounds to 265 g but stays 63.5% of flour.
    final o = calc(const RecipeInputs(style: PizzaStyle.newYork, flourG: 418));
    final water = o.finalDough.firstWhere((l) => l.name == 'Water');
    expect(water.grams, 265);
    expect(water.pct, closeTo(63.5, 1e-9));
    expect(
      {for (final l in o.finalDough) l.name: (l.decimals, l.kind)},
      {
        'UK strong white': (0, LineKind.flour),
        'Water': (0, LineKind.water),
        'Salt': (1, LineKind.salt),
        'IDY': (2, LineKind.yeast),
        'Oil': (1, LineKind.oil),
        'Sugar': (1, LineKind.sugar),
      },
    );

    final poolish = calc(
      const RecipeInputs(
        style: PizzaStyle.newYork,
        preferment: Preferment.poolish,
      ),
    );
    expect([for (final l in poolish.preferment) l.pct], [30, 30, 0.03]);
    expect([for (final l in poolish.preferment) l.decimals], [0, 0, 2]);
    expect(poolish.finalDough.first.pct, 70);
  });

  test('resetToStyle drops every baker\'s % override, keeps the rest', () {
    const i = RecipeInputs(
      style: PizzaStyle.newYork,
      mode: EntryMode.pizzas,
      flourG: 500,
      pizzas: 3,
      diameterCm: 35,
      panWCm: 20,
      panLCm: 30,
      thickness: 0.85,
      flours: [FlourShare(pizzeria, 100)],
      plan: [Stage(6, 22)],
      yeast: Yeast.ady,
      preferment: Preferment.poolish,
      hydrationOverride: 70,
      saltPct: 3,
      oilPct: 1,
      sugarPct: 0,
      residuePct: 5,
      yeastKnob: 1.2,
      hydrationSlope: 1.4,
      wholegrainAbsorption: 80,
      fromTip: {Pct.oil},
    );
    final r = i.resetToStyle();
    expect([
      r.hydrationOverride,
      r.saltPct,
      r.oilPct,
      r.sugarPct,
      r.residuePct,
    ], everyElement(isNull));
    expect(r.fromTip, isEmpty);
    expect(
      [r.style, r.mode, r.flourG, r.pizzas, r.diameterCm, r.panWCm, r.panLCm],
      [PizzaStyle.newYork, EntryMode.pizzas, 500, 3, 35, 20, 30],
    );
    expect([r.thickness, r.yeastKnob, r.yeast], [0.85, 1.2, Yeast.ady]);
    expect([r.hydrationSlope, r.wholegrainAbsorption], [1.4, 80]);
    expect(r.flours, same(i.flours));
    expect(r.plan, same(i.plan));
    expect(r.preferment, same(Preferment.poolish));
  });

  test('flour mode: at least one ball', () {
    final o = calc(
      const RecipeInputs(style: PizzaStyle.neapolitan, flourG: 50),
    );
    expect(o.ballCount, 1);
  });
}
