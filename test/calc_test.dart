import 'package:flutter_test/flutter_test.dart';
import 'package:pizzalator/core/calc.dart';

double g(RecipeOutputs o, String name) =>
    o.finalDough.firstWhere((l) => l.name == name).grams;

void main() {
  const pizzeria = Flour('Italian 00 pizza', 12.5);

  test('Neapolitan golden: 1000 g @ 12.5% / 62% -> 620 g water, 28 g salt', () {
    final o = calc(const RecipeInputs(
        style: PizzaStyle.neapolitan, flours: [FlourShare(pizzeria, 100)]));
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
    final o = calc(const RecipeInputs(
      style: PizzaStyle.neapolitan,
      flours: [
        FlourShare(Flour.ukStrong, 80),
        FlourShare(Flour('Wholemeal', 13, wholegrain: true), 20),
      ],
    ));
    expect(o.proteinPct, 13); // white flours only
    expect(o.hydrationPct, 65); // 0.8×62.5 + 0.2×75
    expect(g(o, 'Water'), 650);
    expect(g(o, 'UK strong white'), 800);
    expect(g(o, 'Wholemeal'), 200);
    expect(o.warnings.any((w) => w.contains('Wholegrain')), isTrue);
  });

  test('hydration clamps to style range', () {
    final o = calc(const RecipeInputs(
        style: PizzaStyle.neapolitan,
        flours: [FlourShare(Flour('Very strong', 16), 100)]));
    expect(o.hydrationPct, 65);
  });

  test('pizzas mode: 4 × 30 cm Neapolitan ≈ 250 g each', () {
    final o = calc(const RecipeInputs(
        style: PizzaStyle.neapolitan, mode: EntryMode.pizzas, pizzas: 4));
    expect(o.ballWeightG, 250);
    expect(o.ballCount, 4);
    expect(o.totalDoughG, closeTo(1000, 2));
    // flour + water + salt + yeast == dough
    final sum = o.finalDough.fold(0.0, (s, l) => s + l.grams);
    expect(sum, closeTo(1000, 2));
  });

  test('Detroit pan weight 10×14 in ≈ 413 g, 10% residue', () {
    final o = calc(const RecipeInputs(
        style: PizzaStyle.detroit,
        mode: EntryMode.pizzas,
        pizzas: 1,
        panWCm: 25.4,
        panLCm: 35.56));
    expect(o.ballWeightG, 413);
    expect(o.totalDoughG, closeTo(413 * 1.1, 1));
  });

  test('poolish carves out of totals', () {
    final o = calc(const RecipeInputs(
        style: PizzaStyle.newYork,
        flours: [FlourShare(pizzeria, 100)],
        preferment: Preferment.poolish));
    expect(o.preferment.first.grams, 300); // flour
    expect(o.preferment[1].grams, 300); // water @100%
    expect(g(o, 'Italian 00 pizza'), 700);
    expect(g(o, 'Water'), 330); // 630 − 300
    final pre = o.preferment.firstWhere((l) => l.name == 'IDY').grams;
    expect(pre, 0.3); // 0.1% of 300
  });

  test('sourdough: no commercial yeast, 15% starter', () {
    final o = calc(const RecipeInputs(
        style: PizzaStyle.neapolitan,
        flours: [FlourShare(pizzeria, 100)],
        yeast: Yeast.sourdough));
    expect(o.yeastPct, 0);
    expect(g(o, 'Starter'), 300); // 150 flour + 150 water
    expect(g(o, 'Italian 00 pizza'), 850);
    expect(g(o, 'Water'), 470);
  });

  test('yeast model: reference plan returns idyRef, fridge-only boosted', () {
    expect(idyPct(PizzaStyle.newYork, const [Stage(24, 20)]), closeTo(0.30, 1e-9));
    expect(idyPct(PizzaStyle.newYork, const [Stage(48, 20)]), closeTo(0.15, 1e-9));
    final fridge = idyPct(PizzaStyle.newYork, const [Stage(24, 4)]);
    final mixed = idyPct(PizzaStyle.newYork, const [Stage(1, 20), Stage(24, 4)]);
    expect(fridge, greaterThan(mixed));
    final o = calc(const RecipeInputs(style: PizzaStyle.newYork, yeast: Yeast.fresh));
    final idy = calc(const RecipeInputs(style: PizzaStyle.newYork));
    expect(o.yeastPct, closeTo(idy.yeastPct * 3, 0.02));
  });

  test('rounding: flour/water 1 g, salt 0.1 g, yeast 0.01 g', () {
    expect(r1(619.6), 620);
    expect(r01(27.96), 28.0);
    expect(r001(1.2349), 1.23);
  });

  test('weak flour warning for New York', () {
    final o = calc(const RecipeInputs(
        style: PizzaStyle.newYork,
        flours: [FlourShare(Flour('UK plain', 10), 100)]));
    expect(o.warnings.any((w) => w.contains('Weak flour')), isTrue);
  });
}
