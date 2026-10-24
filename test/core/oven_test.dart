import 'package:flutter_test/flutter_test.dart';
import 'package:pizzalator/core/calc.dart';
import 'package:pizzalator/core/oven.dart';

const neo = RecipeInputs(style: PizzaStyle.neapolitan);
const ny = RecipeInputs(style: PizzaStyle.newYork);

List<OvenTip> tips(RecipeInputs i, OvenSetup o) => ovenTips(i, calc(i), o);

void main() {
  group('OvenSetup', () {
    test('first-launch default is home oven + steel at 275 °C', () {
      const o = OvenSetup.homeSteel;
      expect(o.kind, OvenKind.home);
      expect(o.surface, Surface.steel);
      expect(o.maxTempC, 275);
      expect(o.label, 'Home oven · steel');
      expect(o.name, 'Steel');
    });

    test('presets match the Main picker', () {
      expect(OvenSetup.presets.map((o) => o.name), [
        'Steel',
        'Stone',
        'Tray',
        'Outdoor',
      ]);
      expect(OvenSetup.presets.map((o) => o.label), [
        'Home oven · steel',
        'Home oven · stone',
        'Home oven · tray',
        'Outdoor oven',
      ]);
      expect(OvenSetup.outdoor.kind, OvenKind.outdoor);
      expect(OvenSetup.outdoor.maxTempC, greaterThanOrEqualTo(400));
    });

    test('copyWith changes only what is passed', () {
      final o = OvenSetup.homeSteel.copyWith(maxTempC: 250);
      expect(o.kind, OvenKind.home);
      expect(o.surface, Surface.steel);
      expect(o.maxTempC, 250);
      final p = o.copyWith(kind: OvenKind.outdoor, surface: Surface.stone);
      expect(p.kind, OvenKind.outdoor);
      expect(p.surface, Surface.stone);
      expect(p.maxTempC, 250);
    });
  });

  group('ovenTips', () {
    test('Neapolitan on steel: one-tap oil and sugar for browning', () {
      final t = tips(neo, OvenSetup.homeSteel);
      expect(t, hasLength(1));
      expect(t.single.text, contains('1.5% oil'));
      expect(t.single.text, contains('0.5% diastatic malt'));
      expect(t.single.text, contains('65%'));
      expect(t.single.applyLabel, 'Apply +1.5% oil, +1% sugar');

      final applied = t.single.apply(neo);
      expect(neo.oilPct, isNull, reason: 'tips never mutate');
      expect(applied.oilPct, 1.5);
      expect(applied.sugarPct, 1);
      final o = calc(applied);
      expect(o.finalDough.firstWhere((l) => l.name == 'Oil').grams, 15);
      expect(o.finalDough.firstWhere((l) => l.name == 'Sugar').grams, 10);
    });

    test(
      'applied enrichment is not suggested again; revert restores style',
      () {
        final applied = tips(neo, OvenSetup.homeSteel).single.apply(neo);
        final t = tips(applied, OvenSetup.homeSteel);
        expect(t, hasLength(1));
        expect(t.single.applyLabel, 'Revert to style');
        expect(t.any((x) => x.applyLabel.startsWith('Apply')), isFalse);

        final reverted = t.single.apply(applied);
        expect(reverted.oilPct, isNull, reason: 'back on the style default');
        expect(reverted.sugarPct, isNull);
        expect(
          tips(reverted, OvenSetup.homeSteel).single.applyLabel,
          startsWith('Apply'),
        );
      },
    );

    test('enrichment never lowers oil the user already raised', () {
      final i = neo.copyWith(oilPct: 2);
      final applied = tips(i, OvenSetup.homeSteel).single.apply(i);
      expect(applied.oilPct, 2);
      expect(applied.sugarPct, 1);
      expect(applied.fromTip, {Pct.sugar}, reason: 'the 2 % stays the user\'s');
    });

    test('tip edits are marked as tips', () {
      final applied = tips(neo, OvenSetup.homeSteel).single.apply(neo);
      expect(applied.fromTip, {Pct.oil, Pct.sugar});
    });

    test('revert clears only the enrichment, not other edits', () {
      final applied = tips(
        neo,
        OvenSetup.homeSteel,
      ).single.apply(neo).set(Pct.salt, 2.5).set(Pct.hydration, 63, tip: true);
      final reverted = tips(
        applied,
        OvenSetup.homeSteel,
      ).firstWhere((t) => t.applyLabel == 'Revert to style').apply(applied);
      expect([reverted.oilPct, reverted.sugarPct], [null, null]);
      expect(reverted.saltPct, 2.5);
      expect(reverted.hydrationOverride, 63, reason: 'the cap tip is separate');
      expect(reverted.fromTip, {Pct.hydration});
    });

    test('hydrationCap: 63 % on stone, 65 % otherwise', () {
      expect(hydrationCap(OvenSetup.homeStone), kHydrationCapStone);
      expect(hydrationCap(OvenSetup.homeSteel), kHydrationCap);
      expect(hydrationCap(OvenSetup.homeTray), kHydrationCap);
      expect([kHydrationCapStone, kHydrationCap], [63, 65]);
    });

    test('stone caps Neapolitan hydration at 63%', () {
      const strong = RecipeInputs(
        style: PizzaStyle.neapolitan,
        flours: [FlourShare(Flour('UK very strong / Canadian', 14.5), 100)],
      );
      expect(calc(strong).hydrationPct, 64);
      final t = tips(strong, OvenSetup.homeStone);
      expect(t, hasLength(2));
      expect(t.first.text, contains('63%'));
      final cap = t.firstWhere((x) => x.applyLabel == 'Cap hydration at 63%');
      final capped = cap.apply(strong);
      expect(capped.hydrationOverride, 63);
      expect(calc(capped).hydrationPct, 63);
      expect(
        tips(capped, OvenSetup.homeStone).map((x) => x.applyLabel),
        isNot(contains('Cap hydration at 63%')),
      );
      // 64 is under the steel cap.
      expect(tips(strong, OvenSetup.homeSteel), hasLength(1));
    });

    test('steel caps wholemeal-heavy Neapolitan at 65%', () {
      const ww = RecipeInputs(
        style: PizzaStyle.neapolitan,
        flours: [
          FlourShare(Flour.ukStrong, 60),
          FlourShare(Flour('Wholemeal', 13, wholegrain: true), 40),
        ],
      );
      expect(calc(ww).hydrationPct, 67.5);
      final cap = tips(
        ww,
        OvenSetup.homeSteel,
      ).firstWhere((x) => x.applyLabel == 'Cap hydration at 65%');
      expect(cap.apply(ww).hydrationOverride, 65);
    });

    test('tray gets the same enrichment tip', () {
      final t = tips(neo, OvenSetup.homeTray);
      expect(t.single.applyLabel, 'Apply +1.5% oil, +1% sugar');
    });

    test('other styles at home: no dough edits', () {
      for (final s in PizzaStyle.values.where(
        (s) => s != PizzaStyle.neapolitan,
      )) {
        for (final o in [
          OvenSetup.homeSteel,
          OvenSetup.homeStone,
          OvenSetup.homeTray,
        ]) {
          expect(tips(RecipeInputs(style: s), o), isEmpty, reason: '$s $o');
        }
      }
    });

    test('outdoor: lean Neapolitan needs nothing', () {
      expect(tips(neo, OvenSetup.outdoor), isEmpty);
    });

    test('outdoor: sugar in a round dough gets a set-to-0 tip', () {
      final t = tips(ny, OvenSetup.outdoor);
      expect(t.single.text, contains('400 °C'));
      expect(t.single.applyLabel, 'Set sugar to 0');
      final applied = t.single.apply(ny);
      expect(applied.sugarPct, 0);
      expect(tips(applied, OvenSetup.outdoor), isEmpty);
    });

    test('outdoor: pan styles bake cooler, no sugar tip', () {
      for (final s in [
        PizzaStyle.detroit,
        PizzaStyle.roman,
        PizzaStyle.sicilian,
      ]) {
        expect(tips(RecipeInputs(style: s), OvenSetup.outdoor), isEmpty);
      }
    });
  });

  group('doughTips', () {
    const plainNy = RecipeInputs(
      style: PizzaStyle.newYork,
      flours: [FlourShare(Flour('UK plain', 10), 100)],
    );
    List<OvenTip> dough(RecipeInputs i) => doughTips(i, calc(i));

    test('weak flour: one tap lowers hydration 2 pp, then it is quiet', () {
      final t = dough(plainNy).single;
      expect(t.title, 'Flour suggestion');
      expect(t.text, startsWith('Weak flour for this style'));
      expect(t.applyLabel, 'Lower hydration 2 pp');
      final applied = t.apply(plainNy);
      expect(calc(plainNy).hydrationPct, 60.5);
      expect(applied.hydrationOverride, 58.5);
      expect(applied.fromTip, {Pct.hydration});
      expect(dough(applied), isEmpty);
    });

    test('strong flour or an exempt style: nothing', () {
      expect(dough(ny), isEmpty);
      expect(dough(plainNy.copyWith(style: PizzaStyle.neapolitan)), isEmpty);
    });

    test('oven tips keep their own title', () {
      expect(tips(neo, OvenSetup.homeSteel).single.title, 'Oven suggestion');
    });
  });

  group('ovenWarnings', () {
    test('default Neapolitan on steel: none', () {
      expect(ovenWarnings(neo, OvenSetup.homeSteel), isEmpty);
    });

    test('outdoor Neapolitan with sugar burns', () {
      final w = ovenWarnings(neo.copyWith(sugarPct: 1), OvenSetup.outdoor);
      expect(w.single, contains('burns'));
      expect(ovenWarnings(neo, OvenSetup.outdoor), isEmpty);
    });

    test('Neapolitan on a tray: use New York instead', () {
      expect(
        ovenWarnings(neo, OvenSetup.homeTray).single,
        contains('New York'),
      );
      expect(ovenWarnings(ny, OvenSetup.homeTray), isEmpty);
    });

    test('Neapolitan under 260 °C: use New York instead', () {
      final cool = OvenSetup.homeSteel.copyWith(maxTempC: 250);
      expect(ovenWarnings(neo, cool).single, contains('260 °C'));
      expect(ovenWarnings(neo, cool).single, contains('New York'));
      expect(ovenWarnings(ny, cool), isEmpty);
      expect(
        ovenWarnings(neo, OvenSetup.homeSteel.copyWith(maxTempC: 260)),
        isEmpty,
      );
    });

    test('tray and cool oven give one New York warning, not two', () {
      final w = ovenWarnings(neo, OvenSetup.homeTray.copyWith(maxTempC: 250));
      expect(w, hasLength(1));
    });

    test('pan styles in an outdoor oven', () {
      for (final s in [
        PizzaStyle.detroit,
        PizzaStyle.roman,
        PizzaStyle.sicilian,
      ]) {
        final w = ovenWarnings(RecipeInputs(style: s), OvenSetup.outdoor);
        expect(w.single, contains('300–320 °C'), reason: '$s');
      }
      expect(ovenWarnings(ny, OvenSetup.outdoor), isEmpty);
      expect(
        ovenWarnings(
          const RecipeInputs(style: PizzaStyle.detroit),
          OvenSetup.homeSteel,
        ),
        isEmpty,
      );
    });
  });

  group('bakeCard', () {
    test('NY on steel matches the Recipe mockup', () {
      final b = bakeCard(PizzaStyle.newYork, OvenSetup.homeSteel);
      expect(b.title, 'Home oven · steel');
      expect(b.subtitle, 'Max 275 °C · 2nd rack from top');
      expect(b.steps, [
        'Preheat steel 45–60 min at max, fan off.',
        'Stretch on semolina and top lightly.',
        'Launch. Bake 5–7 min until the rim blisters.',
        'Switch to grill for the last 1–2 min. Watch the rim, not the clock.',
        'Rest 60 s on a rack before cutting.',
      ]);
    });

    test('NY on stone: middle rack, 7–9 min, grill on top rack', () {
      final b = bakeCard(PizzaStyle.newYork, OvenSetup.homeStone);
      expect(b.title, 'Home oven · stone');
      expect(b.subtitle, 'Max 275 °C · middle rack');
      expect(b.steps.first, contains('60 min'));
      expect(b.steps, contains('Launch. Bake 7–9 min until the rim blisters.'));
      expect(b.steps.join(' '), contains('top rack'));
    });

    test('NY on a tray: inverted tray, 9–12 min', () {
      final b = bakeCard(PizzaStyle.newYork, OvenSetup.homeTray);
      expect(b.steps.first, contains('upside-down tray'));
      expect(b.steps.join(' '), contains('9–12 min'));
    });

    test('thin on steel: 6–8 min until the base is crisp', () {
      final b = bakeCard(PizzaStyle.thin, OvenSetup.homeSteel);
      expect(
        b.steps,
        contains('Launch. Bake 6–8 min until the base is crisp.'),
      );
    });

    test('pan styles at home: lower-middle rack', () {
      final d = bakeCard(PizzaStyle.detroit, OvenSetup.homeSteel);
      expect(d.subtitle, 'Max 275 °C · lower-middle rack');
      expect(d.steps.join(' '), contains('12–16 min'));
      expect(
        bakeCard(PizzaStyle.sicilian, OvenSetup.homeTray).steps.join(' '),
        contains('12–16 min'),
      );
      expect(
        bakeCard(PizzaStyle.roman, OvenSetup.homeStone).steps.join(' '),
        contains('15–20 min'),
      );
    });

    test('outdoor round: 60–90 s, turn every 20–30 s', () {
      final b = bakeCard(PizzaStyle.neapolitan, OvenSetup.outdoor);
      expect(b.title, 'Outdoor oven');
      expect(b.subtitle, 'Max 450 °C · stone floor');
      expect(b.steps, contains('Launch. Bake 60–90 s, turning every 20–30 s.'));
    });

    test('outdoor pan: 300–320 °C, door open', () {
      final b = bakeCard(PizzaStyle.detroit, OvenSetup.outdoor);
      expect(b.subtitle, 'Max 450 °C · pan at 300–320 °C');
      expect(b.steps.join(' '), contains('door open'));
    });

    test('every style × oven has a short card without exclamation marks', () {
      for (final s in PizzaStyle.values) {
        for (final o in OvenSetup.presets) {
          final b = bakeCard(s, o);
          expect(b.steps.length, inInclusiveRange(4, 6), reason: '$s $o');
          expect(b.steps.join(), isNot(contains('!')));
        }
      }
    });
  });
}
