import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/oven.dart';
import 'recipe.dart';

/// Current oven. First-launch default per PRD §2.
final ovenProvider = NotifierProvider<OvenNotifier, OvenSetup>(
  OvenNotifier.new,
);

class OvenNotifier extends Notifier<OvenSetup> {
  @override
  OvenSetup build() => OvenSetup.homeSteel;

  void set(OvenSetup oven) => state = oven;

  /// A picker preset. Within the same kind the user's max temperature stays.
  void pick(OvenSetup preset) => state = preset.kind == state.kind
      ? preset.copyWith(maxTempC: state.maxTempC)
      : preset;

  /// Clamped to the kind's range; the surface stays.
  void setMaxTemp(int c) {
    final (lo, hi) = state.maxTempRange;
    state = state.copyWith(maxTempC: c.clamp(lo, hi));
  }
}

/// Suggest-only edits. Apply with `recipeProvider.notifier.update(tip.apply)`.
final ovenTipsProvider = Provider<List<OvenTip>>(
  (ref) => ovenTips(
    ref.watch(recipeProvider),
    ref.watch(outputsProvider),
    ref.watch(ovenProvider),
  ),
);

/// Flour advice with a one-tap edit (weak flour).
final doughTipsProvider = Provider<List<OvenTip>>(
  (ref) => doughTips(ref.watch(recipeProvider), ref.watch(outputsProvider)),
);

final ovenWarningsProvider = Provider<List<String>>(
  (ref) => ovenWarnings(ref.watch(recipeProvider), ref.watch(ovenProvider)),
);

final bakeCardProvider = Provider<BakeCard>(
  (ref) => bakeCard(
    ref.watch(recipeProvider.select((i) => i.style)),
    ref.watch(ovenProvider),
  ),
);
