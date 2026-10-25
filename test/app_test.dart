import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pizzalator/app.dart';
import 'package:pizzalator/core/bake_log.dart';
import 'package:pizzalator/core/calc.dart';
import 'package:pizzalator/core/export_text.dart';
import 'package:pizzalator/core/oven.dart';
import 'package:pizzalator/core/recipe_json.dart';
import 'package:pizzalator/core/routine.dart';
import 'package:pizzalator/core/live_timer.dart';
import 'package:pizzalator/core/timer_run.dart';
import 'package:pizzalator/routes.dart';
import 'package:pizzalator/services/json_store.dart';
import 'package:pizzalator/services/live_timer.dart';
import 'package:pizzalator/state/bake_log.dart';
import 'package:pizzalator/state/calibration.dart';
import 'package:pizzalator/state/flours.dart';
import 'package:pizzalator/state/oven.dart';
import 'package:pizzalator/state/recipe.dart';
import 'package:pizzalator/state/recipes.dart';
import 'package:pizzalator/state/routine.dart';
import 'package:pizzalator/state/timer_run.dart';
import 'package:pizzalator/widgets/buttons.dart';

import 'fakes.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('dark theme by default, opens on calculator', (tester) async {
    // Non-const so the constructor itself runs under coverage.
    await tester.pumpWidget(
      ProviderScope(child: PizzalatorApp(key: GlobalKey())),
    );
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(find.text('Dough'), findsOneWidget);
  });

  testWidgets('every route builds', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PizzalatorApp()));
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    for (final r in [
      Routes.ferment,
      Routes.recipe,
      Routes.timers,
      Routes.routine,
      Routes.flours,
      Routes.recipes,
      Routes.bakeLog,
      Routes.logEntry,
    ]) {
      unawaited(nav.pushNamed(r));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: r);
      nav.pop();
      await tester.pumpAndSettle();
    }
  });

  group('launch', () {
    late MemoryStore store;
    late FakeLiveTimer live;
    late ProviderContainer c;
    final now = DateTime.now();

    setUp(() {
      store = MemoryStore();
      live = FakeLiveTimer();
      c = ProviderContainer.test(
        overrides: [
          jsonStoreProvider.overrideWithValue(store),
          liveTimerProvider.overrideWithValue(live),
        ],
      );
    });

    void saveRun() => store.data[timerRunStoreName] = jsonDecode(
      jsonEncode(
        TimerRun(
          steps: const [
            RoutineStep(name: 'Rest', kind: StepKind.rest, minutes: 30),
            RoutineStep(name: 'Fold', kind: StepKind.active, minutes: 2),
          ],
          endsAt: now.add(const Duration(minutes: 20)),
        ).toJson(),
      ),
    );

    test('bootstrap brings back the routine and the run', () async {
      store.data[routineStoreName] = {
        'presets': [defaultRoutine.toJson()..['name'] = 'Mine'],
        'selected': 1,
      };
      store.data[floursStoreName] = [
        const Flour('Doves strong', 13.5).toJson(),
      ];
      store.data[bakesStoreName] = [
        BakeEntry(
          id: 'b',
          date: DateTime.utc(2026, 10, 17),
          name: 'Friday NY',
          inputs: const RecipeInputs(style: PizzaStyle.newYork),
          oven: OvenSetup.homeSteel,
        ).toJson(),
      ];
      store.data[hintsStoreName] = ['dough0:b'];
      saveRun();
      GoogleFonts.config.allowRuntimeFetching = true;
      await bootstrap(c);
      // Fonts come from the bundle only (FR8: no network).
      expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
      expect(c.read(routineProvider).current.name, 'Mine');
      expect(c.read(customFloursProvider).single.name, 'Doves strong');
      expect(c.read(bakeLogProvider).single.name, 'Friday NY');
      expect(c.read(hintDismissalsProvider), {'dough0:b'});
      expect(c.read(timerRunProvider)!.step.name, 'Rest');
      expect(live.stops, 1, reason: 'the notification is taken back');
    });

    test('bootstrap never throws: a failing save or bad file', () async {
      saveRun();
      store.data[routineStoreName] = [1, 2];
      store.data[floursStoreName] = 'junk';
      store.data[recipesStoreName] = 'junk';
      store.data[bakesStoreName] = 'junk';
      store.data[hintsStoreName] = 'junk';
      store.data[currentStoreName] = [1];
      store.failWrites = const FileSystemException('No space left on device');
      await bootstrap(c);
      expect(c.read(timerRunProvider), isNotNull);
      expect(c.read(routineProvider).presets, [defaultRoutine]);
      expect(c.read(customFloursProvider), isEmpty);
      expect(c.read(savedRecipesProvider), isEmpty);
      expect(c.read(bakeLogProvider), isEmpty);
      expect(c.read(hintDismissalsProvider), isEmpty);
      expect(c.read(recipeProvider).style, PizzaStyle.neapolitan);
      // Saving the working copy fails quietly too.
      c.read(recipeProvider.notifier).setFlourG(600);
      await pumpEventQueue();
    });

    test(
      'bootstrap opens on the last-used recipe, then keeps it saved',
      () async {
        final friday = SavedRecipe(
          id: 'f',
          name: 'Friday NY',
          inputs: const RecipeInputs(style: PizzaStyle.newYork),
          oven: OvenSetup.homeStone,
          savedAt: DateTime.utc(2026, 10, 17),
        );
        Object? wire(Object? json) => jsonDecode(jsonEncode(json));
        store.data[recipesStoreName] = wire([friday.toJson()]);
        store.data[currentStoreName] = wire({
          'inputs': inputsToJson(friday.inputs),
          'oven': ovenToJson(friday.oven),
          'activeId': 'f',
        });
        await bootstrap(c);
        expect(c.read(recipeProvider).style, PizzaStyle.newYork);
        expect(c.read(ovenProvider).surface, Surface.stone);
        expect(c.read(activeRecipeProvider)!.name, 'Friday NY');
        expect(c.read(recipeDirtyProvider), isFalse);

        Map<Object?, Object?> current() =>
            store.data[currentStoreName]! as Map<Object?, Object?>;
        c.read(recipeProvider.notifier).setFlourG(600);
        await pumpEventQueue();
        expect((current()['inputs']! as Map)['flourG'], 600);
        c.read(ovenProvider.notifier).set(OvenSetup.outdoor);
        await pumpEventQueue();
        expect((current()['oven']! as Map)['kind'], 'outdoor');
        c.read(activeRecipeIdProvider.notifier).set(null);
        await pumpEventQueue();
        expect(current()['activeId'], isNull);
      },
    );

    test('no bootstrap, no saving of the working copy', () async {
      c.read(recipeProvider.notifier).setFlourG(600);
      await pumpEventQueue();
      expect(store.data, isEmpty);
    });

    testWidgets('a live run opens on the timers; back lands on the dough', (
      tester,
    ) async {
      saveRun();
      await tester.runAsync(() => bootstrap(c));
      await tester.pumpWidget(
        UncontrolledProviderScope(container: c, child: const PizzalatorApp()),
      );
      // The rest ring breathes: pump, never settle, while it is up.
      await tester.pump();
      expect(find.text('Dough routine'), findsOneWidget);
      await tester.tap(find.text('Recipe'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Plan fermentation'), findsOneWidget);
    });
  });

  group('live notification', () {
    late DateTime now;
    late MemoryStore store;
    late FakeLiveTimer live;
    late ProviderContainer c;
    const rest = RoutineStep(name: 'Rest', kind: StepKind.rest, minutes: 30);
    const fold = RoutineStep(name: 'Fold', kind: StepKind.active, minutes: 2);

    setUp(() {
      now = DateTime(2026, 6, 10, 9);
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

    DateTime at(int minutes) => now.add(Duration(minutes: minutes));

    /// What Android reports going to the background and coming back.
    const away = [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ];
    const back = [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ];

    void lifecycle(WidgetTester tester, List<AppLifecycleState> states) {
      for (final s in states) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
    }

    Future<void> pumpApp(WidgetTester tester) async {
      // The listener is gone by then; later tests start resumed.
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(container: c, child: const PizzalatorApp()),
      );
    }

    /// A run as if saved, brought back as on launch.
    Future<void> put(TimerRun? r) async {
      store.data[timerRunStoreName] = jsonDecode(jsonEncode(r?.toJson()));
      await c.read(timerRunProvider.notifier).restore();
    }

    testWidgets('hidden, the notification has the run; back, it replays', (
      tester,
    ) async {
      await pumpApp(tester);
      await put(TimerRun(steps: const [rest, fold], endsAt: at(30)));
      lifecycle(tester, away);
      await tester.pump();
      expect(live.shown!.legs.first.first.title, 'Rest');
      live.log.add(LiveAction(LiveTap.pause, at(10)));
      now = at(20);
      lifecycle(tester, back);
      await tester.pump();
      expect(live.shown, isNull);
      expect(c.read(timerRunProvider)!.left, const Duration(minutes: 20));
      // The shade pulled down: still on screen, no notification.
      lifecycle(tester, const [AppLifecycleState.inactive]);
      await tester.pump();
      expect(live.shown, isNull);
    });

    testWidgets('a timer end dings once, on any screen', (tester) async {
      await pumpApp(tester);
      expect(find.text('Dough'), findsOneWidget, reason: 'the calculator');
      await put(TimerRun(steps: const [rest, fold], endsAt: at(1)));
      await tester.pump(const Duration(seconds: 1));
      expect(live.chimes, 0);
      now = at(1);
      await tester.pump(const Duration(seconds: 1));
      expect(live.chimes, 1);
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(live.chimes, 1);
      // Hidden, the notification rings instead.
      await put(TimerRun(steps: const [rest, fold], endsAt: at(1)));
      lifecycle(tester, away);
      now = at(2);
      await tester.pump(const Duration(seconds: 2));
      expect(live.chimes, 1);
      // Ended: no run, no ticks.
      lifecycle(tester, back);
      await tester.pump();
      await c.read(timerRunProvider.notifier).stop();
      await tester.pump(const Duration(seconds: 2));
      expect(live.chimes, 1);
    });
  });

  group('real flow', () {
    late MemoryStore store;
    late FakeLiveTimer live;
    late ProviderContainer c;

    setUp(() {
      store = MemoryStore();
      live = FakeLiveTimer();
      c = ProviderContainer.test(
        overrides: [
          jsonStoreProvider.overrideWithValue(store),
          liveTimerProvider.overrideWithValue(live),
        ],
      );
    });

    Future<void> pumpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: c, child: const PizzalatorApp()),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tap(WidgetTester tester, String text) async {
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: text);
    }

    testWidgets('calculator → ferment → recipe → timers → routine and back', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(find.text('Dough'), findsOneWidget);

      await tap(tester, 'Plan fermentation');
      expect(find.text('Fermentation'), findsOneWidget);
      await tap(tester, 'Build recipe');
      expect(find.text('Recipe'), findsOneWidget);
      await tap(tester, 'Start dough timers');
      expect(find.text('Dough routine'), findsOneWidget);

      // Starting the run goes through the fake store and notification.
      await tap(tester, 'Start');
      expect(c.read(timerRunProvider), isNotNull);
      expect(store.data[timerRunStoreName], isNotNull);
      expect(live.asks, 1);

      await tap(tester, 'Edit routine');
      expect(find.text('Routine'), findsOneWidget);
      await tap(tester, 'Add step');
      expect(c.read(routineProvider).current.steps.last.name, 'New step');
      expect(store.data, contains('routines'));

      await tap(tester, 'Timers');
      expect(find.text('Dough routine'), findsOneWidget);
      await tap(tester, 'Recipe');
      expect(find.text('Open dough timers'), findsOneWidget);
      await tap(tester, 'Fermentation');
      expect(find.text('Build recipe'), findsOneWidget);
      await tap(tester, 'Calculator');
      expect(find.text('Dough'), findsOneWidget);
      expect(find.text('Plan fermentation'), findsOneWidget);

      // Settings › Flours off the flour card, a preset copied, and back.
      await tap(tester, 'Manage flours · scan a bag');
      expect(find.text('Flours'), findsOneWidget);
      await tap(tester, 'US bread flour');
      await tester.enterText(find.byKey(const ValueKey('name')), 'KA bread');
      await tester.pump();
      await tap(tester, 'Save flour');
      expect(store.data[floursStoreName], hasLength(1));
      await tap(tester, 'Calculator');
      expect(find.text('Plan fermentation'), findsOneWidget);

      // Saved recipes off the header: keep this one, open it again.
      await tester.tap(find.byTooltip('Saved recipes'));
      await tester.pumpAndSettle();
      expect(find.text('Recipes'), findsOneWidget);
      await tap(tester, 'Save current as new');
      await tester.enterText(find.byType(TextField), 'Friday NY');
      await tap(tester, 'Save recipe');
      expect(store.data[recipesStoreName], hasLength(1));
      await tap(tester, 'Friday NY');
      expect(find.text('Plan fermentation'), findsOneWidget);
      expect(find.text('Friday NY'), findsOneWidget);

      // An edit marks it; Save changes on the Recipe screen clears the mark.
      await tap(tester, 'Detroit');
      expect(find.text('Friday NY · edited'), findsOneWidget);
      await tap(tester, 'Plan fermentation');
      await tap(tester, 'Build recipe');
      await tester.ensureVisible(find.text('Save changes'));
      await tap(tester, 'Save changes');
      final saved = find.widgetWithText(SecondaryButton, 'Saved');
      expect(tester.widget<SecondaryButton>(saved).onPressed, isNull);
      expect(
        c.read(savedRecipesProvider).single.inputs.style,
        PizzaStyle.detroit,
      );
      await tester.ensureVisible(find.text('Fermentation'));
      await tap(tester, 'Fermentation');
      await tap(tester, 'Calculator');
      expect(find.text('Friday NY'), findsOneWidget);
      expect(find.text('Friday NY · edited'), findsNothing);

      // Recipes again, left by its own back link.
      await tester.tap(find.byTooltip('Saved recipes'));
      await tester.pumpAndSettle();
      await tap(tester, 'Calculator');
      expect(find.text('Plan fermentation'), findsOneWidget);

      // The bake log off the header: log this one, see it, edit it.
      await tester.tap(find.byTooltip('Bake log'));
      await tester.pumpAndSettle();
      expect(find.text('0 BAKES'), findsOneWidget);
      await tester.tap(find.byTooltip('Log a bake'));
      await tester.pumpAndSettle();
      expect(find.text('Log this bake'), findsOneWidget);
      await tester.tap(find.byTooltip('4 stars'));
      await tap(tester, 'Save bake');
      expect(find.text('1 BAKE'), findsOneWidget);
      expect(store.data[bakesStoreName], hasLength(1));
      await tap(tester, 'Friday NY');
      expect(find.text('Edit bake'), findsOneWidget);
      await tap(tester, 'Bake log');
      await tap(tester, 'Calculator');
      expect(find.text('Plan fermentation'), findsOneWidget);

      // And from the recipe's bake card: back lands on the log.
      await tap(tester, 'Plan fermentation');
      await tap(tester, 'Build recipe');
      await tap(tester, 'Bake card');
      await tester.ensureVisible(find.text('Log this bake'));
      await tap(tester, 'Log this bake');
      expect(find.text('Save bake'), findsOneWidget);
      await tap(tester, 'Save bake');
      expect(find.text('2 BAKES'), findsOneWidget);
      // System Back goes where the header's "Calculator" does.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Plan fermentation'), findsOneWidget);
    });

    testWidgets('two "too wet" bakes → a hint → Apply lowers hydration', (
      tester,
    ) async {
      await pumpApp(tester);
      final before = c.read(outputsProvider).hydrationPct;
      await tester.tap(find.byTooltip('Bake log'));
      await tester.pumpAndSettle();
      for (final n in [1, 2]) {
        await tester.tap(find.byTooltip('Log a bake'));
        await tester.pumpAndSettle();
        await tap(tester, 'too wet');
        await tester.ensureVisible(find.text('Save bake'));
        await tap(tester, 'Save bake');
        expect(find.text('$n ${n == 1 ? 'BAKE' : 'BAKES'}'), findsOneWidget);
        // One log is not enough.
        expect(find.text('Apply −2 pp'), n == 1 ? findsNothing : findsOne);
      }
      expect(
        find.textContaining('Suggest hydration ${pctText(before)}%'),
        findsOneWidget,
      );
      await tap(tester, 'Apply −2 pp');
      expect(c.read(outputsProvider).hydrationPct, r01(before - 2));
      expect(find.text('Apply −2 pp'), findsNothing);
      // Gone on the recipe too: no bakes at the new hydration yet.
      await tap(tester, 'Calculator');
      await tap(tester, 'Plan fermentation');
      await tap(tester, 'Build recipe');
      expect(find.textContaining('Calibration hint'), findsNothing);
      expect(find.text(pctText(r01(before - 2))), findsOneWidget);
    });

    testWidgets('calculator, ferment and recipe show the same numbers', (
      tester,
    ) async {
      await pumpApp(tester);
      await tap(tester, 'New York');
      final o = c.read(outputsProvider);
      Line line(String name) => o.finalDough.firstWhere((l) => l.name == name);
      final yeast = line('IDY');
      final shared = [
        '${o.totalFlourG.round()} g',
        for (final n in ['Water', 'Salt', 'IDY', 'Oil', 'Sugar'])
          gramsText(line(n)),
      ];
      void expectAll(List<String> texts, String screen) {
        for (final s in texts) {
          expect(find.text(s), findsWidgets, reason: '$screen: $s');
        }
      }

      expectAll([...shared, pctText(o.hydrationPct)], 'calculator');

      await tap(tester, 'Plan fermentation');
      expectAll([
        yeast.grams.toStringAsFixed(yeast.decimals),
        'g · ${yeast.pct.toStringAsFixed(2)}% of flour',
      ], 'ferment');

      await tap(tester, 'Build recipe');
      expectAll([
        ...shared,
        pctText(o.hydrationPct),
        pctOfFlour(line('Water')),
      ], 'recipe');
      expect(
        find.textContaining('New York · ${o.ballCount} × 35 cm'),
        findsOneWidget,
      );

      // A poolish: Ferment's split and Recipe's two tables add up to the
      // calculator's whole-recipe totals.
      await tap(tester, 'Fermentation');
      await tap(tester, 'Poolish');
      final p = c.read(outputsProvider);
      Line of(List<Line> ls, String n) => ls.firstWhere((l) => l.name == n);
      final prefWater = of(p.preferment, 'Water').grams;
      final finalWater = of(p.finalDough, 'Water').grams;
      final prefFlour = of(p.preferment, 'Flour').grams;
      expectAll([
        '${prefFlour.round()} g flour',
        '${prefWater.round()} g water',
        '${(p.totalFlourG - prefFlour).round()} g flour',
        '${finalWater.round()} g water',
      ], 'ferment split');

      await tap(tester, 'Build recipe');
      expectAll([
        for (final l in p.preferment) gramsText(l),
      ], 'recipe preferment');
      await tap(tester, 'Dough');
      expectAll([for (final l in p.finalDough) gramsText(l)], 'recipe final');

      await tap(tester, 'Fermentation');
      await tap(tester, 'Calculator');
      final idy = of(p.preferment, 'IDY').grams + of(p.finalDough, 'IDY').grams;
      expectAll([
        '${(prefWater + finalWater).round()} g',
        '${idy.toStringAsFixed(2)} g',
        gramsText(of(p.finalDough, 'Salt')),
      ], 'calculator totals');
    });
  });
}
