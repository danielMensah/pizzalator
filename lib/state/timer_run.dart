import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/live_timer.dart';
import '../core/timer_run.dart';
import '../services/json_store.dart';
import '../services/live_timer.dart';
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

/// The running routine, or null. Saved after every change; while the app
/// is hidden the live notification runs it (lib/core/live_timer.dart).
final timerRunProvider = NotifierProvider<TimerRunNotifier, TimerRun?>(
  TimerRunNotifier.new,
);

class TimerRunNotifier extends Notifier<TimerRun?> {
  /// Out of sight: the notification has the run, so ticks must not save a
  /// settle that a Pause tapped there would make wrong.
  var _hidden = false;

  /// The previous tick; a timer end since then chimes.
  DateTime? _last;

  @override
  TimerRun? build() => null;

  DateTime get _now => ref.read(clockProvider)();

  LiveTimer get _live => ref.read(liveTimerProvider);

  /// On launch: reloads the saved run, takes back the notification (the app
  /// may have been killed while hidden), replays the taps made on it and
  /// catches up the time spent away.
  Future<void> restore() async {
    final json = await ref.read(jsonStoreProvider).read(timerRunStoreName);
    final log = await _live.stop();
    if (json == null) return;
    final TimerRun run;
    try {
      run = TimerRun.fromJson(json as Map<String, Object?>);
    } on Error {
      return; // wrong shape: start fresh
    }
    await _set(replayLive(run, log)?.settle(_now));
  }

  /// Starts the routine from the preview, or starts/resumes the current step.
  Future<void> start() {
    final r = state;
    if (r != null) return _set(r.start(_now));
    final done = _set(ref.read(previewRunProvider).start(_now));
    return Future.wait([done, _live.requestPermission()]);
  }

  Future<void> pause() => _update((r, now) => r.pause(now));

  Future<void> extend() => _update((r, now) => r.extend(now));

  /// Done, next and Skip. Clears the run after the last step.
  Future<void> next() => _update((r, now) => r.next(now));

  /// Ends the run wherever it is; its file goes too.
  Future<void> stop() => _set(null);

  Future<void> setAutoStart(bool on) =>
      _update((r, now) => r.withAutoStart(on, now).settle(now));

  /// The app went out of sight: the notification takes the run over. A
  /// last tick first, so an end since the previous one still chimes.
  Future<void> background() {
    final ticked = tick();
    _hidden = true;
    final r = state;
    if (r == null) return ticked;
    final now = _now;
    final paused = r.phaseAt(now) == RunPhase.paused;
    return Future.wait([
      ticked,
      _live.show(liveLegs(r, now), now, pausedAt: paused ? now : null),
    ]);
  }

  /// Back on screen: the notification goes and its taps are replayed. Still
  /// hidden until then: a tick must not settle the run the taps were made
  /// on. Ends while hidden already rang there.
  Future<void> foreground() async {
    final log = await _live.stop();
    _hidden = false;
    _last = null;
    final r = state;
    if (r != null) await _set(replayLive(r, log)?.settle(_now));
  }

  /// Once a second while on screen: chimes a timer end and saves the
  /// automatic transitions.
  Future<void> tick() {
    final now = _now;
    final from = _last ?? now;
    _last = now;
    final r = state;
    if (r == null || _hidden) return Future.value();
    final settled = r.settle(now);
    return Future.wait([
      if (r.endedBetween(from, now)) _live.chime(),
      if (!identical(settled, r)) _set(settled),
    ]);
  }

  Future<void> _update(TimerRun? Function(TimerRun run, DateTime now) change) {
    final r = state;
    if (r == null) return Future.value();
    final now = _now;
    return _set(change(r.settle(now), now));
  }

  Future<void> _set(TimerRun? run) {
    state = run;
    return ref.read(jsonStoreProvider).write(timerRunStoreName, run?.toJson());
  }
}
