import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/timer_run.dart';
import '../services/json_store.dart';
import '../services/notifications.dart';
import 'recipe.dart';
import 'routine.dart';

/// JsonStore file holding the current run (null when none).
const timerRunStoreName = 'timer_run';

/// Wall clock; tests override it to move time.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// What Start would run: the current routine against the recipe's plan.
final previewRunProvider = Provider<TimerRun>(
  (ref) => TimerRun.fromRoutine(
    ref.watch(routineProvider).current.steps,
    ref.watch(recipeProvider.select((i) => i.activePlan)),
  ),
);

/// The running routine, or null. Saved and rescheduled after every change.
final timerRunProvider = NotifierProvider<TimerRunNotifier, TimerRun?>(
  TimerRunNotifier.new,
);

class TimerRunNotifier extends Notifier<TimerRun?> {
  /// Reschedules run one at a time so a slow one cannot land after a newer one.
  Future<void> _alarms = Future.value();

  @override
  TimerRun? build() => null;

  DateTime get _now => ref.read(clockProvider)();

  /// On launch: reloads the saved run, catches up the time spent killed and
  /// reschedules its notifications.
  Future<void> restore() async {
    final json = await ref.read(jsonStoreProvider).read(timerRunStoreName);
    if (json == null) return;
    final TimerRun run;
    try {
      run = TimerRun.fromJson(json as Map<String, Object?>);
    } on Error {
      return; // wrong shape: start fresh
    }
    await _set(run.settle(_now));
  }

  /// Starts the routine from the preview, or starts/resumes the current step.
  Future<void> start() {
    final r = state;
    if (r != null) return _set(r.start(_now));
    final done = _set(ref.read(previewRunProvider).start(_now));
    return Future.wait([
      done,
      ref.read(notificationsProvider).requestPermission(),
    ]);
  }

  Future<void> pause() => _update((r, now) => r.pause(now));

  Future<void> extend() => _update((r, now) => r.extend(now));

  /// Done, next and Skip. Clears the run after the last step.
  Future<void> next() => _update((r, now) => r.next(now));

  /// Ends the run wherever it is: file and alarms go too.
  Future<void> stop() => _set(null);

  Future<void> setAutoStart(bool on) =>
      _update((r, now) => r.withAutoStart(on, now).settle(now));

  /// Once a second from the screen. Alarms already cover the automatic
  /// chain, so only the save happens here.
  Future<void> tick() {
    final r = state;
    if (r == null) return Future.value();
    final settled = r.settle(_now);
    return identical(settled, r)
        ? Future.value()
        : _set(settled, reschedule: false);
  }

  Future<void> _update(TimerRun? Function(TimerRun run, DateTime now) change) {
    final r = state;
    if (r == null) return Future.value();
    final now = _now;
    return _set(change(r.settle(now), now));
  }

  Future<void> _set(TimerRun? run, {bool reschedule = true}) {
    state = run;
    final saved = ref
        .read(jsonStoreProvider)
        .write(timerRunStoreName, run?.toJson());
    if (!reschedule) return saved;
    final notes = ref.read(notificationsProvider);
    final alarms = run?.alarms(_now) ?? const <RunAlarm>[];
    _alarms = _alarms.catchError((Object _) {}).then((_) async {
      await notes.cancelAll();
      for (final (i, a) in alarms.indexed) {
        // One refused alarm must not cost the rest of the chain.
        try {
          await notes.scheduleAt(i, a.at, a.title, a.body);
        } on Object catch (e) {
          debugPrint('alarm $i not scheduled: $e');
        }
      }
    });
    return Future.wait([saved, _alarms]);
  }
}
