import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calc.dart';

/// Current calculator inputs. First-launch defaults per PRD §2.
final recipeProvider = NotifierProvider<RecipeNotifier, RecipeInputs>(
  RecipeNotifier.new,
);

/// Derived formula; recomputes whenever inputs change.
final outputsProvider = Provider<RecipeOutputs>(
  (ref) => calc(ref.watch(recipeProvider)),
);

class RecipeNotifier extends Notifier<RecipeInputs> {
  @override
  RecipeInputs build() => const RecipeInputs(style: PizzaStyle.neapolitan);

  void update(RecipeInputs Function(RecipeInputs) change) =>
      state = change(state);

  /// FR1: the new style's defaults and starting size. Baker's % the user set
  /// stay; ones a tip set were for the old style and go. A thickness preset
  /// stays thin / std / thick in the new style's terms. Amounts, flours, plan
  /// and leavening stay.
  void setStyle(PizzaStyle style) => update((i) {
    if (i.style == style) return i;
    final k = thicknessPresets(i.style).indexOf(i.thickness);
    return i
        .clear(i.fromTip)
        .copyWith(
          style: style,
          diameterCm: style.diameterCm,
          panWCm: style.panWCm,
          panLCm: style.panLCm,
          thickness: k < 0 ? null : thicknessPresets(style)[k],
        );
  });

  /// FR3: the other side starts from the current totals, so the percentages
  /// and the dough on screen carry over.
  void setMode(EntryMode mode) => update((i) {
    if (i.mode == mode) return i;
    final o = calc(i);
    return i.copyWith(mode: mode, flourG: o.totalFlourG, pizzas: o.ballCount);
  });

  /// The kitchen temperature: the plan's room stages, which the yeast model
  /// and the water temperature both read. A fridge-only plan has none.
  void setRoomC(double c) => update(
    (i) =>
        i.copyWith(plan: StagePlan.of(i.activePlan).copyWith(roomC: c).stages),
  );
  void setFlourG(double g) => update((i) => i.copyWith(flourG: g));
}
