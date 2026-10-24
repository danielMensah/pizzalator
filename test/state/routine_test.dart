import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pizzalator/core/routine.dart';
import 'package:pizzalator/services/json_store.dart';
import 'package:pizzalator/state/routine.dart';

void main() {
  late Directory dir;
  late JsonStore store;
  late ProviderContainer c;

  ProviderContainer container() => ProviderContainer.test(
    overrides: [jsonStoreProvider.overrideWithValue(store)],
  );

  setUp(() {
    dir = Directory.systemTemp.createTempSync('routine_state_test');
    store = JsonStore(dir);
    c = container();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  RoutineState s() => c.read(routineProvider);
  RoutineNotifier n() => c.read(routineProvider.notifier);
  List<String> names() => s().current.steps.map((x) => x.name).toList();
  const extra = RoutineStep(name: 'New step', kind: StepKind.rest, minutes: 15);

  test('starts on the built-in default, clean', () {
    expect(s().presets, [defaultRoutine]);
    expect(s().selected, 0);
    expect(s().current, same(defaultRoutine));
    expect(s().dirty, isFalse);
  });

  test('load with nothing saved keeps the default', () async {
    await n().load();
    expect(s().current, same(defaultRoutine));
    expect(s().dirty, isFalse);
  });

  test('editing the built-in makes a dirty working copy', () async {
    await n().setMinutes(1, 45);
    expect(s().dirty, isTrue);
    expect(s().current.steps[1].minutes, 45);
    expect(s().current.builtIn, isFalse);
    expect(s().current.name, defaultRoutine.name);
    expect(s().presets.single, same(defaultRoutine));
    expect(defaultRoutine.steps[1].minutes, 30);
    // Further edits stay on the same working copy.
    await n().setMinutes(2, 3);
    expect(s().current.steps.map((x) => x.minutes).take(3), [5, 45, 3]);
  });

  test('setMinutes floors at 1', () async {
    await n().setMinutes(0, 0);
    expect(s().current.steps[0].minutes, 1);
  });

  test('editStep, addStep, removeStep, moveStep', () async {
    await n().editStep(0, defaultRoutine.steps[0].copyWith(name: 'Mix'));
    expect(names().first, 'Mix');
    await n().addStep(extra);
    expect(names().last, 'New step');
    expect(s().current.steps, hasLength(12));
    await n().removeStep(0);
    expect(names().first, 'Rest in bowl, covered');
    await n().moveStep(0, 2);
    expect(names().take(3), [
      'Fold in bowl 4–6×',
      'Rest, covered',
      'Rest in bowl, covered',
    ]);
    await n().moveStep(10, 0);
    expect(names().first, 'New step');
  });

  test('removeStep keeps at least one step', () async {
    for (var i = 0; i < 11; i++) {
      await n().removeStep(0);
    }
    expect(names(), ['Divide into balls']);
  });

  test('saveAsPreset appends, selects and cleans', () async {
    await n().setMinutes(9, 120);
    await n().saveAsPreset('  Same-day NY ');
    expect(s().presets, hasLength(2));
    expect(s().selected, 1);
    expect(s().dirty, isFalse);
    expect(s().current.name, 'Same-day NY');
    expect(s().current.builtIn, isFalse);
    expect(s().current.steps[9].minutes, 120);
    expect(s().current.steps[9].bindsToPlan, isTrue);
  });

  test('saveAsPreset with a blank name numbers the preset', () async {
    await n().saveAsPreset(' ');
    expect(s().current.name, 'Routine 2');
  });

  test('editing a user preset changes it in place, not dirty', () async {
    await n().saveAsPreset('Mine');
    await n().setMinutes(0, 8);
    expect(s().dirty, isFalse);
    expect(s().presets[1].steps[0].minutes, 8);
    expect(s().presets[0].steps[0].minutes, 5);
  });

  test('select switches preset and drops the working copy', () async {
    await n().saveAsPreset('Mine');
    await n().select(0);
    await n().setMinutes(0, 9);
    expect(s().dirty, isTrue);
    await n().select(1);
    expect(s().dirty, isFalse);
    expect(s().current.name, 'Mine');
    await n().select(0);
    expect(s().current, same(defaultRoutine));
  });

  test('resetToDefault selects the built-in and drops edits', () async {
    await n().saveAsPreset('Mine');
    await n().resetToDefault();
    expect(s().selected, 0);
    await n().setMinutes(0, 9);
    await n().resetToDefault();
    expect(s().dirty, isFalse);
    expect(s().current, same(defaultRoutine));
    expect(s().presets, hasLength(2));
  });

  test(
    'every mutation persists; load restores presets, selection, draft',
    () async {
      await n().saveAsPreset('A');
      await n().select(0);
      await n().setMinutes(9, 60);
      c.dispose();

      c = container();
      await n().load();
      expect(s().presets.map((p) => p.name), [defaultRoutine.name, 'A']);
      expect(s().presets.first, same(defaultRoutine));
      expect(s().selected, 0);
      expect(s().dirty, isTrue);
      expect(s().current.steps[9].minutes, 60);
      expect(s().current.steps[9].bindsToPlan, isTrue);

      await n().select(1);
      c.dispose();
      c = container();
      await n().load();
      expect(s().current.name, 'A');
      expect(s().dirty, isFalse);
    },
  );

  File saved([String ext = '']) =>
      File('${dir.path}/$routineStoreName.json$ext');

  test('load ignores a saved file of the wrong shape, and keeps it', () async {
    await store.write(routineStoreName, {'presets': 'nope'});
    await n().load();
    expect(s().current, same(defaultRoutine));
    // Set aside before the next edit writes the default over it.
    expect(saved('.bad').readAsStringSync(), '{"presets":"nope"}');
    expect(saved().existsSync(), isFalse);
    await store.write(routineStoreName, [1, 2]);
    await n().load();
    expect(s().presets, [defaultRoutine]);
  });

  test('one bad preset is skipped; the others load', () async {
    await store.write(routineStoreName, {
      'presets': [
        defaultRoutine.toJson()..['name'] = 'Good',
        {'name': 'Odd', 'steps': 'nope'},
        // A preset with no steps would crash the timers (TimerRun.step).
        {'name': 'Empty', 'steps': <Object>[]},
      ],
      'selected': 2,
    });
    await n().load();
    expect(s().presets.map((p) => p.name), [defaultRoutine.name, 'Good']);
    expect(s().selected, 1, reason: 'clamped to what loaded');
    expect(saved('.bad').existsSync(), isTrue);
  });

  test('a preset with no steps loads as the default', () async {
    await store.write(routineStoreName, {
      'presets': [
        {'name': 'x', 'steps': <Object>[]},
      ],
      'selected': 1,
    });
    await n().load();
    expect(s().current, same(defaultRoutine));
    expect(s().presets, [defaultRoutine]);
  });

  test('an empty draft is dropped too', () async {
    await store.write(routineStoreName, {
      'presets': <Object>[],
      'draft': {'name': 'x', 'steps': <Object>[]},
    });
    await n().load();
    expect(s().dirty, isFalse);
    expect(s().current, same(defaultRoutine));
  });

  test('a clean file is not set aside', () async {
    await n().saveAsPreset('A');
    c.dispose();
    c = container();
    await n().load();
    expect(saved('.bad').existsSync(), isFalse);
  });

  test('load clamps a selection past the end', () async {
    await store.write(routineStoreName, {'presets': <Object>[], 'selected': 4});
    await n().load();
    expect(s().selected, 0);
  });
}
