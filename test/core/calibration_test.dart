import 'package:flutter_test/flutter_test.dart';
import 'package:pizzalator/core/bake_log.dart';
import 'package:pizzalator/core/calc.dart';
import 'package:pizzalator/core/calibration.dart';
import 'package:pizzalator/core/oven.dart';

const ny = RecipeInputs(style: PizzaStyle.newYork);
const wholemeal = Flour('Wholemeal', 13, wholegrain: true);

var _n = 0;

/// A bake of [inputs] in [oven], [outcomes] as logged.
BakeEntry bake(
  Map<Outcome, int> outcomes, {
  RecipeInputs inputs = ny,
  OvenSetup oven = OvenSetup.homeSteel,
}) => BakeEntry(
  id: 'b${_n++}',
  date: DateTime.utc(2026, 10, 17),
  name: 'Friday NY',
  inputs: inputs,
  oven: oven,
  outcomes: outcomes,
);

const wet = {Outcome.dough: 0};
const dry = {Outcome.dough: 2};
const under = {Outcome.proof: 0};
const over = {Outcome.proof: 2};
const pale = {Outcome.crust: 0};
const burntBottom = {Outcome.bottom: 2};

List<CalibrationHint> hints(
  List<BakeEntry> log, {
  RecipeInputs inputs = ny,
  OvenSetup oven = OvenSetup.homeSteel,
}) => calibrationHints(log, inputs, oven, name: 'Friday NY');

