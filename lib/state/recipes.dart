import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calc.dart';
import '../core/oven.dart';
import '../core/recipe_json.dart';
import '../core/routine.dart';
import '../services/json_store.dart';
import 'oven.dart';
import 'recipe.dart';
import 'routine.dart';
import 'timer_run.dart';

/// JsonStore file holding the saved recipes (PRD §5).
const recipesStoreName = 'recipes';

/// JsonStore file holding the working copy: inputs, oven and the id of the
/// recipe it came from, so launch opens on the last-used recipe (PRD §5).
const currentStoreName = 'current';

/// Saved recipes, newest first.
final savedRecipesProvider =
    NotifierProvider<SavedRecipesNotifier, List<SavedRecipe>>(
      SavedRecipesNotifier.new,
    );

/// Id of the saved recipe the working copy came from, or null.
final activeRecipeIdProvider =
    NotifierProvider<ActiveRecipeIdNotifier, String?>(
      ActiveRecipeIdNotifier.new,
    );

/// The saved recipe the working copy came from; null when none (or it was
/// deleted).
final activeRecipeProvider = Provider<SavedRecipe?>((ref) {
  final id = ref.watch(activeRecipeIdProvider);
  return ref.watch(savedRecipesProvider).where((r) => r.id == id).firstOrNull;
});

/// The working copy differs from the active recipe: inputs, oven or routine.
final recipeDirtyProvider = Provider<bool>((ref) {
  final a = ref.watch(activeRecipeProvider);
  return a != null &&
      _body(a.inputs, a.oven, a.routine) !=
          _body(
            ref.watch(recipeProvider),
            ref.watch(ovenProvider),
            routineToSave(ref.watch(routineProvider)),
          );
});

/// What a recipe keeps of the routine: nothing for the built-in as is.
RoutinePreset? routineToSave(RoutineState s) =>
    s.current.builtIn ? null : s.current;

String _body(RecipeInputs i, OvenSetup o, RoutinePreset? r) =>
    jsonEncode([inputsToJson(i), ovenToJson(o), r?.toJson()]);

class ActiveRecipeIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? id) => state = id;
}

class SavedRecipesNotifier extends Notifier<List<SavedRecipe>> {
  @override
  List<SavedRecipe> build() => const [];

  JsonStore get _store => ref.read(jsonStoreProvider);
  DateTime get _now => ref.read(clockProvider)();
  ActiveRecipeIdNotifier get _active =>
      ref.read(activeRecipeIdProvider.notifier);

  /// A recipe that does not parse is skipped, and the file is set aside
  /// first, so the next write cannot destroy what was skipped. What did
  /// parse is written back, or the next launch would find no file at all.
  // ponytail: one file per collection; split per entry if it grows past a few hundred
  Future<void> load() async {
    final json = await _store.read(recipesStoreName);
    if (json == null) return;
    var bad = json is! List<Object?>;
    SavedRecipe? parse(Object? r) {
      final recipe = parseRecipe(r);
      if (recipe == null) bad = true;
      return recipe;
    }

    final recipes = [
      if (json is List<Object?>)
        for (final r in json) ?parse(r),
    ];
    if (bad) {
      await _store.keepBad(recipesStoreName);
      return _set(recipes);
    }
    state = recipes;
  }

  /// The working copy as a new recipe on top, now the active one. A blank
  /// name takes the style's.
  Future<void> saveAs(String name) {
    final trimmed = name.trim();
    final r = _working(
      _newId(state),
      trimmed.isEmpty ? ref.read(recipeProvider).style.label : trimmed,
    );
    _active.set(r.id);
    return _set([r, ...state]);
  }

  /// The working copy over the active recipe, in place.
  Future<void> saveChanges() {
    final id = ref.read(activeRecipeIdProvider);
    final a = state.where((r) => r.id == id).firstOrNull;
    if (a == null) return Future.value();
    return _set([
      for (final r in state) r.id == a.id ? _working(a.id, a.name) : r,
    ]);
  }

  /// [r] becomes the working copy: formula, oven and routine.
  Future<void> open(SavedRecipe r) {
    ref.read(recipeProvider.notifier).update((_) => r.inputs);
    ref.read(ovenProvider.notifier).set(r.oven);
    _active.set(r.id);
    return ref.read(routineProvider.notifier).use(r.routine);
  }

  /// A copy right under the original.
  Future<void> duplicate(int i) {
    final r = state[i];
    final copy = r.copyWith(
      id: _newId(state),
      name: '${r.name} copy',
      savedAt: _now,
    );
    return _set([...state]..insert(i + 1, copy));
  }

  Future<void> rename(int i, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return Future.value();
    return _set([...state]..[i] = state[i].copyWith(name: trimmed));
  }

  Future<void> delete(int i) {
    if (state[i].id == ref.read(activeRecipeIdProvider)) _active.set(null);
    return _set([...state]..removeAt(i));
  }

  String exportJson() => exportRecipes(state);

  /// The recipes in an export, on top; one whose id is taken gets a new
  /// id. Returns how many came in. Throws a [FormatException] when [text]
  /// is not an export.
  Future<int> importJson(String text) async {
    final added = <SavedRecipe>[];
    for (final r in importRecipes(text)) {
      final taken = [...added, ...state];
      added.add(
        taken.any((t) => t.id == r.id) ? r.copyWith(id: _newId(taken)) : r,
      );
    }
    if (added.isNotEmpty) await _set([...added, ...state]);
    return added.length;
  }

  /// Launch: the last working copy back. A file this build cannot read is
  /// set aside and the first-launch defaults stay.
  Future<void> restoreCurrent() async {
    final json = await _store.read(currentStoreName);
    if (json == null) return;
    final RecipeInputs inputs;
    final OvenSetup oven;
    final String? id;
    try {
      final m = json as Map<String, Object?>;
      inputs = inputsFromJson(m['inputs']! as Map<String, Object?>);
      oven = ovenFromJson(m['oven']! as Map<String, Object?>);
      id = m['activeId'] as String?;
    } on Error {
      return _store.keepBad(currentStoreName);
    }
    ref.read(recipeProvider.notifier).update((_) => inputs);
    ref.read(ovenProvider.notifier).set(oven);
    _active.set(id);
  }

  // ponytail: written on every change; debounce if a stepper held down shows in a trace
  Future<void> saveCurrent() => _store.write(currentStoreName, {
    'inputs': inputsToJson(ref.read(recipeProvider)),
    'oven': ovenToJson(ref.read(ovenProvider)),
    'activeId': ref.read(activeRecipeIdProvider),
  });

  SavedRecipe _working(String id, String name) => SavedRecipe(
    id: id,
    name: name,
    inputs: ref.read(recipeProvider),
    oven: ref.read(ovenProvider),
    routine: routineToSave(ref.read(routineProvider)),
    savedAt: _now,
  );

  String _newId(List<SavedRecipe> taken) =>
      clockId(_now, (id) => taken.any((r) => r.id == id));

  Future<void> _set(List<SavedRecipe> next) {
    state = next;
    return _store.write(recipesStoreName, [for (final r in next) r.toJson()]);
  }
}
