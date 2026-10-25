import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pizzalator/core/live_timer.dart';
import 'package:pizzalator/core/presets.dart';
import 'package:pizzalator/core/routine.dart';
import 'package:pizzalator/core/timer_run.dart';
import 'package:pizzalator/services/json_store.dart';
import 'package:pizzalator/services/live_timer.dart';
import 'package:pizzalator/state/recipe.dart';
import 'package:pizzalator/state/timer_run.dart';

import '../fakes.dart';

const _r = StepKind.rest;
const _a = StepKind.active;
const restA = RoutineStep(name: 'Rest A', kind: _r, minutes: 30);
const restB = RoutineStep(name: 'Rest B', kind: _r, minutes: 15);
const fold = RoutineStep(name: 'Fold', kind: _a, minutes: 2);

void main() {
  final t0 = DateTime(2026, 10, 24, 9);
  DateTime at(int minutes) => t0.add(Duration(minutes: minutes));
  late DateTime now;
  late MemoryStore store;
  late FakeLiveTimer live;
  late ProviderContainer c;

  setUp(() {
    now = t0;
    store = MemoryStore();
    live = FakeLiveTimer();
    c = ProviderContainer.test(
      overrides: [
        jsonStoreProvider.overrideWithValue(store),
        liveTimerProvider.overrideWithValue(live),
        clockProvider.overrideWithValue(() => now),
      ],
    );
  });

  TimerRun? s() => c.read(timerRunProvider);
  TimerRunNotifier n() => c.read(timerRunProvider.notifier);
  Map<String, Object?> saved() =>
      store.data[timerRunStoreName]! as Map<String, Object?>;

  Future<void> saveRun(TimerRun r) async =>
      store.data[timerRunStoreName] = jsonDecode(jsonEncode(r.toJson()));

  /// A rest A that ends at 30, then rest B (chained) and Fold.
  Future<void> restoreRests() async {
    await saveRun(TimerRun(steps: const [restA, restB, fold], endsAt: at(30)));
    await n().restore();
  }

  test('clock defaults to the wall clock', () {
    final real = ProviderContainer.test().read(clockProvider)();
    expect(real.difference(DateTime.now()).inSeconds.abs(), lessThan(2));
  });

  test('preview follows the routine and the recipe plan', () {
    expect(s(), isNull);
    final p = c.read(previewRunProvider);
    // Neapolitan: 2 h room bulk, then 24 h fridge as its own rest.
    expect(p.steps.length, defaultRoutine.steps.length + 1);
    expect([p.steps[9].minutes, p.steps[10].minutes], [120, 1440]);
    expect(p.cold, isTrue);
    c
        .read(recipeProvider.notifier)
        .update((i) => i.copyWith(plan: const [Stage(4, 22)]));
    final same = c.read(previewRunProvider);
    expect(same.steps.length, defaultRoutine.steps.length);
    expect(same.steps[9].minutes, 240);
    expect(same.cold, isFalse);
  });

  test('start snapshots the preview, asks permission once, saves', () async {
    await n().start();
    expect(s()!.index, 0);
    expect(s()!.phaseAt(now), RunPhase.ready);
    expect(saved()['index'], 0);
    expect(live.asks, 1);
    expect(live.shown, isNull, reason: 'on screen: no notification');
    await n().start();
    expect(live.asks, 1);
  });

  test('next starts the rest and saves it', () async {
    await n().start();
    now = at(4);
    await n().next();
    expect(s()!.index, 1);
    expect(s()!.endsAt, at(34));
    expect(saved()['index'], 1);
  });

  test('pause, resume and +5 are saved', () async {
    await n().start();
    await n().next();
    now = at(10);
    await n().pause();
    expect(s()!.phaseAt(now), RunPhase.paused);
    expect(saved()['leftMs'], const Duration(minutes: 20).inMilliseconds);
    now = at(40);
    await n().start();
    expect(s()!.endsAt, at(60));
    await n().extend();
    expect(saved()['endsAt'], at(65).millisecondsSinceEpoch);
  });

  test('auto-start setting is saved', () async {
    await n().start();
    await n().next();
    await n().setAutoStart(true);
    expect(s()!.autoStart, isTrue);
    expect(saved()['autoStart'], isTrue);
  });

  test('tick saves automatic transitions only', () async {
    await restoreRests();
    final writes = store.writes;
    now = at(10);
    await n().tick();
    expect(store.writes, writes, reason: 'nothing changed');
    now = at(31);
    await n().tick();
    expect(s()!.index, 1);
    expect(saved()['index'], 1);
  });

  test('tick chimes each timer end once, chained ones too', () async {
    await restoreRests();
    now = at(29);
    await n().tick();
    expect(live.chimes, 0);
    now = at(30);
    await n().tick();
    expect(live.chimes, 1);
    now = at(31);
    await n().tick();
    expect(live.chimes, 1);
    now = at(45);
    await n().tick();
    expect(live.chimes, 2);
    now = at(60);
    await n().tick();
    expect(live.chimes, 2, reason: 'Fold waits; nothing else ends');
  });

  test('the first tick after launch does not chime for the past', () async {
    await saveRun(TimerRun(steps: const [restA, fold], endsAt: at(30)));
    now = at(40);
    await n().restore();
    await n().tick();
    expect(live.chimes, 0);
  });

  test('actions apply on the settled run', () async {
    await restoreRests();
    now = at(50); // rest B ended at 45, Fold waits
    await n().next();
    expect(s()!.index, 2);
  });

  test('restore catches up after a kill', () async {
    await saveRun(
      TimerRun(steps: const [restA, restB, restA, fold], endsAt: at(30)),
    );
    now = at(50);
    await n().restore();
    expect(s()!.index, 2);
    expect(s()!.endsAt, at(75));
    expect(saved()['index'], 2);
  });

  test('restore takes back the notification and replays its taps', () async {
    // Killed while hidden; Pause was tapped on the notification at 10.
    await saveRun(TimerRun(steps: const [restA, fold], endsAt: at(30)));
    live.log.add(LiveAction(LiveTap.pause, at(10)));
    now = at(50);
    await n().restore();
    expect(live.stops, 1);
    expect(s()!.left, const Duration(minutes: 20));
    expect(saved()['leftMs'], const Duration(minutes: 20).inMilliseconds);
  });

  test('restore ignores a missing or corrupt file', () async {
    await n().restore();
    expect(s(), isNull);
    store.data[timerRunStoreName] = {'steps': 'nope'};
    await n().restore();
    expect(s(), isNull);
    expect(live.stops, 2, reason: 'a stale notification goes anyway');
  });

  test('next on the last step clears the run', () async {
    await saveRun(const TimerRun(steps: [fold]));
    await n().restore();
    await n().next();
    expect(s(), isNull);
    expect(store.data[timerRunStoreName], isNull);
    expect(store.data.containsKey(timerRunStoreName), isTrue);
  });

  test('stop ends the run and clears its file', () async {
    await restoreRests();
    await n().stop();
    expect(s(), isNull);
    expect(store.data[timerRunStoreName], isNull);
  });

  group('hidden', () {
    test('background hands the settled run to the notification', () async {
      await restoreRests();
      now = at(31);
      await n().background();
      final shown = live.shown!;
      expect(shown.startedAt, at(31));
      expect(shown.pausedAt, isNull);
      expect(
        jsonEncode(shown.legs),
        jsonEncode(liveLegs(s()!, at(31))),
        reason: 'laid out from the run as it is now',
      );
      expect(s()!.index, 1);
      expect(saved()['index'], 1);
    });

    test('background while paused starts the notification paused', () async {
      await restoreRests();
      now = at(10);
      await n().pause();
      now = at(12);
      await n().background();
      expect(live.shown!.pausedAt, at(12));
      expect(live.shown!.legs.first.first.end, const Duration(minutes: 20));
    });

    test('background chimes an end the last tick missed', () async {
      await restoreRests();
      now = at(29);
      await n().tick();
      now = at(30);
      await n().background();
      expect(live.chimes, 1);
      expect(live.shown!.legs.first.first.title, 'Rest B');
    });

    test('a tick before the taps are back does not settle', () async {
      await restoreRests();
      now = at(5);
      await n().background();
      live
        ..log.add(LiveAction(LiveTap.pause, at(10)))
        ..gate = Completer();
      now = at(40);
      final back = n().foreground();
      await n().tick();
      expect(s()!.index, 0, reason: 'still the run the notification had');
      live.gate!.complete();
      await back;
      expect(s()!.index, 0);
      expect(s()!.left, const Duration(minutes: 20));
    });

    test('ticks neither save nor chime while hidden', () async {
      await restoreRests();
      await n().background();
      final writes = store.writes;
      now = at(46);
      await n().tick();
      expect(store.writes, writes);
      expect(live.chimes, 0);
      expect(s()!.index, 0);
    });

    test('foreground replays the taps, settles and saves', () async {
      await restoreRests();
      now = at(5);
      await n().background();
      live.log.addAll([
        LiveAction(LiveTap.pause, at(10)), // 20 left
        LiveAction(LiveTap.resume, at(18)), // rest A ends at 38
      ]);
      now = at(40);
      await n().foreground();
      expect(live.shown, isNull);
      expect(s()!.index, 1);
      expect(s()!.endsAt, at(53), reason: 'rest B chained at 38');
      expect(saved()['endsAt'], at(53).millisecondsSinceEpoch);
    });

    test('foreground: no chime for ends while hidden', () async {
      await restoreRests();
      now = at(29);
      await n().tick();
      await n().background();
      now = at(31);
      await n().foreground();
      await n().tick();
      expect(live.chimes, 0, reason: 'the notification rang it');
      now = at(45);
      await n().tick();
      expect(live.chimes, 1);
    });

    test('Finish on the notification ends the run', () async {
      await saveRun(const TimerRun(steps: [fold]));
      await n().restore();
      await n().background();
      live.log.add(LiveAction(LiveTap.next, at(3)));
      now = at(4);
      await n().foreground();
      expect(s(), isNull);
      expect(store.data[timerRunStoreName], isNull);
    });

    test('no run: nothing shown, nothing saved', () async {
      await n().background();
      expect(live.shown, isNull);
      await n().foreground();
      expect(s(), isNull);
      expect(store.writes, 0);
    });
  });

  test('no run: tick and actions do nothing', () async {
    await n().tick();
    await n().pause();
    await n().next();
    await n().extend();
    await n().setAutoStart(true);
    expect(s(), isNull);
    expect(store.writes, 0);
  });
}
