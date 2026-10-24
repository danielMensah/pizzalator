import 'package:flutter_test/flutter_test.dart';
import 'package:pizzalator/core/calc.dart';
import 'package:pizzalator/core/export_text.dart';
import 'package:pizzalator/core/oven.dart';
import 'package:pizzalator/core/schedule.dart';

const _wholemeal = Flour('Wholemeal', 13, wholegrain: true);

// Recipe mockup: NY, 2 × 35 cm, UK strong, home oven + steel.
const ny = RecipeInputs(
  style: PizzaStyle.newYork,
  mode: EntryMode.pizzas,
  pizzas: 2,
  diameterCm: 35,
);

String why(RecipeInputs i, [OvenSetup oven = OvenSetup.homeSteel]) =>
    whyTheseNumbers(i, calc(i), oven);

void main() {
  group('numbers', () {
    test('pctText: one decimal from 1 %, two below, zeros trimmed', () {
      expect(pctText(100), '100');
      expect(pctText(62.5), '62.5');
      expect(pctText(2.0), '2');
      expect(pctText(63.636), '63.6');
      expect(pctText(0.4282), '0.43');
      expect(pctText(0.1), '0.1');
    });

    test('gramsText keeps the line\'s FR6 decimals', () {
      expect(
        gramsText(const Line(LineKind.water, 'Water', 625, 62.5)),
        '625 g',
      );
      expect(
        gramsText(const Line(LineKind.salt, 'Salt', 28, 2.8, 1)),
        '28.0 g',
      );
      expect(
        gramsText(const Line(LineKind.yeast, 'IDY', 2.4, 0.24, 2)),
        '2.40 g',
      );
      final o = calc(ny);
      expect(
        [for (final l in o.finalDough) gramsText(l)],
        ['418 g', '266 g', '9.2 g', '2.32 g', '10.5 g', '6.3 g'],
      );
    });

    test('pctOfFlour is the formula %, not rounded grams over flour', () {
      final o = calc(
        const RecipeInputs(style: PizzaStyle.newYork, flourG: 418),
      );
      expect(pctOfFlour(o.finalDough.first), '100%');
      expect(pctOfFlour(o.finalDough[1]), '63.5%'); // 265 / 418 = 63.4
      expect(
        pctOfFlour(const Line(LineKind.salt, 'Salt', 9.2, 2.2, 1)),
        '2.2%',
      );
    });

    test('lineLabel spells out yeast types', () {
      expect(
        lineLabel(const Line(LineKind.yeast, 'IDY', 1, 0)),
        'Instant yeast',
      );
      expect(
        lineLabel(const Line(LineKind.yeast, 'ADY', 1, 0)),
        'Active dry yeast',
      );
      expect(
        lineLabel(const Line(LineKind.yeast, 'FRESH', 1, 0)),
        'Fresh yeast',
      );
      expect(lineLabel(const Line(LineKind.water, 'Water', 1, 0)), 'Water');
    });

    test('clockText: weekday and 24 h time', () {
      expect(clockText(DateTime(2026, 10, 30, 19)), 'Fri 19:00');
      expect(clockText(DateTime(2026, 10, 28, 9, 5)), 'Wed 09:05');
      expect(clockText(DateTime(2026, 11, 1, 0, 30)), 'Sun 00:30');
    });

    test('whenText: absolute with a bake time, else offset from start', () {
      ScheduleItem item(Duration offset, [DateTime? at]) => ScheduleItem(
        step: ScheduleStep.mix,
        name: 'Mix',
        startOffset: offset,
        duration: Duration.zero,
        note: '',
        at: at,
      );
      expect(whenText(item(Duration.zero)), 'Start');
      expect(whenText(item(const Duration(hours: 1, minutes: 54))), '+1 h 54');
      expect(
        whenText(item(Duration.zero, DateTime(2026, 10, 28, 16, 6))),
        'Wed 16:06',
      );
    });
  });

  group('preferment', () {
    test('sourdough without a preferment means a starter, as in calc', () {
      expect(
        effectivePreferment(
          const RecipeInputs(
            style: PizzaStyle.neapolitan,
            yeast: Yeast.sourdough,
          ),
        ),
        same(Preferment.sourdough),
      );
      expect(
        effectivePreferment(
          const RecipeInputs(
            style: PizzaStyle.neapolitan,
            preferment: Preferment.poolish,
          ),
        ),
        same(Preferment.poolish),
      );
      expect(
        effectivePreferment(const RecipeInputs(style: PizzaStyle.neapolitan)),
        same(Preferment.none),
      );
    });

    test('labels', () {
      expect(prefermentLabel(PrefermentKind.poolish), 'Poolish');
      expect(prefermentLabel(PrefermentKind.biga), 'Biga');
      expect(prefermentLabel(PrefermentKind.sourdough), 'Starter');
      expect(prefermentLabel(PrefermentKind.none), 'Preferment');
    });
  });

  group('summary', () {
    test('round style: style · count × size · flour · surface', () {
      expect(
        summaryText(ny, calc(ny), OvenSetup.homeSteel),
        'New York · 2 × 35 cm · UK strong white · steel',
      );
    });

    test('sizes follow the cm / in toggle', () {
      expect(
        summaryText(ny, calc(ny), OvenSetup.homeSteel, unit: LengthUnit.inch),
        'New York · 2 × 13.8 in · UK strong white · steel',
      );
      const pan = RecipeInputs(style: PizzaStyle.detroit, panLCm: 35.56);
      expect(
        summaryText(pan, calc(pan), OvenSetup.homeSteel, unit: LengthUnit.inch),
        contains(' × 9.8×14 in · '),
      );
    });

    test('pan style, blend and outdoor oven', () {
      const i = RecipeInputs(
        style: PizzaStyle.detroit,
        mode: EntryMode.pizzas,
        pizzas: 1,
        panWCm: 25.5,
        flours: [FlourShare(Flour.ukStrong, 80), FlourShare(_wholemeal, 20)],
      );
      expect(
        summaryText(i, calc(i), OvenSetup.outdoor),
        'Detroit · 1 × 25.5×35 cm · UK strong white + Wholemeal · outdoor',
      );
    });

    test('yieldText: balls for round styles, pans for pan styles', () {
      expect(yieldText(ny, calc(ny)), '2 balls · 356 g');
      const one = RecipeInputs(
        style: PizzaStyle.newYork,
        mode: EntryMode.pizzas,
        pizzas: 1,
      );
      expect(yieldText(one, calc(one)), startsWith('1 ball · '));
      const pan = RecipeInputs(
        style: PizzaStyle.detroit,
        mode: EntryMode.pizzas,
        pizzas: 1,
      );
      expect(yieldText(pan, calc(pan)), '1 pan · 400 g');
      const pans = RecipeInputs(
        style: PizzaStyle.sicilian,
        mode: EntryMode.pizzas,
        pizzas: 2,
      );
      expect(yieldText(pans, calc(pans)), startsWith('2 pans · '));
    });
  });

  group('whyTheseNumbers', () {
    test('mockup case: NY on steel', () {
      expect(
        why(ny),
        'UK strong white at 13% protein lifts New York hydration 0.5 pp to '
        '63.5%. Sugar 1.5% and oil 2.5% give colour at 275 °C that a lean '
        'dough would not get. Steel browns the base in time, so no need to '
        'lower hydration.',
      );
    });

    test('weak flour lowers hydration', () {
      const i = RecipeInputs(
        style: PizzaStyle.newYork,
        flours: [FlourShare(Flour('UK plain', 10), 100)],
      );
      expect(
        why(i),
        startsWith(
          'UK plain at 10% protein lowers New York hydration 2.5 pp to 60.5%.',
        ),
      );
    });

    test('12.5 % flour keeps the base hydration', () {
      const i = RecipeInputs(
        style: PizzaStyle.newYork,
        flours: [FlourShare(Flour('Italian 00 pizza', 12.5), 100)],
      );
      expect(
        why(i),
        startsWith(
          'Italian 00 pizza at 12.5% protein keeps New York at its 63% base '
          'hydration.',
        ),
      );
    });

    test('blend with wholegrain', () {
      const i = RecipeInputs(
        style: PizzaStyle.newYork,
        flours: [FlourShare(Flour.ukStrong, 80), FlourShare(_wholemeal, 20)],
      );
      expect(
        why(i),
        startsWith(
          'Your blend at 13% protein lifts New York hydration 2.8 pp to 65.8%. '
          'The wholegrain share absorbs more water, so it gets at least 75%.',
        ),
      );
    });

    test('hand-set hydration on a lean Neapolitan, over the steel cap', () {
      const i = RecipeInputs(
        style: PizzaStyle.neapolitan,
        hydrationOverride: 66,
      );
      expect(
        why(i),
        'Hydration set by hand to 66%, so the flour model is skipped. '
        'A lean dough browns slowly at 275 °C. Above 65% the base steams '
        'before it browns in a home oven.',
      );
    });

    test('Neapolitan on stone caps lower', () {
      const i = RecipeInputs(
        style: PizzaStyle.neapolitan,
        hydrationOverride: 64,
      );
      expect(
        why(i, OvenSetup.homeStone),
        endsWith(
          'Above 63% the base steams '
          'before it browns in a home oven.',
        ),
      );
      expect(why(i), endsWith('so no need to lower hydration.'));
    });

    test('stone and tray surfaces', () {
      expect(
        why(ny, OvenSetup.homeStone),
        endsWith(
          'Stone browns the base slower than steel, so the bake runs a '
          'little longer.',
        ),
      );
      expect(
        why(ny, OvenSetup.homeTray),
        endsWith('A tray heats the base slowly, so the bake runs longer.'),
      );
    });

    test('pan style at home, one enrichment, malt for Roman', () {
      const roman = RecipeInputs(style: PizzaStyle.roman, oilPct: 0);
      expect(
        why(roman),
        endsWith(
          'Malt 0.5% gives colour at 275 °C that a lean dough would not get. '
          'In the pan, oil fries the base, so the surface matters less.',
        ),
      );
      const oily = RecipeInputs(style: PizzaStyle.detroit, sugarPct: 0);
      expect(why(oily), contains('Oil 3% gives colour'));
    });

    test('outdoor: sugar can scorch, lean dough is fine', () {
      expect(
        why(ny, OvenSetup.outdoor),
        endsWith('Sugar 1.5% can scorch at 450 °C; watch the rim.'),
      );
      expect(
        why(
          const RecipeInputs(style: PizzaStyle.neapolitan),
          OvenSetup.outdoor,
        ),
        endsWith('At 450 °C the crust colours from heat alone.'),
      );
    });
  });

  group('recipeText', () {
    final schedule = buildSchedule(
      plan: PizzaStyle.newYork.plan,
      preferment: Preferment.none,
      handsOn: const Duration(minutes: 114),
      afterBulk: const Duration(minutes: 5),
      bakeAt: DateTime(2026, 10, 30, 19),
    );
    const water = (
      celsius: 29,
      caption: 'for 24 °C dough · flour 20 °C · room 21 °C · hand mix',
    );

    test('mockup case, golden', () {
      expect(
        recipeText(
          inputs: ny,
          outputs: calc(ny),
          oven: OvenSetup.homeSteel,
          schedule: schedule,
          water: water,
        ),
        '''
New York · 2 × 35 cm · UK strong white · steel
Hydration 63.5% · protein 13%

Final dough
- UK strong white: 418 g (100%)
- Water: 266 g (63.5%)
- Salt: 9.2 g (2.2%)
- Instant yeast: 2.32 g (0.55%)
- Oil: 10.5 g (2.5%)
- Sugar: 6.3 g (1.5%)

Water 29 °C for 24 °C dough · flour 20 °C · room 21 °C · hand mix
Yield 2 balls · 356 g · total dough 712 g

Schedule
- Wed 16:01 Mix + dough routine. Timers run it: 1 h 54.
- Wed 17:55 Bulk in container. 1 h at 20 °C, covered.
- Wed 18:55 Fridge. 48 h at 4 °C, in the container.
- Fri 18:55 Divide into balls. Into oiled tubs, covered.
- Fri 19:00 Bake. See bake card.

Bake: Home oven · steel
Max 275 °C · 2nd rack from top
1. Preheat steel 45–60 min at max, fan off.
2. Stretch on semolina and top lightly.
3. Launch. Bake 5–7 min until the rim blisters.
4. Switch to grill for the last 1–2 min. Watch the rim, not the clock.
5. Rest 60 s on a rack before cutting.
''',
      );
    });

    test('preferment gets its own table, first', () {
      const i = RecipeInputs(
        style: PizzaStyle.neapolitan,
        preferment: Preferment.poolish,
      );
      final text = recipeText(
        inputs: i,
        outputs: calc(i),
        oven: OvenSetup.homeSteel,
        schedule: schedule,
        water: water,
      );
      expect(
        text,
        contains(
          'Poolish\n'
          '- Flour: 300 g (30%)\n'
          '- Water: 300 g (30%)\n'
          '- Instant yeast: 0.30 g (0.03%)\n'
          '\n'
          'Final dough\n'
          '- UK strong white: 700 g (70%)\n',
        ),
      );
    });
  });
}
