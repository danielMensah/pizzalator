import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pizzalator/core/bake_log.dart';
import 'package:pizzalator/core/oven.dart';
import 'package:pizzalator/services/json_store.dart';
import 'package:pizzalator/services/photos.dart';
import 'package:pizzalator/state/bake_log.dart';
import 'package:pizzalator/state/calibration.dart';
import 'package:pizzalator/state/oven.dart';
import 'package:pizzalator/state/recipe.dart';
import 'package:pizzalator/state/recipes.dart';

import '../fakes.dart';

void main() {
  late MemoryStore store;
  late ProviderContainer c;

  setUp(() {
    store = MemoryStore();
    c = ProviderContainer.test(
      overrides: [
        jsonStoreProvider.overrideWithValue(store),
        photoStoreProvider.overrideWithValue(FakePhotoStore()),
      ],
    );
  });

  HintDismissalsNotifier n() => c.read(hintDismissalsProvider.notifier);
  List<String> ids() => [
    for (final h in c.read(calibrationHintsProvider)) h.id,
  ];

  Future<void> logWet(String id) => c
      .read(bakeLogProvider.notifier)
      .add(
        BakeEntry(
          id: id,
          date: DateTime.utc(2026, 10, 17),
          name: 'Bake',
          inputs: c.read(recipeProvider),
          oven: c.read(ovenProvider),
          outcomes: const {Outcome.dough: 0},
        ),
      );

  test('hints for the working copy, labelled by style', () async {
    expect(ids(), isEmpty);
    await logWet('a');
    await logWet('b');
    final h = c.read(calibrationHintsProvider).single;
    expect(h.id, 'dough0:b');
    expect(h.title, 'Calibration hint · Neapolitan');
    c.read(recipeProvider.notifier).update(h.apply!);
    expect(ids(), isEmpty);
  });

  test('labelled by the saved recipe the working copy came from', () async {
    await c.read(savedRecipesProvider.notifier).saveAs('Friday NY');
    await logWet('a');
    await logWet('b');
    expect(
      c.read(calibrationHintsProvider).single.title,
      'Calibration hint · Friday NY',
    );
  });

  test('Not now hides it, saved; a newer bake raises it again', () async {
    await logWet('a');
    await logWet('b');
    await n().dismiss('dough0:b');
    expect(ids(), isEmpty);
    expect(store.data[hintsStoreName], ['dough0:b']);
    await logWet('c');
    expect(ids(), ['dough0:c']);
  });

  test('load: nothing saved, then saved ids back', () async {
    await n().load();
    expect(c.read(hintDismissalsProvider), isEmpty);
    expect(store.writes, 0);
    store.data[hintsStoreName] = ['x:1', 'y:2'];
    await n().load();
    expect(c.read(hintDismissalsProvider), {'x:1', 'y:2'});
    expect(store.bad, isEmpty);
  });

  test('load skips a bad id, sets the file aside, keeps the rest', () async {
    store.data[hintsStoreName] = ['x:1', 3, null];
    await n().load();
    expect(c.read(hintDismissalsProvider), {'x:1'});
    expect(store.bad[hintsStoreName], ['x:1', 3, null]);
    // Written back: the next launch still has it.
    expect(store.data[hintsStoreName], ['x:1']);
  });

  test('a file that is not a list loads nothing, set aside', () async {
    store.data[hintsStoreName] = {'x': 1};
    await n().load();
    expect(c.read(hintDismissalsProvider), isEmpty);
    expect(store.bad[hintsStoreName], {'x': 1});
  });

  test('hints read only the log; the oven hint edits the oven', () async {
    final log = c.read(bakeLogProvider.notifier);
    for (final id in ['a', 'b']) {
      await log.add(
        BakeEntry(
          id: id,
          date: DateTime.utc(2026, 10, 17),
          name: 'Bake',
          inputs: c.read(recipeProvider),
          oven: OvenSetup.homeSteel,
          outcomes: const {Outcome.bottom: 2},
        ),
      );
    }
    final h = c.read(calibrationHintsProvider).single;
    expect(c.read(ovenProvider).maxTempC, 275); // nothing silent
    c.read(ovenProvider.notifier).set(h.applyOven!(c.read(ovenProvider)));
    expect(c.read(ovenProvider).maxTempC, 250);
    expect(ids(), isEmpty);
  });
}
