import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pizzalator/core/calc.dart';
import 'package:pizzalator/core/oven.dart';
import 'package:pizzalator/core/recipe_json.dart';
import 'package:pizzalator/core/routine.dart';
import 'package:pizzalator/services/json_store.dart';
import 'package:pizzalator/state/oven.dart';
import 'package:pizzalator/state/recipe.dart';
import 'package:pizzalator/state/recipes.dart';
import 'package:pizzalator/state/routine.dart';
import 'package:pizzalator/state/timer_run.dart';

import '../fakes.dart';

void main() {
  late MemoryStore store;
  late ProviderContainer c;
  // One instant for every save: ids must still differ.
  final now = DateTime.utc(2026, 10, 24, 9);

  ProviderContainer container() => ProviderContainer.test(
    overrides: [
      jsonStoreProvider.overrideWithValue(store),
      clockProvider.overrideWithValue(() => now),
    ],
  );

  setUp(() {
    store = MemoryStore();
    c = container();
  });

  List<SavedRecipe> saved() => c.read(savedRecipesProvider);
  SavedRecipesNotifier n() => c.read(savedRecipesProvider.notifier);
  List<String> names() => [for (final r in saved()) r.name];
  SavedRecipe? active() => c.read(activeRecipeProvider);
  bool dirty() => c.read(recipeDirtyProvider);
  void edit(RecipeInputs Function(RecipeInputs) change) =>
      c.read(recipeProvider.notifier).update(change);
  List<Object?> stored() => store.data[recipesStoreName]! as List<Object?>;

  test('starts empty: nothing active, nothing edited', () {
    expect(saved(), isEmpty);
    expect(active(), isNull);
    expect(dirty(), isFalse);
  });

  test('saveAs puts the working copy on top and makes it active', () async {
    c.read(recipeProvider.notifier).setStyle(PizzaStyle.newYork);
    c.read(ovenProvider.notifier).set(OvenSetup.homeStone);
    await n().saveAs('  Friday NY ');
    edit((i) => i.copyWith(flourG: 600));
    await n().saveAs('');
    expect(names(), ['New York', 'Friday NY']);
    expect(active()!.name, 'New York');
    expect(saved()[1].inputs.style, PizzaStyle.newYork);
    expect(saved()[1].inputs.flourG, 1000);
    expect(saved()[0].inputs.flourG, 600);
    expect(saved()[1].oven.surface, Surface.stone);
    expect(saved()[1].savedAt, now);
    // The built-in routine is not stored with it.
    expect(saved()[1].routine, isNull);
    expect(saved()[0].id, isNot(saved()[1].id));
    expect(dirty(), isFalse);
    expect(
      [for (final r in stored()) (r! as Map)['name']],
      ['New York', 'Friday NY'],
    );
  });

  test('a user routine is saved with the recipe', () async {
    await c.read(routineProvider.notifier).saveAsPreset('Same-day NY');
    await n().saveAs('Friday NY');
    expect(active()!.routine!.name, 'Same-day NY');
  });

  test('dirty: inputs, oven or routine differ from the active one', () async {
    await n().saveAs('Friday NY');
    edit((i) => i.set(Pct.hydration, 64));
    expect(dirty(), isTrue);
    edit((i) => i.clear({Pct.hydration}));
    expect(dirty(), isFalse);
    c.read(ovenProvider.notifier).setMaxTemp(250);
    expect(dirty(), isTrue);
    c.read(ovenProvider.notifier).setMaxTemp(275);
    expect(dirty(), isFalse);
    await c.read(routineProvider.notifier).setMinutes(0, 9);
    expect(dirty(), isTrue);
  });

  test('saveChanges writes over the active recipe, in place', () async {
    await n().saveAs('A');
    await n().saveAs('B');
    await n().open(saved()[1]);
    edit((i) => i.copyWith(flourG: 1500));
    await n().saveChanges();
    expect(names(), ['B', 'A']);
    expect(saved()[1].inputs.flourG, 1500);
    expect(saved()[1].id, active()!.id);
    expect(dirty(), isFalse);
    expect(((stored()[1]! as Map)['inputs'] as Map)['flourG'], 1500);
  });

  test('saveChanges with nothing active does nothing', () async {
    await n().saveChanges();
    expect(saved(), isEmpty);
    expect(store.writes, 0);
  });

  test('open loads inputs, oven and routine; it is active, clean', () async {
    c.read(recipeProvider.notifier).setStyle(PizzaStyle.detroit);
    c.read(ovenProvider.notifier).set(OvenSetup.outdoor);
    await c.read(routineProvider.notifier).saveAsPreset('Pan day');
    await n().saveAs('Detroit');
    final detroit = saved().single;

    c.read(recipeProvider.notifier).setStyle(PizzaStyle.thin);
    c.read(ovenProvider.notifier).set(OvenSetup.homeSteel);
    await c.read(routineProvider.notifier).select(0);
    c.read(activeRecipeIdProvider.notifier).set(null);

    await n().open(detroit);
    expect(c.read(recipeProvider).style, PizzaStyle.detroit);
    expect(c.read(ovenProvider).kind, OvenKind.outdoor);
    expect(c.read(routineProvider).current.name, 'Pan day');
    expect(active()!.name, 'Detroit');
    expect(dirty(), isFalse);
  });

  test('duplicate: a copy under the original, new id, not active', () async {
    await n().saveAs('A');
    await n().saveAs('B');
    await n().duplicate(1);
    expect(names(), ['B', 'A', 'A copy']);
    expect(saved()[2].id, isNot(saved()[1].id));
    expect(active()!.name, 'B');
    expect(stored(), hasLength(3));
  });

  test('rename trims; a blank name keeps the old one', () async {
    await n().saveAs('A');
    await n().rename(0, '  Friday NY ');
    expect(names(), ['Friday NY']);
    await n().rename(0, ' ');
    expect(names(), ['Friday NY']);
    expect(active()!.name, 'Friday NY');
    expect((stored().single! as Map)['name'], 'Friday NY');
  });

  test('delete; deleting the active one clears it', () async {
    await n().saveAs('A');
    await n().saveAs('B');
    await n().delete(1);
    expect(names(), ['B']);
    expect(active()!.name, 'B');
    await n().delete(0);
    expect(saved(), isEmpty);
    expect(active(), isNull);
    expect(c.read(activeRecipeIdProvider), isNull);
    expect(stored(), isEmpty);
  });

  test('export and import: on top, new ids where they collide', () async {
    await n().saveAs('A');
    await n().saveAs('B');
    final text = n().exportJson();
    expect(text, exportRecipes(saved()));
    final before = {for (final r in saved()) r.id};

    expect(await n().importJson(text), 2);
    expect(names(), ['B', 'A', 'B', 'A']);
    final ids = {for (final r in saved()) r.id};
    expect(ids, hasLength(4));
    expect(ids.containsAll(before), isTrue);
    expect(stored(), hasLength(4));

    // Ids not here yet are kept.
    final other = jsonDecode(text) as Map<String, Object?>;
    ((other['recipes']! as List).first as Map)['id'] = 'from-tablet';
    expect(await n().importJson(jsonEncode(other)), 2);
    expect(saved().first.id, 'from-tablet');
  });

  test('import of an export with no readable recipes writes nothing', () async {
    expect(await n().importJson(exportRecipes(const [])), 0);
    expect(store.writes, 0);
  });

  test('import of something else throws FormatException', () async {
    await expectLater(n().importJson('hello'), throwsFormatException);
    expect(saved(), isEmpty);
  });

  group('load', () {
    test('nothing saved: stays empty', () async {
      await n().load();
      expect(saved(), isEmpty);
      expect(store.bad, isEmpty);
    });

    test('brings saved recipes back, in order', () async {
      await n().saveAs('A');
      await n().saveAs('B');
      c = container();
      await n().load();
      expect(names(), ['B', 'A']);
      expect(store.bad, isEmpty);
    });

    test('skips a bad recipe, sets the file aside, writes the rest', () async {
      await n().saveAs('A');
      store.data[recipesStoreName] = [
        ...stored(),
        {'id': 3},
        'junk',
      ];
      c = container();
      await n().load();
      expect(names(), ['A']);
      expect(store.bad[recipesStoreName], hasLength(3));
      c = container();
      await n().load();
      expect(names(), ['A']);
    });

    test('a file that is not a list loads nothing, set aside', () async {
      store.data[recipesStoreName] = {'recipes': <Object?>[]};
      await n().load();
      expect(saved(), isEmpty);
      expect(store.bad, contains(recipesStoreName));
    });
  });

  group('current (last-used recipe, PRD §5)', () {
    test('saveCurrent then restoreCurrent: inputs, oven, active', () async {
      await n().saveAs('Friday NY');
      c.read(recipeProvider.notifier).setStyle(PizzaStyle.roman);
      c.read(ovenProvider.notifier).set(OvenSetup.homeTray);
      await n().saveCurrent();
      final id = active()!.id;

      c = container();
      await n().load();
      await n().restoreCurrent();
      expect(c.read(recipeProvider).style, PizzaStyle.roman);
      expect(c.read(ovenProvider).surface, Surface.none);
      expect(c.read(activeRecipeIdProvider), id);
      expect(active()!.name, 'Friday NY');
      expect(dirty(), isTrue);
    });

    test('nothing saved: first-launch defaults', () async {
      await n().restoreCurrent();
      expect(c.read(recipeProvider).style, PizzaStyle.neapolitan);
      expect(store.bad, isEmpty);
    });

    test('a bad file: defaults, and the file is set aside', () async {
      store.data[currentStoreName] = {
        'inputs': inputsToJson(const RecipeInputs(style: PizzaStyle.detroit)),
        'oven': {'kind': 'microwave'},
      };
      await n().restoreCurrent();
      expect(c.read(recipeProvider).style, PizzaStyle.neapolitan);
      expect(c.read(ovenProvider).surface, Surface.steel);
      expect(store.bad, contains(currentStoreName));
    });

    test('inputs calc() cannot compute: defaults, file set aside', () async {
      store.data[currentStoreName] = {
        'inputs': {
          ...inputsToJson(const RecipeInputs(style: PizzaStyle.detroit)),
          'flours': <Object>[],
        },
        'oven': ovenToJson(OvenSetup.homeTray),
      };
      await n().restoreCurrent();
      expect(c.read(recipeProvider).style, PizzaStyle.neapolitan);
      expect(store.bad, contains(currentStoreName));
    });
  });

  test('the built-in routine left as is is not part of a recipe', () {
    expect(routineToSave(c.read(routineProvider)), isNull);
  });

  test('a recipe saved on another phone opens its routine here', () async {
    final r = SavedRecipe(
      id: 'x',
      name: 'X',
      inputs: const RecipeInputs(style: PizzaStyle.neapolitan),
      oven: OvenSetup.homeSteel,
      routine: RoutinePreset(name: 'Theirs', steps: defaultRoutine.steps),
      savedAt: now,
    );
    await n().importJson(exportRecipes([r]));
    await n().open(saved().single);
    expect(c.read(routineProvider).current.name, 'Theirs');
    expect(dirty(), isFalse);
  });
}