void main() {
  final hyd = r01(Pct.hydration.value(ny));

  test('nothing logged, nothing said', () {
    expect(hints(const []), isEmpty);
  });

  group('hydration', () {
    final cases = [
      ('too wet', wet, -kHintHydrationStepPp, 'Apply −2 pp'),
      ('too dry', dry, kHintHydrationStepPp, 'Apply +2 pp'),
    ];
    for (final (tag, outcome, step, label) in cases) {
      test('two "$tag" at the current hydration: $label', () {
        final log = [bake(outcome), bake(outcome)];
        final h = hints(log).single;
        final to = r01(hyd + step);
        expect(h.id, 'dough${outcome[Outcome.dough]}:${log.first.id}');
        expect(h.title, 'Calibration hint · Friday NY');
        expect(
          h.text,
          'Two bakes logged "$tag" with UK strong white. Suggest hydration '
          '${pctText(hyd)}% → ${pctText(to)}% on this recipe.',
        );
        expect(h.applyLabel, label);
        expect(h.done, 'Hydration now ${pctText(to)}%');
        expect(h.applyOven, isNull);
        final applied = h.apply!(ny);
        expect(Pct.hydration.value(applied), to);
        // Set by the user's tap, so a style switch keeps it.
        expect(applied.fromTip, isEmpty);
        // At the new value nothing was logged yet: the hint goes.
        expect(hints(log, inputs: applied), isEmpty);
      });
    }

    test('one log is not enough; the two newest must agree', () {
      expect(hints([bake(wet)]), isEmpty);
      expect(hints([bake(wet), bake(const {}), bake(wet)]), isEmpty);
      expect(hints([bake(wet), bake(dry)]), isEmpty);
    });

    test('only bakes at the current hydration count', () {
      final other = ny.set(Pct.hydration, hyd + 3);
      // The newest at 63 + 3 % is ignored; the two at the current value agree.
      expect(
        hints([bake(dry, inputs: other), bake(wet), bake(wet)]),
        hasLength(1),
      );
      // Two wet at another hydration say nothing about this one.
      expect(
        hints([bake(wet, inputs: other), bake(wet, inputs: other)]),
        isEmpty,
      );
      // ...until the recipe is back at it.
      expect(
        hints([
          bake(wet, inputs: other),
          bake(wet, inputs: other),
        ], inputs: other),
        hasLength(1),
      );
    });

    test('converges: two more wet bakes at the new value step again', () {
      final log = [bake(wet), bake(wet)];
      final once = hints(log).single.apply!(ny);
      final log2 = [bake(wet, inputs: once), bake(wet, inputs: once), ...log];
      final twice = hints(log2, inputs: once).single.apply!(once);
      expect(Pct.hydration.value(twice), r01(hyd - 2 * kHintHydrationStepPp));
      expect(hints(log2, inputs: twice), isEmpty);
    });

    test('a different flour mix or style is not counted', () {
      const blend = [FlourShare(Flour.ukStrong, 80), FlourShare(wholemeal, 20)];
      final mixed = ny.copyWith(flours: blend);
      final reshared = ny.copyWith(
        flours: const [
          FlourShare(Flour.ukStrong, 70),
          FlourShare(wholemeal, 30),
        ],
      );
      const detroit = RecipeInputs(style: PizzaStyle.detroit);
      expect(hints([bake(wet, inputs: mixed), bake(wet)]), isEmpty);
      expect(hints([bake(wet, inputs: detroit), bake(wet)]), isEmpty);
      expect(
        hints([
          bake(wet, inputs: reshared),
          bake(wet, inputs: mixed),
        ], inputs: mixed),
        isEmpty,
      );
      // The same mix in another order is the same mix; a blend's text
      // names every flour.
      final reordered = ny.copyWith(flours: blend.reversed.toList());
      final h = hints([
        bake(wet, inputs: reordered),
        bake(wet, inputs: mixed),
      ], inputs: mixed).single;
      expect(h.text, contains('with UK strong white + Wholemeal'));
    });
  });

  group('proof', () {
    final cases = [
      ('under-proofed', under, 1.0, 1.15, 'Apply +15%'),
      ('over-proofed', over, 1.0, 0.85, 'Apply −15%'),
      ('under-proofed near the top', under, 1.9, 2.0, 'Apply +15%'),
      ('over-proofed near the bottom', over, 0.6, 0.5, 'Apply −15%'),
    ];
    for (final (tag, outcome, knob, to, label) in cases) {
      test('$tag at knob $knob → $to', () {
        final at = ny.copyWith(yeastKnob: knob);
        final log = [bake(outcome, inputs: at), bake(outcome, inputs: at)];
        final h = hints(log, inputs: at).single;
        expect(h.id, 'proof${outcome[Outcome.proof]}:${log.first.id}');
        expect(h.applyLabel, label);
        expect(
          h.text,
          'Two bakes logged "${tag.split(' ').first}" at yeast knob '
          '${(knob * 100).round()}%. Suggest '
          '${(to * 100).round()}% on this recipe.',
        );
        expect(h.done, 'Yeast knob now ${(to * 100).round()}%');
        final applied = h.apply!(at);
        expect(applied.yeastKnob, to);
        expect(hints(log, inputs: applied), isEmpty);
      });
    }

    test('clamped at the knob range: no hint that changes nothing', () {
      final top = ny.copyWith(yeastKnob: kYeastKnobMax);
      final bottom = ny.copyWith(yeastKnob: kYeastKnobMin);
      expect(
        hints([
          bake(under, inputs: top),
          bake(under, inputs: top),
        ], inputs: top),
        isEmpty,
      );
      expect(
        hints([
          bake(over, inputs: bottom),
          bake(over, inputs: bottom),
        ], inputs: bottom),
        isEmpty,
      );
    });

    test('only bakes at the current knob count', () {
      final faster = ny.copyWith(yeastKnob: 1.15);
      expect(hints([bake(under), bake(under)], inputs: faster), isEmpty);
    });

    test('sourdough: the knob moves no yeast, so no proof hint', () {
      final sour = ny.copyWith(yeast: Yeast.sourdough);
      expect(
        hints([
          bake(under, inputs: sour),
          bake(under, inputs: sour),
        ], inputs: sour),
        isEmpty,
      );
    });
  });

  group('pale crust', () {
    test('home oven: sugar +1 on the current sugar %', () {
      final log = [bake(pale), bake(pale)];
      final h = hints(log).single;
      final sugar = PizzaStyle.newYork.sugar;
      expect(h.id, 'crust0:${log.first.id}');
      expect(h.applyLabel, 'Apply +1% sugar');
      expect(
        h.text,
        'Two bakes came out pale in a home oven. Suggest sugar '
        '${pctText(sugar)}% → ${pctText(sugar + 1)}% on this recipe.',
      );
      final applied = h.apply!(ny);
      expect(Pct.sugar.value(applied), sugar + kHintSugarStepPct);
      expect(hints(log, inputs: applied), isEmpty);
    });

    test('Roman: malt +0.5', () {
      const roman = RecipeInputs(style: PizzaStyle.roman);
      final h = hints([
        bake(pale, inputs: roman),
        bake(pale, inputs: roman),
      ], inputs: roman).single;
      expect(h.applyLabel, 'Apply +0.5% malt');
      expect(h.text, contains('malt 0.5% → 1%'));
      expect(Pct.sugar.value(h.apply!(roman)), 1);
    });

    test('outdoor: not a sugar problem', () {
      const out = OvenSetup.outdoor;
      expect(
        hints([bake(pale, oven: out), bake(pale, oven: out)], oven: out),
        isEmpty,
      );
      // Bakes outdoors do not count for the home oven either.
      expect(hints([bake(pale, oven: out), bake(pale, oven: out)]), isEmpty);
    });
  });

  group('burnt bottom', () {
    test('steel: max temp −25 °C via applyOven', () {
      final log = [bake(burntBottom), bake(burntBottom)];
      final h = hints(log).single;
      expect(h.id, 'bottom2:${log.first.id}');
      expect(h.apply, isNull);
      expect(h.applyLabel, 'Apply −25 °C');
      expect(
        h.text,
        'Two bakes logged "bottom burnt" on the steel. Raise it a rack or '
        'bake cooler: max 275 °C → 250 °C.',
      );
      expect(h.done, 'Max temp now 250 °C');
      final cooler = h.applyOven!(OvenSetup.homeSteel);
      expect(cooler.maxTempC, 250);
      expect(cooler.surface, Surface.steel);
      expect(hints(log, oven: cooler), isEmpty);
    });

    test('clamped to the home range; none at the bottom of it', () {
      const low = OvenSetup(
        kind: OvenKind.home,
        surface: Surface.steel,
        maxTempC: 210,
      );
      final near = hints([
        bake(burntBottom, oven: low),
        bake(burntBottom, oven: low),
      ], oven: low).single;
      expect(near.applyOven!(low).maxTempC, 200);
      final floor = low.copyWith(maxTempC: 200);
      expect(
        hints([
          bake(burntBottom, oven: floor),
          bake(burntBottom, oven: floor),
        ], oven: floor),
        isEmpty,
      );
    });

    test('stone, or bakes on another surface: not counted', () {
      const stone = OvenSetup.homeStone;
      expect(
        hints([
          bake(burntBottom, oven: stone),
          bake(burntBottom, oven: stone),
        ], oven: stone),
        isEmpty,
      );
      expect(
        hints([bake(burntBottom, oven: stone), bake(burntBottom, oven: stone)]),
        isEmpty,
      );
    });
  });

  test('every rule at once, in a fixed order', () {
    const all = {
      Outcome.dough: 0,
      Outcome.proof: 0,
      Outcome.crust: 0,
      Outcome.bottom: 2,
    };
    expect(
      [
        for (final h in hints([bake(all), bake(all)])) h.id.split(':').first,
      ],
      ['dough0', 'proof0', 'crust0', 'bottom2'],
    );
  });
}
