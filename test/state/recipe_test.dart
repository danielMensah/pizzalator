import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pizzalator/core/calc.dart';
import 'package:pizzalator/state/recipe.dart';

void main() {
  test('starts with first-launch defaults: Neapolitan, UK strong, 1000 g', () {
    final c = ProviderContainer.test();
    final i = c.read(recipeProvider);
    expect(i.style, PizzaStyle.neapolitan);
    expect(i.flours.single.flour, Flour.ukStrong);
    expect(i.flourG, 1000);
    expect(c.read(outputsProvider).hydrationPct, 62.5);
  });

  test('setStyle re-derives outputs', () {
    final c = ProviderContainer.test();
    c.read(recipeProvider.notifier).setStyle(PizzaStyle.newYork);
    expect(c.read(recipeProvider).style, PizzaStyle.newYork);
    expect(c.read(outputsProvider).hydrationPct, 63.5);
  });

  test('setStyle drops oven-tip overrides and takes the style size', () {
    final c = ProviderContainer.test();
    final n = c.read(recipeProvider.notifier);
    n.update(
      (i) => i
          .set(Pct.oil, 1.5, tip: true)
          .set(Pct.sugar, 1, tip: true)
          .set(Pct.hydration, 65, tip: true),
    );
    n.setStyle(PizzaStyle.newYork);
    final i = c.read(recipeProvider);
    expect([i.oilPct, i.sugarPct, i.hydrationOverride], everyElement(isNull));
    expect(i.fromTip, isEmpty);
    expect(i.diameterCm, 35);
    final oil = c
        .read(outputsProvider)
        .finalDough
        .firstWhere((l) => l.name == 'Oil');
    expect(oil.grams, 25); // NY's own 2.5%, not the Neapolitan tip's 1.5%
    n.setStyle(PizzaStyle.roman);
    expect(
      [c.read(recipeProvider).panWCm, c.read(recipeProvider).panLCm],
      [30, 40],
    );
    expect(c.read(recipeProvider).flourG, 1000, reason: 'amount kept');
    n.update((i) => i.copyWith(oilPct: 4, panWCm: 20));
    n.setStyle(PizzaStyle.roman);
    expect(
      [c.read(recipeProvider).oilPct, c.read(recipeProvider).panWCm],
      [4, 20],
      reason: 're-tapping the current style changes nothing',
    );
  });

  test('setStyle keeps the baker\'s % the user set (FR1)', () {
    final c = ProviderContainer.test();
    final n = c.read(recipeProvider.notifier);
    n.update((i) => i.set(Pct.salt, 2.6).set(Pct.oil, 1.5, tip: true));
    n.setStyle(PizzaStyle.newYork);
    final i = c.read(recipeProvider);
    expect(i.saltPct, 2.6);
    expect(i.oilPct, isNull);
  });

  test('setStyle keeps thin / std / thick across the styles\' presets', () {
    final c = ProviderContainer.test();
    final n = c.read(recipeProvider.notifier);
    n.setStyle(PizzaStyle.detroit);
    n.update((i) => i.copyWith(thickness: thicknessPresets(i.style).last));
    n.setStyle(PizzaStyle.newYork);
    expect(c.read(recipeProvider).thickness, 1.15);
    n.update((i) => i.copyWith(thickness: 1.07));
    n.setStyle(PizzaStyle.detroit);
    expect(c.read(recipeProvider).thickness, 1.07, reason: 'not a preset');
  });

  test('setRoomC retimes the plan room stages; fridge-only has none', () {
    final c = ProviderContainer.test();
    final n = c.read(recipeProvider.notifier);
    n.setRoomC(25);
    expect(c.read(recipeProvider).activePlan, const [
      Stage(2, 25),
      Stage(24, 4),
    ]);
    n.update((i) => i.copyWith(plan: const [Stage(48, 4)]));
    n.setRoomC(22);
    expect(c.read(recipeProvider).activePlan, const [Stage(48, 4)]);
  });

  test('setFlourG scales water', () {
    final c = ProviderContainer.test();
    c.read(recipeProvider.notifier).setFlourG(500);
    final water = c
        .read(outputsProvider)
        .finalDough
        .firstWhere((l) => l.name == 'Water');
    expect(water.grams, 313); // 500 × 62.5%
  });

  test('setMode keeps percentages and carries the totals (FR3)', () {
    final c = ProviderContainer.test();
    final n = c.read(recipeProvider.notifier);
    n.setMode(EntryMode.pizzas);
    expect(c.read(recipeProvider).mode, EntryMode.pizzas);
    expect(c.read(outputsProvider).hydrationPct, 62.5);
    // 1000 g of flour made 7 balls; pizzas mode starts from those 7.
    expect(c.read(recipeProvider).pizzas, 7);
    expect(c.read(outputsProvider).ballCount, 7);
    final flour = c.read(outputsProvider).totalFlourG;
    n.setMode(EntryMode.flour);
    expect(c.read(recipeProvider).flourG, flour);
    final same = c.read(recipeProvider);
    n.setMode(EntryMode.flour);
    expect(c.read(recipeProvider), same);
  });

  test('update applies any copyWith change', () {
    final c = ProviderContainer.test();
    c
        .read(recipeProvider.notifier)
        .update((i) => i.copyWith(hydrationOverride: 70));
    expect(c.read(outputsProvider).hydrationPct, 70);
  });
}
