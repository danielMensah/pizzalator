import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pizzalator/core/presets.dart';
import 'package:pizzalator/core/routine.dart';
import 'package:pizzalator/core/timer_run.dart';
import 'package:pizzalator/services/json_store.dart';
import 'package:pizzalator/services/notifications.dart';
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
  late FakeNotifications notes;
  late ProviderContainer c;

  setUp(() {
    now = t0;
    store = MemoryStore();
    notes = FakeNotifications();
    c = ProviderContainer.test(
      overrides: [
        jsonStoreProvider.overrideWithValue(store),
        notificationsProvider.overrideWithValue(notes),
        clockProvider.overrideWithValue(() => now),
      ],
    );
  });

  TimerRun? s() => c.read(timerRunProvider);
  TimerRunNotifier n() => c.read(timerRunProvider.notifier);
  Map<String, Object?> saved() =>
      store.data[timerRunStoreName]! as Map<String, Object?>;
  List<DateTime> alarmTimes() => [
    for (final i in notes.pending.keys.toList()..sort()) notes.pending[i]!.at,
  ];

  Future<void> saveRun(TimerRun r) async =>
      store.data[timerRunStoreName] = jsonDecode(jsonEncode(r.toJson()));

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
    expect(notes.asks, 1);
    expect(notes.cancels, 1);
    expect(notes.pending, isEmpty);
    await n().start();
    expect(notes.asks, 1);
  });

  test('next starts the rest and schedules its end', () async {
    await n().start();
    now = at(4);
    await n().next();
    expect(s()!.index, 1);
    expect(s()!.endsAt, at(34));
    expect(saved()['index'], 1);
    final a = notes.pending[0]!;
    expect(a.at, at(34));
    expect(a.title, 'Rest over');
    expect(a.body, 'Next: Fold in bowl 4–6×');
  });

  test('pause, resume and +5 reschedule', () async {
    await n().start();
    await n().next();
    now = at(10);
    await n().pause();
    expect(s()!.phaseAt(now), RunPhase.paused);
    expect(notes.pending, isEmpty);
    now = at(40);
    await n().start();
    expect(alarmTimes(), [at(60)]);
    await n().extend();
    expect(alarmTimes(), [at(65)]);
    expect(saved()['endsAt'], at(65).millisecondsSinceEpoch);
  });

  test('auto-start setting is saved and rescheduled', () async {
    await n().start();
    await n().next(); // rest A, 30 min, then Fold (untimed)
    await n().setAutoStart(true);
    expect(s()!.autoStart, isTrue);
    expect(saved()['autoStart'], isTrue);
    expect(alarmTimes(), [at(30)]);
  });

  test('tick saves automatic transitions, leaves alarms alone', () async {
    await saveRun(TimerRun(steps: const [restA, restB, fold], endsAt: at(30)));
    await n().restore();
    final writes = store.writes;
    final cancels = notes.cancels;
    now = at(10);
    await n().tick();
    expect(store.writes, writes, reason: 'nothing changed');
    now = at(31);
    await n().tick();
    expect(s()!.index, 1);
    expect(saved()['index'], 1);
    expect(notes.cancels, cancels);
  });

  test('actions apply on the settled run', () async {
    await saveRun(TimerRun(steps: const [restA, restB, fold], endsAt: at(30)));
    await n().restore();
    now = at(50); // rest B ended at 45, Fold waits
    await n().next();
    expect(s()!.index, 2);
  });

  test('restore catches up after a kill and reschedules', () async {
    await saveRun(
      TimerRun(steps: const [restA, restB, restA, fold], endsAt: at(30)),
    );
    now = at(50);
    await n().restore();
    expect(s()!.index, 2);
    expect(s()!.endsAt, at(75));
    expect(saved()['index'], 2);
    expect(alarmTimes(), [at(75)]);
    expect(notes.pending[0]!.body, 'Next: Fold');
  });

  test('restore ignores a missing or corrupt file', () async {
    await n().restore();
    expect(s(), isNull);
    store.data[timerRunStoreName] = {'steps': 'nope'};
    await n().restore();
    expect(s(), isNull);
    expect(notes.cancels, 0);
  });

  test('next on the last step clears the run', () async {
    await saveRun(const TimerRun(steps: [fold]));
    await n().restore();
    await n().next();
    expect(s(), isNull);
    expect(store.data[timerRunStoreName], isNull);
    expect(store.data.containsKey(timerRunStoreName), isTrue);
    expect(notes.pending, isEmpty);
  });

  test('reschedules run in call order', () async {
    // next() schedules two alarms (rest to rest), pause() right after none.
    // Unserialised, the first reschedule's alarms land after the second
    // one's cancel and ring for a paused timer.
    await saveRun(const TimerRun(steps: [fold, restA, restB, fold]));
    await n().restore();
    final a = n().next();
    final b = n().pause();
    await Future.wait([a, b]);
    expect(s()!.phaseAt(now), RunPhase.paused);
    expect(notes.pending, isEmpty);
  });

  test('a refused alarm does not stop the others or throw', () async {
    await saveRun(const TimerRun(steps: [fold, restA, restB, fold]));
    await n().restore();
    notes.failIds.add(0);
    await n().next();
    expect(notes.pending.keys, [1]);
    expect(notes.pending[1]!.at, at(45));
  });

  test('stop ends the run, clears its file and its alarms', () async {
    await saveRun(TimerRun(steps: const [restA, restB, fold], endsAt: at(30)));
    await n().restore();
    expect(notes.pending, isNotEmpty);
    await n().stop();
    expect(s(), isNull);
    expect(store.data[timerRunStoreName], isNull);
    expect(notes.pending, isEmpty);
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
