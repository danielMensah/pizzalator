import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pizzalator/app.dart';
import 'package:pizzalator/core/calc.dart';
import 'package:pizzalator/core/export_text.dart';
import 'package:pizzalator/core/routine.dart';
import 'package:pizzalator/core/timer_run.dart';
import 'package:pizzalator/routes.dart';
import 'package:pizzalator/services/json_store.dart';
import 'package:pizzalator/services/notifications.dart';
import 'package:pizzalator/state/recipe.dart';
import 'package:pizzalator/state/routine.dart';
import 'package:pizzalator/state/timer_run.dart';

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
    late FakeNotifications notes;
    late ProviderContainer c;
    final now = DateTime.now();

    setUp(() {
      store = MemoryStore();
      notes = FakeNotifications();
      c = ProviderContainer.test(
        overrides: [
          jsonStoreProvider.overrideWithValue(store),
          notificationsProvider.overrideWithValue(notes),
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

    test('bootstrap brings back the routine and the run, alarms set', () async {
      store.data[routineStoreName] = {
        'presets': [defaultRoutine.toJson()..['name'] = 'Mine'],
        'selected': 1,
      };
      saveRun();
      await bootstrap(c);
      expect(c.read(routineProvider).current.name, 'Mine');
      expect(c.read(timerRunProvider)!.step.name, 'Rest');
      expect(notes.pending.values.single.title, 'Rest over');
    });

    test('bootstrap never throws: a failing save or bad file', () async {
      saveRun();
      store.data[routineStoreName] = [1, 2];
      store.failWrites = const FileSystemException('No space left on device');
      await bootstrap(c);
      expect(c.read(timerRunProvider), isNotNull);
      expect(c.read(routineProvider).presets, [defaultRoutine]);
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

  group('real flow', () {
    late MemoryStore store;
    late FakeNotifications notes;
    late ProviderContainer c;

    setUp(() {
      store = MemoryStore();
      notes = FakeNotifications();
      c = ProviderContainer.test(
        overrides: [
          jsonStoreProvider.overrideWithValue(store),
          notificationsProvider.overrideWithValue(notes),
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

      // Starting the run goes through the fake store and notifications.
      await tap(tester, 'Start');
      expect(c.read(timerRunProvider), isNotNull);
      expect(store.data[timerRunStoreName], isNotNull);
      expect(notes.asks, 1);

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
