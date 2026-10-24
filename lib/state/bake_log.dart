import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/bake_log.dart';
import '../core/calc.dart';
import '../core/recipe_json.dart';
import '../services/json_store.dart';
import '../services/photos.dart';
import 'oven.dart';
import 'recipe.dart';
import 'recipes.dart';
import 'timer_run.dart';

/// JsonStore file holding the bake log (PRD §5).
const bakesStoreName = 'bakes';

/// Logged bakes, newest first.
final bakeLogProvider = NotifierProvider<BakeLogNotifier, List<BakeEntry>>(
  BakeLogNotifier.new,
);

class BakeLogNotifier extends Notifier<List<BakeEntry>> {
  @override
  List<BakeEntry> build() => const [];

  JsonStore get _store => ref.read(jsonStoreProvider);
  PhotoStore get _photos => ref.read(photoStoreProvider);

  /// A bake that does not parse is skipped, and the file is set aside
  /// first, so the next write cannot destroy what was skipped. What did
  /// parse is written back, or the next launch would find no file at all.
  // ponytail: one file per collection; split per entry if it grows past a few hundred
  Future<void> load() async {
    final json = await _store.read(bakesStoreName);
    if (json == null) return;
    var bad = json is! List<Object?>;
    BakeEntry? parse(Object? e) {
      final entry = parseBake(e);
      if (entry == null) bad = true;
      return entry;
    }

    final log = [
      if (json is List<Object?>)
        for (final e in json) ?parse(e),
    ];
    if (bad) {
      await _store.keepBad(bakesStoreName);
      return _set(log);
    }
    state = log;
  }

  /// A new bake of the working copy, now: named after the recipe it came
  /// from (else the style), the plan's room and fridge and the oven's max
  /// filled in as what probably happened.
  BakeEntry draft() {
    final inputs = ref.read(recipeProvider);
    final oven = ref.read(ovenProvider);
    final active = ref.read(activeRecipeProvider);
    final plan = StagePlan.of(inputs.activePlan);
    final now = ref.read(clockProvider)();
    return BakeEntry(
      id: clockId(now, (id) => state.any((e) => e.id == id)),
      date: now,
      name: active?.name ?? inputs.style.label,
      recipeId: active?.id,
      inputs: inputs,
      oven: oven,
      roomC: plan.roomC,
      fridgeH: plan.fridgeH,
      ovenC: oven.maxTempC.toDouble(),
    );
  }

  Future<void> add(BakeEntry e) => _set([e, ...state]);

  /// In place, by id. A replaced photo's file goes.
  Future<void> update(BakeEntry e) async {
    final old = state.firstWhere((o) => o.id == e.id).photo;
    await _set([for (final o in state) o.id == e.id ? e : o]);
    if (old != null && old != e.photo) await _photos.delete(old);
  }

  /// Its photo too, once the log no longer points at it.
  Future<void> delete(String id) async {
    final photo = state.firstWhere((e) => e.id == id).photo;
    await _set([...state]..removeWhere((e) => e.id == id));
    if (photo != null) await _photos.delete(photo);
  }

  Future<void> _set(List<BakeEntry> next) {
    state = next;
    return _store.write(bakesStoreName, [for (final e in next) e.toJson()]);
  }
}
