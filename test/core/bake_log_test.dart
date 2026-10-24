import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pizzalator/core/bake_log.dart';
import 'package:pizzalator/core/calc.dart';
import 'package:pizzalator/core/oven.dart';
import 'package:pizzalator/core/recipe_json.dart';

/// Through text and back, as the store does.
Map<String, Object?> wire(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

final friday = BakeEntry(
  id: 'b1',
  date: DateTime.utc(2026, 10, 17, 19),
  name: 'Friday NY',
  recipeId: 'r1',
  inputs: const RecipeInputs(
    style: PizzaStyle.newYork,
  ).set(Pct.hydration, 63.5),
  oven: OvenSetup.homeSteel,
  rating: 3,
  outcomes: const {Outcome.dough: 0, Outcome.crumb: 2},
  roomC: 22,
  fridgeH: 46.5,
  ovenC: 275,
  bakeMin: 6,
  photo: 'abc.jpg',
  notes: 'Rim blistered well.',
);

void main() {
  test('outcomes: mockup names and options, middle by default', () {
    expect(
      [for (final o in Outcome.values) o.label],
      ['Dough felt', 'Proof', 'Crust colour', 'Crumb', 'Bottom'],
    );
    expect(Outcome.proof.options, ['under', 'right', 'over']);
    expect(Outcome.bottom.tags, [
      'bottom soggy',
      'bottom right',
      'bottom burnt',
    ]);
    expect(friday.choice(Outcome.proof), 1);
    expect(friday.choice(Outcome.dough), 0);
  });

  test('good: the middle option, and an open crumb', () {
    for (final o in Outcome.values) {
      expect(o.good(1), isTrue, reason: o.name);
      expect(o.good(0), isFalse, reason: o.name);
    }
    expect(Outcome.crumb.good(2), isTrue);
    expect(Outcome.crust.good(2), isFalse);
  });

  test('tags: bad first, then a notable good, then right; three at most', () {
    expect(friday.tags, [
      ('too wet', false),
      ('open crumb', true),
      ('proof right', true),
    ]);
    final allBad = BakeEntry(
      id: 'x',
      date: friday.date,
      name: 'x',
      inputs: friday.inputs,
      oven: friday.oven,
      outcomes: {for (final o in Outcome.values) o: 0},
    );
    expect(allBad.tags, [
      ('too wet', false),
      ('under-proofed', false),
      ('pale', false),
    ]);
  });

  test('json round trip keeps every field', () {
    final back = BakeEntry.fromJson(wire(friday.toJson()));
    expect(back.toJson(), friday.toJson());
    expect(back.date, friday.date);
    expect(back.inputs.style, PizzaStyle.newYork);
    expect(calc(back.inputs).hydrationPct, 63.5);
    expect(back.oven.surface, Surface.steel);
    expect(back.outcomes[Outcome.crumb], 2);
    expect(
      [back.roomC, back.fridgeH, back.ovenC, back.bakeMin],
      [22, 46.5, 275, 6],
    );
    expect(
      [back.photo, back.notes, back.recipeId],
      ['abc.jpg', 'Rim blistered well.', 'r1'],
    );
  });

  test('the blank fields stay blank', () {
    final bare = BakeEntry(
      id: 'b2',
      date: DateTime.utc(2026, 10, 24),
      name: 'Neapolitan',
      inputs: const RecipeInputs(style: PizzaStyle.neapolitan),
      oven: OvenSetup.outdoor,
    );
    final back = BakeEntry.fromJson(wire(bare.toJson()));
    expect(back.rating, 0);
    expect(back.recipeId, isNull);
    expect(back.photo, isNull);
    expect(back.bakeMin, isNull);
    expect(back.notes, '');
    expect(back.choice(Outcome.bottom), 1);
  });

  test('parseBake: null for what this build cannot read', () {
    Map<String, Object?> with_(String key, Object? value) =>
        wire(friday.toJson())..[key] = value;
    expect(parseBake(friday.toJson()), isNotNull);
    expect(parseBake('junk'), isNull);
    expect(parseBake(with_('rating', 6)), isNull);
    expect(parseBake(with_('outcomes', {'dough': 3})), isNull);
    expect(parseBake(with_('outcomes', {'smell': 1})), isNull);
    expect(parseBake(with_('date', 'not a date')), isNull);
    expect(
      parseBake(with_('inputs', inputsToJson(friday.inputs)..['pizzas'] = 0)),
      isNull,
    );
  });
}
