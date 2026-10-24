import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pizzalator/core/calc.dart';
import 'package:pizzalator/core/oven.dart';
import 'package:pizzalator/state/oven.dart';
import 'package:pizzalator/state/recipe.dart';

void main() {
  test('starts on home oven + steel', () {
    final c = ProviderContainer.test();
    expect(c.read(ovenProvider), same(OvenSetup.homeSteel));
  });

  test('set switches the oven and re-derives the bake card', () {
    final c = ProviderContainer.test();
    expect(c.read(bakeCardProvider).title, 'Home oven · steel');
    c.read(ovenProvider.notifier).set(OvenSetup.homeStone);
    expect(c.read(ovenProvider), same(OvenSetup.homeStone));
    expect(c.read(bakeCardProvider).title, 'Home oven · stone');
  });

  test('pick keeps the max temperature within an oven kind', () {
    final c = ProviderContainer.test();
    final n = c.read(ovenProvider.notifier);
    n.setMaxTemp(250);
    n.pick(OvenSetup.homeStone);
    expect(c.read(ovenProvider).surface, Surface.stone);
    expect(c.read(ovenProvider).maxTempC, 250);
    n.pick(OvenSetup.outdoor);
    expect(c.read(ovenProvider), same(OvenSetup.outdoor));
    n.pick(OvenSetup.homeSteel);
    expect(c.read(ovenProvider), same(OvenSetup.homeSteel));
  });

  test('setMaxTemp clamps to the oven kind; surface stays', () {
    final c = ProviderContainer.test();
    final n = c.read(ovenProvider.notifier);
    n.setMaxTemp(350);
    expect(c.read(ovenProvider).maxTempC, 300);
    n.setMaxTemp(100);
    expect(c.read(ovenProvider).maxTempC, 200);
    expect(c.read(ovenProvider).surface, Surface.steel);
    n.pick(OvenSetup.outdoor);
    n.setMaxTemp(600);
    expect(c.read(ovenProvider).maxTempC, 500);
    n.setMaxTemp(250);
    expect(c.read(ovenProvider).maxTempC, 300);
  });

  test('a cool home oven warns Neapolitan off (PRD §4.4)', () {
    final c = ProviderContainer.test();
    c.read(ovenProvider.notifier).setMaxTemp(250);
    expect(c.read(ovenWarningsProvider).single, contains('260 °C'));
    expect(c.read(bakeCardProvider).subtitle, startsWith('Max 250 °C'));
  });

  test('dough tips follow the flour', () {
    final c = ProviderContainer.test();
    expect(c.read(doughTipsProvider), isEmpty);
    c
        .read(recipeProvider.notifier)
        .update(
          (i) => i.copyWith(
            style: PizzaStyle.newYork,
            flours: const [FlourShare(Flour('UK plain', 10), 100)],
          ),
        );
    expect(c.read(doughTipsProvider).single.title, 'Flour suggestion');
  });

  test('bake card follows the style', () {
    final c = ProviderContainer.test();
    c.read(recipeProvider.notifier).setStyle(PizzaStyle.newYork);
    expect(c.read(bakeCardProvider).steps.join(' '), contains('5–7 min'));
  });

  test('tips apply through the recipe notifier, then drop out', () {
    final c = ProviderContainer.test();
    final tip = c.read(ovenTipsProvider).single;
    expect(tip.applyLabel, startsWith('Apply'));
    c.read(recipeProvider.notifier).update(tip.apply);
    expect(c.read(recipeProvider).oilPct, 1.5);
    expect(c.read(ovenTipsProvider).single.applyLabel, 'Revert to style');
  });

  test('warnings follow oven and recipe', () {
    final c = ProviderContainer.test();
    expect(c.read(ovenWarningsProvider), isEmpty);
    c.read(ovenProvider.notifier).set(OvenSetup.homeTray);
    expect(c.read(ovenWarningsProvider).single, contains('New York'));
    c.read(recipeProvider.notifier).setStyle(PizzaStyle.newYork);
    expect(c.read(ovenWarningsProvider), isEmpty);
  });
}
