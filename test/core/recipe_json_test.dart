import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pizzalator/core/calc.dart';
import 'package:pizzalator/core/oven.dart';
import 'package:pizzalator/core/recipe_json.dart';
import 'package:pizzalator/core/routine.dart';

/// Through text and back, as the store and the clipboard do.
Map<String, Object?> wire(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

/// Everything calc() shows, comparable.
List<Object?> shown(RecipeOutputs o) => [
  for (final l in [...o.preferment, ...o.finalDough])
    (l.kind, l.name, l.grams, l.pct, l.decimals),
  o.totalFlourG,
  o.totalDoughG,
  o.ballWeightG,
  o.ballCount,
  o.hydrationPct,
  o.proteinPct,
  o.yeastPct,
  o.warnings,
  o.notes,
];

const custom = Flour(
  'Marriage’s wholemeal',
  12.9,
  wholegrain: true,
  fibrePct: 9.2,
  note: 'scanned',
);

/// Every field off its default.
final edited = const RecipeInputs(style: PizzaStyle.roman)
    .copyWith(
      mode: EntryMode.pizzas,
      flourG: 750,
      pizzas: 3,
      diameterCm: 31.5,
      panWCm: 28,
      panLCm: 38.1,
      thickness: 1.15,
      flours: const [
        FlourShare(Flour.ukStrong, 60),
        FlourShare(custom, 25),
        FlourShare(Flour('Semolina rimacinata', 12.5), 15),
      ],
      plan: const [Stage(1.5, 22), Stage(30, 3), Stage(2, 22)],
      yeast: Yeast.fresh,
      preferment: Preferment.poolish.copyWith(flourShare: 40, hours: 10),
      yeastKnob: 1.15,
      hydrationSlope: 0.8,
      wholegrainAbsorption: 78,
    )
    .set(Pct.hydration, 78.5)
    .set(Pct.salt, 2.6)
    .set(Pct.residue, 8)
    .set(Pct.oil, 3.5, tip: true)
    .set(Pct.sugar, 1, tip: true);

void main() {
  test('clockId: base 36 of the clock, bumped past taken ids', () {
    final now = DateTime.fromMicrosecondsSinceEpoch(36 * 36);
    expect(clockId(now, (_) => false), '100');
    expect(clockId(now, {'100', '101'}.contains), '102');
  });

  group('inputs', () {
    final cases = {
      for (final s in PizzaStyle.values) s.label: RecipeInputs(style: s),
      'edited': edited,
      'sourdough': withYeast(edited, Yeast.sourdough),
      'biga, IDY': edited.copyWith(
        yeast: Yeast.idy,
        preferment: Preferment.biga,
      ),
    };
    for (final MapEntry(key: name, value: i) in cases.entries) {
      test('$name: same JSON and same formula after a round trip', () {
        final json = wire(inputsToJson(i));
        final back = inputsFromJson(json);
        expect(wire(inputsToJson(back)), json);
        expect(shown(calc(back)), shown(calc(i)));
      });
    }

    test('every field is kept', () {
      final back = inputsFromJson(wire(inputsToJson(edited)));
      expect(back.style, PizzaStyle.roman);
      expect(back.mode, EntryMode.pizzas);
      expect([back.flourG, back.pizzas], [750, 3]);
      expect([back.diameterCm, back.panWCm, back.panLCm], [31.5, 28, 38.1]);
      expect(back.thickness, 1.15);
      expect(
        [for (final f in back.flours) (f.flour, f.sharePct)],
        [
          (Flour.ukStrong, 60.0),
          (custom, 25.0),
          (const Flour('Semolina rimacinata', 12.5), 15.0),
        ],
      );
      expect(back.flours[1].flour.note, 'scanned');
      expect(back.plan, const [Stage(1.5, 22), Stage(30, 3), Stage(2, 22)]);
      expect(back.yeast, Yeast.fresh);
      final p = back.preferment;
      expect(
        [p.kind, p.flourShare, p.hydration, p.hours, p.tempC],
        [PrefermentKind.poolish, 40, 100, 10, 20],
      );
      expect([for (final p in Pct.values) p.of(back)], [78.5, 2.6, 3.5, 1, 8]);
      expect(back.fromTip, {Pct.oil, Pct.sugar});
      expect(
        [back.yeastKnob, back.hydrationSlope, back.wholegrainAbsorption],
        [1.15, 0.8, 78],
      );
    });

    test('defaults stay unset: style plan, no overrides', () {
      final back = inputsFromJson(
        wire(inputsToJson(const RecipeInputs(style: PizzaStyle.detroit))),
      );
      expect(back.plan, isNull);
      expect([for (final p in Pct.values) p.of(back)], everyElement(isNull));
      expect(back.fromTip, isEmpty);
    });

    test('tips are written in a fixed order, however they were set', () {
      final a = edited.copyWith(fromTip: {Pct.sugar, Pct.oil});
      final b = edited.copyWith(fromTip: {Pct.oil, Pct.sugar});
      expect(jsonEncode(inputsToJson(a)), jsonEncode(inputsToJson(b)));
    });

    test('a loaded sourdough plan still goes when sourdough does', () {
      const i = RecipeInputs(style: PizzaStyle.newYork);
      final back = inputsFromJson(
        wire(inputsToJson(withYeast(i, Yeast.sourdough))),
      );
      expect(withYeast(back, Yeast.idy).plan, isNull);
    });

    test('whole numbers in a hand-edited file read as doubles', () {
      final json = wire(inputsToJson(edited))
        ..['flourG'] = 800
        ..['thickness'] = 1;
      final back = inputsFromJson(json);
      expect(back.flourG, 800.0);
      expect(back.thickness, 1.0);
    });
  });

  test('oven round trip', () {
    for (final o in [
      ...OvenSetup.presets,
      OvenSetup.homeStone.copyWith(maxTempC: 250),
    ]) {
      final back = ovenFromJson(wire(ovenToJson(o)));
      expect(
        [back.kind, back.surface, back.maxTempC],
        [o.kind, o.surface, o.maxTempC],
      );
    }
  });

  group('saved recipe', () {
    final at = DateTime.utc(2026, 10, 17, 18, 30);
    final mine = SavedRecipe(
      id: 'abc',
      name: 'Friday NY',
      inputs: edited,
      oven: OvenSetup.homeStone,
      routine: RoutinePreset(name: 'Same-day NY', steps: defaultRoutine.steps),
      savedAt: at,
    );
    final plain = SavedRecipe(
      id: 'def',
      name: 'Plain',
      inputs: const RecipeInputs(style: PizzaStyle.neapolitan),
      oven: OvenSetup.homeSteel,
      savedAt: at,
    );

    test('round trip keeps id, name, oven, routine and time', () {
      final back = SavedRecipe.fromJson(wire(mine.toJson()));
      expect(back.toJson(), wire(mine.toJson()));
      expect(back.id, 'abc');
      expect(back.name, 'Friday NY');
      expect(back.oven.surface, Surface.stone);
      expect(back.routine!.name, 'Same-day NY');
      expect(back.routine!.steps, hasLength(defaultRoutine.steps.length));
      expect(back.savedAt, at);
    });

    test('no routine means the built-in one', () {
      expect(SavedRecipe.fromJson(wire(plain.toJson())).routine, isNull);
    });

    test('copyWith: new id, name or time; the rest stays', () {
      final later = DateTime.utc(2026, 10, 18);
      final copy = mine.copyWith(id: 'x', name: 'Copy', savedAt: later);
      expect([copy.id, copy.name, copy.savedAt], ['x', 'Copy', later]);
      expect(copy.inputs, same(mine.inputs));
      expect(copy.routine, same(mine.routine));
      expect(mine.copyWith().toJson(), mine.toJson());
    });

    test('export: the envelope, pretty-printed; import reads it back', () {
      final text = exportRecipes([mine, plain]);
      final json = jsonDecode(text) as Map<String, Object?>;
      expect(json['format'], 'pizzalator.recipes');
      expect(json['version'], 1);
      expect(json['recipes'], [wire(mine.toJson()), wire(plain.toJson())]);
      expect(text, contains('\n  "format"'));
      final back = importRecipes(text);
      expect(
        [for (final r in back) r.toJson()],
        [wire(mine.toJson()), wire(plain.toJson())],
      );
      expect(exportRecipes(back), text);
    });

    test('import skips bad recipes, keeps the rest', () {
      final json = jsonDecode(exportRecipes([mine, plain])) as Map;
      final list = json['recipes'] as List;
      list
        ..insert(1, {'id': 'bad', 'name': 3})
        ..add('junk')
        ..add(wire(plain.toJson())..['savedAt'] = 'not a date')
        ..add(wire(plain.toJson())..['inputs'] = {'style': 'pizza'})
        // Shape-valid but calc() cannot compute it (hand-edited backup).
        ..add(
          wire(
            plain.toJson(),
          )..['inputs'] = {...inputsToJson(plain.inputs), 'flours': <Object>[]},
        )
        ..add(
          wire(plain.toJson())
            ..['inputs'] = {...inputsToJson(plain.inputs), 'diameterCm': 0},
        )
        // A routine the routines file would refuse: no steps to time.
        ..add(
          wire(plain.toJson())
            ..['routine'] = {'name': 'Empty', 'steps': <Object>[]},
        );
      final back = importRecipes(jsonEncode(json));
      expect([for (final r in back) r.id], ['abc', 'def']);
    });

    test('inputsFromJson refuses inputs calc() cannot compute', () {
      final base = inputsToJson(edited);
      final share = (base['flours']! as List).first;
      for (final bad in <String, Object?>{
        'flours': <Object>[],
        'flourG': 0,
        'pizzas': 0,
        'diameterCm': 0,
        'panWCm': -1,
        'panLCm': 0,
        'thickness': 0,
      }.entries) {
        expect(
          () => inputsFromJson({...base, bad.key: bad.value}),
          throwsA(isA<Error>()),
          reason: bad.key,
        );
      }
      expect(
        () => inputsFromJson({
          ...base,
          'flours': List.filled(kMaxFlours + 1, share),
        }),
        throwsA(isA<Error>()),
      );
    });

    test('import throws FormatException on anything but an export', () {
      for (final text in [
        'Neapolitan · 7 × 30 cm',
        '[]',
        '{"recipes": []}',
        '{"format": "other", "version": 1, "recipes": []}',
        '{"format": "pizzalator.recipes", "version": 2, "recipes": []}',
        '{"format": "pizzalator.recipes", "version": 1, "recipes": {}}',
      ]) {
        expect(() => importRecipes(text), throwsFormatException, reason: text);
      }
    });

    test('parseRecipe: null for anything that is not a recipe', () {
      expect(parseRecipe(wire(mine.toJson()))!.id, 'abc');
      expect(parseRecipe(null), isNull);
      expect(parseRecipe('junk'), isNull);
      expect(parseRecipe({'id': 1}), isNull);
    });
  });
}
