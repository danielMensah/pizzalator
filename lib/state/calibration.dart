import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calibration.dart';
import '../services/json_store.dart';
import 'bake_log.dart';
import 'oven.dart';
import 'recipe.dart';
import 'recipes.dart';

/// JsonStore file holding the hints set aside with "Not now".
const hintsStoreName = 'hints';

/// Hint ids (rule + newest bake) the user said "Not now" to.
final hintDismissalsProvider =
    NotifierProvider<HintDismissalsNotifier, Set<String>>(
      HintDismissalsNotifier.new,
    );

/// What the bake log suggests for the working copy, "Not now"s left out.
/// Suggest-only: nothing applies without a tap (PRD §5).
final calibrationHintsProvider = Provider<List<CalibrationHint>>((ref) {
  final inputs = ref.watch(recipeProvider);
  final dismissed = ref.watch(hintDismissalsProvider);
  return [
    for (final h in calibrationHints(
      ref.watch(bakeLogProvider),
      inputs,
      ref.watch(ovenProvider),
      name: ref.watch(activeRecipeProvider)?.name ?? inputs.style.label,
    ))
      if (!dismissed.contains(h.id)) h,
  ];
});

class HintDismissalsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  JsonStore get _store => ref.read(jsonStoreProvider);

  /// An id that is not a string is skipped, and the file is set aside
  /// first, so the next write cannot destroy what was skipped. What did
  /// parse is written back, or the next launch would find no file at all.
  // ponytail: one file per collection; split per entry if it grows past a few hundred
  Future<void> load() async {
    final json = await _store.read(hintsStoreName);
    if (json == null) return;
    final ids = {
      if (json is List<Object?>)
        for (final id in json)
          if (id is String) id,
    };
    if (json is! List<Object?> || ids.length != json.length) {
      await _store.keepBad(hintsStoreName);
      return _set(ids);
    }
    state = ids;
  }

  Future<void> dismiss(String id) => _set({...state, id});

  Future<void> _set(Set<String> next) {
    state = next;
    return _store.write(hintsStoreName, next.toList());
  }
}
