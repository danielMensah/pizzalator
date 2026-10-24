import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pizzalator/core/bake_log.dart';
import 'package:pizzalator/core/calc.dart';
import 'package:pizzalator/core/oven.dart';
import 'package:pizzalator/services/json_store.dart';
import 'package:pizzalator/services/photos.dart';
import 'package:pizzalator/state/bake_log.dart';
import 'package:pizzalator/state/oven.dart';
import 'package:pizzalator/state/recipe.dart';
import 'package:pizzalator/state/recipes.dart';
import 'package:pizzalator/state/timer_run.dart';

import '../fakes.dart';

void main() {
  late MemoryStore store;
  late FakePhotoStore photos;
  late ProviderContainer c;
  // One instant for every draft: ids must still differ.
  final now = DateTime.utc(2026, 10, 24, 19);

  ProviderContainer container() => ProviderContainer.test(
    overrides: [
      jsonStoreProvider.overrideWithValue(store),
      photoStoreProvider.overrideWithValue(photos),
      clockProvider.overrideWithValue(() => now),
    ],
  );

  setUp(() {
    store = MemoryStore();
    photos = FakePhotoStore();
    c = container();
  });

  List<BakeEntry> log() => c.read(bakeLogProvider);
  BakeLogNotifier n() => c.read(bakeLogProvider.notifier);
  List<String> names() => [for (final e in log()) e.name];

  BakeEntry entry(String id, {String name = 'Bake', String? photo}) =>
      BakeEntry(
        id: id,
        date: now,
        name: name,
        inputs: const RecipeInputs(style: PizzaStyle.newYork),
        oven: OvenSetup.homeSteel,
        photo: photo,
      );

  test('draft: the working copy, its plan and oven, named by style', () {
    c.read(recipeProvider.notifier).setStyle(PizzaStyle.newYork);
    c.read(recipeProvider.notifier).setRoomC(22);
    c.read(ovenProvider.notifier).setMaxTemp(250);
    final d = n().draft();
    expect(d.name, 'New York');
    expect(d.recipeId, isNull);
    expect(d.date, now);
    expect(d.inputs, same(c.read(recipeProvider)));
    expect(d.oven.maxTempC, 250);
    expect(d.roomC, 22);
    expect(d.fridgeH, StagePlan.of(d.inputs.activePlan).fridgeH);
    expect(d.ovenC, 250);
    expect(d.bakeMin, isNull);
    expect(d.rating, 0);
  });

  test('draft: named after the active recipe, linked to it', () async {
    await c.read(savedRecipesProvider.notifier).saveAs('Friday NY');
    final d = n().draft();
    expect(d.name, 'Friday NY');
    expect(d.recipeId, c.read(activeRecipeProvider)!.id);
  });

  test('draft ids differ from every logged one, same clock', () async {
    final a = n().draft();
    await n().add(a);
    expect(n().draft().id, isNot(a.id));
  });

  test('add puts new bakes first; update in place; all persist', () async {
    await n().add(entry('a', name: 'A'));
    await n().add(entry('b', name: 'B'));
    expect(names(), ['B', 'A']);
    await n().update(entry('a', name: 'A2'));
    expect(names(), ['B', 'A2']);
    expect(
      [for (final e in store.data[bakesStoreName]! as List) (e as Map)['name']],
      ['B', 'A2'],
    );
  });

  test('update with a new photo deletes the old one', () async {
    await n().add(entry('a', photo: 'old.jpg'));
    await n().update(entry('a', photo: 'old.jpg'));
    expect(photos.deleted, isEmpty);
    await n().update(entry('a', photo: 'new.jpg'));
    expect(photos.deleted, ['old.jpg']);
  });

  test('delete removes the bake and its photo', () async {
    await n().add(entry('a', photo: 'a.jpg'));
    await n().add(entry('b'));
    await n().delete('a');
    expect(names(), ['Bake']);
    expect(log().single.id, 'b');
    expect(photos.deleted, ['a.jpg']);
    await n().delete('b');
    expect(log(), isEmpty);
    expect(photos.deleted, ['a.jpg']);
    expect(store.data[bakesStoreName], isEmpty);
  });

  test('a failed write keeps the photo the file still points at', () async {
    await n().add(entry('a', photo: 'old.jpg'));
    store.failWrites = const FileSystemException('full');
    await expectLater(
      n().update(entry('a', photo: 'new.jpg')),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(n().delete('a'), throwsA(isA<FileSystemException>()));
    expect(photos.deleted, isEmpty);
  });

  test('load: nothing saved stays empty', () async {
    await n().load();
    expect(log(), isEmpty);
    expect(store.bad, isEmpty);
  });

  test('load brings bakes back, in order', () async {
    await n().add(entry('a', name: 'A'));
    await n().add(entry('b', name: 'B'));
    c = container();
    await n().load();
    expect(names(), ['B', 'A']);
    expect(store.bad, isEmpty);
  });

  test('load skips a bad entry, sets the file aside, keeps the rest', () async {
    store.data[bakesStoreName] = [
      entry('a', name: 'A').toJson(),
      {'id': 3},
      'junk',
    ];
    await n().load();
    expect(names(), ['A']);
    expect(store.bad[bakesStoreName], hasLength(3));
    c = container();
    await n().load();
    expect(names(), ['A']);
  });

  test('a file that is not a list loads nothing, set aside', () async {
    store.data[bakesStoreName] = {'bakes': <Object?>[]};
    await n().load();
    expect(log(), isEmpty);
    expect(store.bad, contains(bakesStoreName));
  });
}
