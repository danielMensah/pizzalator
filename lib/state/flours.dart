import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calc.dart';
import '../services/json_store.dart';
import 'recipe.dart';

/// JsonStore file holding the user's own flours (FR12).
const floursStoreName = 'flours';

/// The user's flours, newest first.
final customFloursProvider =
    NotifierProvider<CustomFloursNotifier, List<Flour>>(
      CustomFloursNotifier.new,
    );

/// What every flour picker lists: presets, then the user's own, each once (a
/// DropdownButton asserts exactly one item per value).
final flourChoicesProvider = Provider<List<Flour>>(
  (ref) => {...Flour.presets, ...ref.watch(customFloursProvider)}.toList(),
);

class CustomFloursNotifier extends Notifier<List<Flour>> {
  @override
  List<Flour> build() => const [];

  JsonStore get _store => ref.read(jsonStoreProvider);

  /// A flour that does not parse is skipped, and the file is set aside
  /// first, so the next write cannot destroy what was skipped. What did
  /// parse is written back, or the next launch would find no file at all.
  // ponytail: one file per collection; split per entry if it grows past a few hundred
  Future<void> load() async {
    final json = await _store.read(floursStoreName);
    if (json == null) return;
    var bad = json is! List<Object?>;
    Flour? parse(Object? f) {
      try {
        return Flour.fromJson(f! as Map<String, Object?>);
      } on Error {
        bad = true; // wrong shape: older, newer or hand-edited file
        return null;
      }
    }

    final flours = [
      if (json is List<Object?>)
        for (final f in json) ?parse(f),
    ];
    if (bad) {
      await _store.keepBad(floursStoreName);
      return _set(flours);
    }
    state = flours;
  }

  Future<void> add(Flour flour) => _set([flour, ...state]);

  /// Also swaps the old flour for the new one in the current blend, shares
  /// kept, so the edit shows up in the formula.
  Future<void> replace(int i, Flour flour) {
    final old = state[i];
    ref
        .read(recipeProvider.notifier)
        .update(
          (r) => r.flours.any((f) => f.flour == old)
              ? r.copyWith(
                  flours: [
                    for (final f in r.flours)
                      f.flour == old ? FlourShare(flour, f.sharePct) : f,
                  ],
                )
              : r,
        );
    return _set([...state]..[i] = flour);
  }

  /// Recipes keep their snapshot of the flour (PRD §4.3).
  Future<void> remove(int i) => _set([...state]..removeAt(i));

  Future<void> _set(List<Flour> next) {
    state = next;
    return _store.write(floursStoreName, [for (final f in next) f.toJson()]);
  }
}
