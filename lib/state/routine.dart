import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/routine.dart';
import '../services/json_store.dart';

/// JsonStore file holding the user presets, selection and working copy.
const routineStoreName = 'routines';

final routineProvider = NotifierProvider<RoutineNotifier, RoutineState>(
  RoutineNotifier.new,
);

class RoutineState {
  const RoutineState({required this.presets, this.selected = 0, this.draft});

  /// `presets[0]` is always the built-in [defaultRoutine].
  final List<RoutinePreset> presets;
  final int selected;

  /// Unsaved working copy of the built-in, created by the first edit.
  final RoutinePreset? draft;

  RoutinePreset get current => draft ?? presets[selected];
  bool get dirty => draft != null;
}

class RoutineNotifier extends Notifier<RoutineState> {
  @override
  RoutineState build() => const RoutineState(presets: [defaultRoutine]);

  JsonStore get _store => ref.read(jsonStoreProvider);

  /// Restores saved presets; keeps the default when nothing (valid) is saved.
  /// A preset that does not parse or has no steps is skipped, and the file is
  /// set aside first, so the next write cannot destroy what was skipped.
  /// What did parse is written back, or the next launch would find no file.
  Future<void> load() async {
    final json = await _store.read(routineStoreName);
    if (json == null) return;
    var bad = false;
    RoutinePreset? parse(Object? p) {
      try {
        final preset = RoutinePreset.fromJson(p! as Map<String, Object?>);
        if (preset.steps.isNotEmpty) return preset;
      } on Error {
        // Wrong shape (older, newer or hand-edited file).
      }
      bad = true;
      return null;
    }

    final m = json is Map<String, Object?> ? json : null;
    final list = m?['presets'];
    final presets = [
      defaultRoutine,
      if (list is List<Object?>)
        for (final p in list) ?parse(p),
    ];
    final draft = m?['draft'] == null ? null : parse(m!['draft']);
    final selected = m?['selected'];
    final next = RoutineState(
      presets: presets,
      selected: (selected is int ? selected : 0).clamp(0, presets.length - 1),
      draft: draft,
    );
    if (m == null || list is! List<Object?> || bad) {
      await _store.keepBad(routineStoreName);
      return _set(next);
    }
    state = next;
  }

  Future<void> select(int i) =>
      _set(RoutineState(presets: state.presets, selected: i));

  Future<void> resetToDefault() => select(0);

  /// A saved recipe's routine (null: the built-in). The built-in's name with
  /// other steps is its working copy; any other name selects that preset,
  /// added when it is not here.
  Future<void> use(RoutinePreset? routine) {
    if (routine == null) return select(0);
    final s = state;
    final i = s.presets.indexWhere((p) => p.name == routine.name);
    if (i == 0) {
      return _set(RoutineState(presets: s.presets, draft: routine));
    }
    if (i > 0) return select(i);
    return _set(
      RoutineState(
        presets: [...s.presets, routine],
        selected: s.presets.length,
      ),
    );
  }

  Future<void> setMinutes(int step, int minutes) =>
      _edit((s) => s[step] = s[step].copyWith(minutes: max(1, minutes)));

  Future<void> editStep(int i, RoutineStep step) => _edit((s) => s[i] = step);

  Future<void> addStep(RoutineStep step) => _edit((s) => s.add(step));

  /// Keeps at least one step.
  Future<void> removeStep(int i) => state.current.steps.length > 1
      ? _edit((s) => s.removeAt(i))
      : Future.value();

  /// [to] is the step's index after the move.
  Future<void> moveStep(int from, int to) =>
      _edit((s) => s.insert(to, s.removeAt(from)));

  /// Saves the current steps as a new user preset and selects it.
  Future<void> saveAsPreset(String name) {
    final s = state;
    final trimmed = name.trim();
    final preset = RoutinePreset(
      name: trimmed.isEmpty ? 'Routine ${s.presets.length + 1}' : trimmed,
      steps: s.current.steps,
    );
    return _set(
      RoutineState(presets: [...s.presets, preset], selected: s.presets.length),
    );
  }

  /// Built-in → working copy (dirty); user preset → edited in place.
  Future<void> _edit(void Function(List<RoutineStep> steps) change) {
    final s = state;
    final steps = [...s.current.steps];
    change(steps);
    final edited = RoutinePreset(name: s.current.name, steps: steps);
    if (s.presets[s.selected].builtIn) {
      return _set(
        RoutineState(presets: s.presets, selected: s.selected, draft: edited),
      );
    }
    return _set(
      RoutineState(
        presets: [...s.presets]..[s.selected] = edited,
        selected: s.selected,
      ),
    );
  }

  Future<void> _set(RoutineState next) {
    state = next;
    return _store.write(routineStoreName, {
      'presets': [
        for (final p in next.presets)
          if (!p.builtIn) p.toJson(),
      ],
      'selected': next.selected,
      'draft': next.draft?.toJson(),
    });
  }
}
