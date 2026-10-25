import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pizzalator/core/routine.dart';
import 'package:pizzalator/core/timer_run.dart';
import 'package:pizzalator/routes.dart';
import 'package:pizzalator/screens/timers.dart';
import 'package:pizzalator/services/json_store.dart';
import 'package:pizzalator/services/live_timer.dart';
import 'package:pizzalator/state/timer_run.dart';
import 'package:pizzalator/theme/pizza_theme.dart';
import 'package:pizzalator/widgets/widgets.dart';

import '../fakes.dart';

const _r = StepKind.rest;
const _a = StepKind.active;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final t0 = DateTime(2026, 6, 10, 9); // clear of DST changes
  late DateTime now;
  late MemoryStore store;
  late ProviderContainer c;
  late List<String> haptics;

  setUp(() {
    now = t0;
    store = MemoryStore();
    c = ProviderContainer.test(
      overrides: [
        jsonStoreProvider.overrideWithValue(store),
        liveTimerProvider.overrideWithValue(FakeLiveTimer()),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    haptics = [];
  });

  TimerRun? run() => c.read(timerRunProvider);

  Future<void> pumpScreen(WidgetTester tester, {bool reduce = false}) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      },
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: pizzaTheme(Brightness.dark),
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
            child: app!,
          ),
          initialRoute: Routes.timers,
          routes: {
            Routes.calculator: (_) => const Scaffold(body: Text('Recipe page')),
            // Non-const so the constructor runs under coverage.
            Routes.timers: (_) => TimersScreen(key: GlobalKey()),
            Routes.routine: (_) => const Scaffold(body: Text('Routine editor')),
          },
        ),
      ),
    );
  }

  /// Restores a saved run, as main.dart does on launch.
  Future<void> restore(TimerRun r) async {
    store.data[timerRunStoreName] = jsonDecode(jsonEncode(r.toJson()));
    await c.read(timerRunProvider.notifier).restore();
  }

  Future<void> tick(WidgetTester tester, Duration d) async {
    now = now.add(d);
    await tester.pump(const Duration(seconds: 1));
  }

  RingTimer ring(WidgetTester tester) =>
      tester.widget<RingTimer>(find.byType(RingTimer));

  StepRow row(WidgetTester tester, String name) => tester.widget<StepRow>(
    find.ancestor(of: find.text(name), matching: find.byType(StepRow)),
  );

  bool enabled(WidgetTester tester, String label) =>
      tester
          .widget<ButtonStyleButton>(
            find.ancestor(
              of: find.text(label),
              matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
            ),
          )
          .onPressed !=
      null;

  testWidgets('preview: default routine against the recipe plan', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpScreen(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Dough routine'), findsOneWidget);
    // Neapolitan: the bulk is 2 h in the room, then 24 h in the fridge.
    expect(find.text('Step 1 of 12'), findsOneWidget);
    // 5+30+2+15+2+15+10+30+5 min hands-on and rests + 2 h + 24 h + 5.
    expect(find.text('28.0 h left'), findsOneWidget);
    expect(find.text('12:59'), findsOneWidget);
    expect(find.text('BALLS READY'), findsOneWidget);
    expect(find.bySemanticsLabel('Balls ready 12:59'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Hands on, Mix all ingredients, ~5 min remaining'),
      findsOneWidget,
    );
    semantics.dispose();
    expect(ring(tester).clock, '~5 min');
    expect(ring(tester).label, 'Hands on');
    expect(ring(tester).title, 'Mix all ingredients');
    expect(ring(tester).progress, 1);
    expect(ring(tester).color, PizzaColors.dark.wheat);
    expect(find.text('Start'), findsOneWidget);
    expect(enabled(tester, '+5'), isFalse);
    expect(enabled(tester, 'Skip'), isFalse);
    expect(find.bySemanticsLabel('Add five minutes'), findsOneWidget);
    expect(find.text('Auto-start'), findsNothing);
    expect(row(tester, 'Mix all ingredients').state, StepRowState.upcoming);
    expect(row(tester, 'Mix all ingredients').sub, 'hands on');
    expect(row(tester, 'Mix all ingredients').trailing, '~5 min');
    expect(row(tester, 'Rest in bowl, covered').sub, 'covered rest');
    expect(row(tester, 'Rest in bowl, covered').accent, PizzaColors.dark.ember);
    await tester.scrollUntilVisible(find.text('Knead on the counter'), 50);
    expect(row(tester, 'Knead on the counter').trailing, '10 min');
    await tester.scrollUntilVisible(find.text('Bulk in container'), 50);
    expect(row(tester, 'Bulk in container').trailing, '2 h');
    await tester.scrollUntilVisible(find.text('Fridge'), 50);
    expect(row(tester, 'Fridge').trailing, '24 h');
  });

  testWidgets('start, done next, then the rest counts down', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Start'));
    await tester.pump();
    expect(run()!.index, 0);
    expect(find.text('Done, next'), findsOneWidget);
    // Under the ring, every line of it: the face has no room for it.
    final note = find.textContaining('Water, yeast');
    expect(tester.widget<Text>(note).maxLines, isNull);
    expect(
      tester.getRect(note).top,
      greaterThan(tester.getRect(find.byType(RingTimer)).bottom),
    );
    expect(row(tester, 'Mix all ingredients').state, StepRowState.current);
    expect(row(tester, 'Mix all ingredients').sub, 'in progress');

    await tester.tap(find.text('Done, next'));
    await tester.pump();
    expect(find.text('Step 2 of 12'), findsOneWidget);
    expect(ring(tester).label, 'Resting');
    expect(ring(tester).clock, '30:00');
    expect(ring(tester).breathing, isTrue);
    expect(ring(tester).color, PizzaColors.dark.ember);
    expect(find.text('Cover with napkins / cloth'), findsOneWidget);
    expect(row(tester, 'Mix all ingredients').state, StepRowState.done);
    expect(row(tester, 'Mix all ingredients').sub, 'done');
    expect(row(tester, 'Rest in bowl, covered').sub, 'resting now');

    await tick(tester, const Duration(seconds: 1));
    expect(ring(tester).clock, '29:59');

    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(ring(tester).label, 'Paused');
    expect(ring(tester).breathing, isFalse);
    await tick(tester, const Duration(minutes: 10));
    expect(ring(tester).clock, '29:59');

    await tester.tap(find.text('Resume'));
    await tester.pump();
    expect(find.text('Pause'), findsOneWidget);
    await tester.tap(find.text('+5'));
    await tester.pump();
    expect(ring(tester).clock, '34:59');
    expect(ring(tester).progress, 1, reason: 'clamped past the step length');
  });

  testWidgets('rest end: haptic, ding state, next step named', (tester) async {
    await restore(
      TimerRun(
        steps: const [
          RoutineStep(name: 'Rest', kind: _r, minutes: 15),
          RoutineStep(name: 'Fold', kind: _a, minutes: 2),
        ],
        endsAt: t0.add(const Duration(minutes: 15)),
      ),
    );
    await pumpScreen(tester);
    await tick(tester, const Duration(minutes: 14, seconds: 58));
    expect(haptics, isEmpty);
    await tick(tester, const Duration(seconds: 2));
    expect(haptics, ['HapticFeedbackType.heavyImpact']);
    expect(ring(tester).label, 'Rest over');
    expect(ring(tester).clock, '00:00');
    expect(ring(tester).progress, 0);
    expect(ring(tester).color, PizzaColors.dark.sage);
    expect(find.text('Next: Fold'), findsOneWidget);
    expect(find.text('0 min left'), findsNothing);
    expect(find.text('2 min left'), findsOneWidget);
    await tick(tester, const Duration(seconds: 5));
    expect(haptics, hasLength(1), reason: 'once per timer end');

    await tester.tap(find.text('Done, next'));
    await tester.pump();
    expect(ring(tester).clock, '~2 min');
    expect(find.text('Next: Fold'), findsNothing);
    expect(find.text('Finish'), findsOneWidget);
    expect(enabled(tester, '+5'), isFalse);
  });

  testWidgets('timed active step: Start N min, then it counts', (tester) async {
    await restore(
      const TimerRun(
        steps: [
          RoutineStep(name: 'Knead', kind: _a, minutes: 10, note: 'Push'),
          RoutineStep(name: 'Rest', kind: _r, minutes: 90),
        ],
      ),
    );
    await pumpScreen(tester);
    expect(ring(tester).clock, '10:00');
    expect(find.text('Start 10 min'), findsOneWidget);
    expect(row(tester, 'Rest').trailing, '1.5 h');
    await tester.tap(find.text('Start 10 min'));
    await tester.pump();
    expect(ring(tester).label, 'Hands on');
    expect(ring(tester).breathing, isFalse);
    await tick(tester, const Duration(minutes: 10));
    expect(ring(tester).label, 'Step done');
    expect(find.text('Next: Rest'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(ring(tester).clock, '1:30:00');
    expect(find.text('1.5 h left'), findsOneWidget);
  });

  testWidgets('a chained end dings the ring too, not only the haptic', (
    tester,
  ) async {
    await restore(
      TimerRun(
        steps: const [
          RoutineStep(name: 'Rest A', kind: _r, minutes: 10),
          RoutineStep(name: 'Rest B', kind: _r, minutes: 10),
          RoutineStep(name: 'Fold', kind: _a, minutes: 2),
        ],
        endsAt: t0.add(const Duration(minutes: 10)),
      ),
    );
    await pumpScreen(tester);
    expect(ring(tester).dings, 0);
    expect(ring(tester).stepKey, 0);
    await tick(tester, const Duration(minutes: 10));
    // Rest B started the same instant: the arc never showed zero.
    expect(ring(tester).title, 'Rest B');
    expect(ring(tester).dings, 1);
    expect(ring(tester).stepKey, 1);
    expect(haptics, hasLength(1));
  });

  testWidgets('shows the settled run, so taps act on what is shown', (
    tester,
  ) async {
    const rest = RoutineStep(name: 'R', kind: _r, minutes: 10);
    await restore(
      TimerRun(
        steps: [
          rest.copyWith(name: 'R1'),
          rest.copyWith(name: 'R2'),
          rest.copyWith(name: 'R3'),
          rest.copyWith(name: 'R4'),
          const RoutineStep(name: 'Fold', kind: _a, minutes: 2),
        ],
        endsAt: t0.add(const Duration(minutes: 10)),
      ),
    );
    // Back on the screen 25 min later: R1 and R2 are over, R3 runs.
    now = t0.add(const Duration(minutes: 25));
    await pumpScreen(tester);
    expect(find.text('Step 3 of 5'), findsOneWidget);
    expect(ring(tester).title, 'R3');
    expect(ring(tester).label, 'Resting');
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(run()!.step.name, 'R4');
  });

  testWidgets('End routine, after a confirm, drops the run', (tester) async {
    await restore(
      TimerRun(
        steps: const [
          RoutineStep(name: 'Rest', kind: _r, minutes: 30),
          RoutineStep(name: 'Fold', kind: _a, minutes: 2),
        ],
        endsAt: t0.add(const Duration(minutes: 30)),
      ),
    );
    await pumpScreen(tester);
    await tester.scrollUntilVisible(find.text('End routine'), 50);
    await tester.tap(find.text('End routine'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('End this routine?'), findsOneWidget);
    await tester.tap(find.text('Keep going'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(run(), isNotNull);

    await tester.tap(find.text('End routine'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('End'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(run(), isNull);
    expect(store.data[timerRunStoreName], isNull);
    expect(find.text('Start'), findsOneWidget, reason: 'the preview again');
    expect(find.text('End routine'), findsNothing);
  });

  testWidgets('Finish clears the run and goes back', (tester) async {
    await restore(
      const TimerRun(
        steps: [RoutineStep(name: 'Divide', kind: _a, minutes: 5)],
      ),
    );
    await pumpScreen(tester);
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    expect(run(), isNull);
    expect(find.text('Recipe page'), findsOneWidget);
  });

  testWidgets('auto-start switch', (tester) async {
    await restore(
      const TimerRun(
        steps: [RoutineStep(name: 'Divide', kind: _a, minutes: 5)],
      ),
    );
    await pumpScreen(tester);
    expect(find.text('Auto-start'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(run()!.autoStart, isTrue);
  });

  testWidgets('Edit routine opens the editor; Recipe goes back', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Edit routine'));
    await tester.pumpAndSettle();
    expect(find.text('Routine editor'), findsOneWidget);
    Navigator.of(tester.element(find.text('Routine editor'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recipe'));
    await tester.pumpAndSettle();
    expect(find.text('Recipe page'), findsOneWidget);
  });

  testWidgets('reduced motion: the rest ring still reports breathing', (
    tester,
  ) async {
    // RingTimer drops the animation itself; the screen only states the fact.
    await restore(
      TimerRun(
        steps: const [RoutineStep(name: 'Rest', kind: _r, minutes: 15)],
        endsAt: t0.add(const Duration(minutes: 15)),
      ),
    );
    await pumpScreen(tester, reduce: true);
    expect(ring(tester).breathing, isTrue);
    expect(reduceMotion(tester.element(find.byType(RingTimer))), isTrue);
  });
}
