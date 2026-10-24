import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pizzalator/core/calc.dart';
import 'package:pizzalator/services/json_store.dart';
import 'package:pizzalator/state/flours.dart';
import 'package:pizzalator/state/recipe.dart';

import '../fakes.dart';

void main() {
  late MemoryStore store;
  late ProviderContainer c;

  setUp(() {
    store = MemoryStore();
    c = ProviderContainer.test(
      overrides: [jsonStoreProvider.overrideWithValue(store)],
    );
  });

  List<Flour> mine() => c.read(customFloursProvider);
  CustomFloursNotifier n() => c.read(customFloursProvider.notifier);
  const sains = Flour('Sainsbury’s strong white', 13.7, fibrePct: 3.1);
  const marriage = Flour(
    'Marriage’s wholemeal',
    12.9,
    wholegrain: true,
    fibrePct: 9.2,
    note: 'scanned',
  );

  test('starts empty; load with nothing saved stays empty', () async {
    expect(mine(), isEmpty);
    await n().load();
    expect(mine(), isEmpty);
    expect(store.bad, isEmpty);
  });

  test('load brings saved flours back, in order', () async {
    store.data[floursStoreName] = [marriage.toJson(), sains.toJson()];
    await n().load();
    expect(mine(), [marriage, sains]);
    expect(mine().first.note, 'scanned');
    expect(store.bad, isEmpty);
  });

  test('load skips a bad entry and sets the file aside first', () async {
    store.data[floursStoreName] = [
      sains.toJson(),
      {'name': 3},
      'junk',
    ];
    await n().load();
    expect(mine(), [sains]);
    expect(store.bad[floursStoreName], hasLength(3));
    // What loaded is written back: the next launch still has it.
    c = ProviderContainer.test(
      overrides: [jsonStoreProvider.overrideWithValue(store)],
    );
    await n().load();
    expect(mine(), [sains]);
  });

  test('a file that is not a list loads nothing, set aside', () async {
    store.data[floursStoreName] = {'flours': <Object?>[]};
    await n().load();
    expect(mine(), isEmpty);
    expect(store.bad, contains(floursStoreName));
  });

  test('add puts new flours first; replace and remove; all persist', () async {
    await n().add(sains);
    await n().add(marriage);
    expect(mine(), [marriage, sains]);
    expect(store.data[floursStoreName], [marriage.toJson(), sains.toJson()]);

    const edited = Flour('Sainsbury’s strong', 13.5, fibrePct: 3.1);
    await n().replace(1, edited);
    expect(mine(), [marriage, edited]);
    await n().remove(0);
    expect(mine(), [edited]);
    expect(store.data[floursStoreName], [edited.toJson()]);
    expect(store.writes, 4);
  });

  test('replace swaps the old flour in the blend, shares kept', () async {
    await n().add(sains);
    c
        .read(recipeProvider.notifier)
        .update(
          (i) => i.copyWith(
            flours: const [FlourShare(sains, 80), FlourShare(marriage, 20)],
          ),
        );
    const edited = Flour('Sainsbury’s strong', 13.5);
    await n().replace(0, edited);
    final blend = c.read(recipeProvider).flours;
    expect(
      [for (final f in blend) (f.flour, f.sharePct)],
      [(edited, 80.0), (marriage, 20.0)],
    );
  });

  test('replace leaves an unrelated recipe as it was', () async {
    await n().add(sains);
    final before = c.read(recipeProvider);
    await n().replace(0, marriage);
    expect(c.read(recipeProvider), same(before));
  });

  test('remove leaves recipes alone: they hold a snapshot', () async {
    await n().add(sains);
    c
        .read(recipeProvider.notifier)
        .update((i) => i.copyWith(flours: const [FlourShare(sains, 100)]));
    await n().remove(0);
    expect(c.read(recipeProvider).flours.single.flour, sains);
  });

  test('choices: presets then mine, each once', () async {
    await n().add(sains);
    // Equal to a preset: listed once, where the preset is.
    await n().add(const Flour('UK plain', 10, note: 'mine'));
    final choices = c.read(flourChoicesProvider);
    expect(choices, [...Flour.presets, sains]);
    expect(choices.where((f) => f.name == 'UK plain').single.note, '');
  });
}
