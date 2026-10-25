import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pizzalator/core/bake_log.dart';
import 'package:pizzalator/core/calc.dart';
import 'package:pizzalator/core/export_text.dart';
import 'package:pizzalator/core/oven.dart';
import 'package:pizzalator/routes.dart';
import 'package:pizzalator/screens/recipe.dart';
import 'package:pizzalator/state/bake_log.dart';
import 'package:pizzalator/state/calibration.dart';
import 'package:pizzalator/state/oven.dart';
import 'package:pizzalator/state/recipe.dart';
import 'package:pizzalator/state/recipes.dart';
import 'package:pizzalator/services/json_store.dart';
import 'package:pizzalator/services/live_timer.dart';
import 'package:pizzalator/state/schedule.dart';
import 'package:pizzalator/state/timer_run.dart';
import 'package:pizzalator/state/units.dart';
import 'package:pizzalator/theme/pizza_theme.dart';
import 'package:pizzalator/widgets/widgets.dart';

import '../fakes.dart';

late ProviderContainer c;

/// The test clock: a Wednesday morning, clear of DST changes.
var now = DateTime(2026, 6, 10, 10);

/// Recipe pushed over a home page so the back link has somewhere to go.
Future<void> pump(
  WidgetTester tester, {
  double scale = 1,
  bool reduce = false,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: pizzaTheme(Brightness.dark),
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduce,
          ),
          child: app!,
        ),
        initialRoute: Routes.recipe,
        routes: {
          Routes.calculator: (_) => const Text('Home page'),
          // Non-const so the constructor itself runs under coverage.
          Routes.recipe: (_) => RecipeScreen(key: UniqueKey()),
          Routes.timers: (_) => const Text('Timers page'),
          Routes.bakeLog: (_) => const Text('Bake log page'),
          Routes.logEntry: (_) => const Text('Log entry page'),
        },
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

void recipe(RecipeInputs Function(RecipeInputs) change) =>
    c.read(recipeProvider.notifier).update(change);

Future<void> tapTab(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 100, scrollable: find.byType(Scrollable));
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    now = DateTime(2026, 6, 10, 10);
    c = ProviderContainer.test(
      overrides: [
        clockProvider.overrideWithValue(() => now),
        jsonStoreProvider.overrideWithValue(MemoryStore()),
      ],
    );
  });

  testWidgets('header: summary, hydration, back to Fermentation', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Recipe'), findsOneWidget);
    expect(
      find.text('Neapolitan · 7 × 30 cm · UK strong white · steel'),
      findsOneWidget,
    );
    expect(find.text('62.5'), findsOneWidget);
    expect(find.text('HYDRATION'), findsOneWidget);

    await tester.tap(find.text('Fermentation'));
    await tester.pumpAndSettle();
    expect(find.text('Home page'), findsOneWidget);
  });

  testWidgets('ingredients tick off with a counter', (tester) async {
    await pump(tester);
    expect(find.text('Preferment'), findsNothing);
    expect(find.text('Ingredients'), findsOneWidget);
    expect(find.text('FINAL DOUGH'), findsOneWidget);
    for (final s in [
      'UK strong white',
      '1000 g',
      '100%',
      'Water',
      '625 g',
      '62.5%',
      'Salt',
      '28.0 g',
      'Instant yeast',
      '3.00 g',
      '0.3%',
    ]) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    expect(find.text('0 / 4 ADDED'), findsOneWidget);

    await tester.tap(find.text('Water'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 4 ADDED'), findsOneWidget);
    final water = tester.widget<Text>(find.text('Water'));
    expect(water.style?.decoration, TextDecoration.lineThrough);
    await tester.tap(find.text('Salt'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 4 ADDED'), findsOneWidget);
    await tester.tap(find.text('Water'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 4 ADDED'), findsOneWidget);
  });

  double roomC() => StagePlan.of(c.read(recipeProvider).activePlan).roomC;

  testWidgets('water temperature: editable temps and mixing', (tester) async {
    await pump(tester);
    expect(find.text('30 °C'), findsOneWidget);
    expect(
      find.text('for 24 °C dough · flour 20 °C · room 20 °C · hand mix'),
      findsOneWidget,
    );

    await tapVisible(tester, find.bySemanticsLabel('More flour temp'));
    expect(c.read(bakeSetupProvider).flourC, 21);
    expect(find.text('29 °C'), findsOneWidget);
    // One kitchen: the room temp is the plan's, as on Fermentation.
    await tapVisible(tester, find.bySemanticsLabel('Less room temp'));
    expect(roomC(), 19);
    expect(c.read(recipeProvider).activePlan.first, const Stage(2, 19));
    await tapVisible(tester, find.bySemanticsLabel('Less flour temp'));
    await tapVisible(tester, find.bySemanticsLabel('More room temp'));
    expect(find.text('30 °C'), findsOneWidget);

    await tapVisible(tester, find.text('Mixer'));
    expect(c.read(bakeSetupProvider).mixer, isTrue);
    expect(find.text('26 °C'), findsOneWidget);
    expect(
      find.text('for 24 °C dough · flour 20 °C · room 20 °C · mixer'),
      findsOneWidget,
    );
    await tapVisible(tester, find.text('Hand'));
    expect(c.read(bakeSetupProvider).mixer, isFalse);
  });

  testWidgets('steppers stop at the kitchen range', (tester) async {
    c.read(bakeSetupProvider.notifier).setFlourC(kKitchenMaxC);
    c.read(recipeProvider.notifier).setRoomC(StagePlan.roomMinC);
    await pump(tester);
    await tapVisible(tester, find.bySemanticsLabel('More flour temp'));
    await tapVisible(tester, find.bySemanticsLabel('Less room temp'));
    expect(c.read(bakeSetupProvider).flourC, kKitchenMaxC);
    expect(roomC(), StagePlan.roomMinC);
  });

  testWidgets('a fridge-only plan has no room temp to set', (tester) async {
    recipe((i) => i.copyWith(plan: const [Stage(48, 4)]));
    await pump(tester);
    await tester.scrollUntilVisible(
      find.bySemanticsLabel('More room temp'),
      100,
      scrollable: find.byType(Scrollable),
    );
    final more = tester.widget<StepButton>(
      find.byWidgetPredicate(
        (w) => w is StepButton && w.semanticLabel == 'More room temp',
      ),
    );
    expect(more.onPressed, isNull);
  });

  testWidgets('yield and total dough', (tester) async {
    await pump(tester);
    await tester.scrollUntilVisible(
      find.text('TOTAL DOUGH'),
      100,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('YIELD'), findsOneWidget);
    expect(find.text('7 balls · 237 g'), findsOneWidget);
    expect(find.text('1656 g'), findsOneWidget);
  });

  testWidgets('preferment gets its own tab and counter', (tester) async {
    recipe((i) => i.copyWith(preferment: Preferment.poolish));
    await pump(tester);
    // Four short tabs: they fit one line at large text sizes.
    for (final tab in ['Poolish', 'Dough', 'Times', 'Bake']) {
      expect(find.text(tab), findsOneWidget, reason: tab);
    }
    expect(find.text('Ingredients'), findsNothing);
    // Opens on the preferment: it is made first.
    expect(find.text('POOLISH'), findsOneWidget);
    expect(find.text('0 / 3 ADDED'), findsOneWidget);
    expect(find.text('300 g'), findsNWidgets(2));
    expect(find.text('29 °C'), findsNothing);
    await tester.tap(find.text('Flour'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3 ADDED'), findsOneWidget);

    await tapTab(tester, 'Dough');
    expect(find.text('FINAL DOUGH'), findsOneWidget);
    expect(find.text('0 / 4 ADDED'), findsOneWidget);
    expect(find.text('700 g'), findsOneWidget);
    // 4-factor water temperature with the poolish at 20 °C.
    expect(find.text('34 °C'), findsOneWidget);

    await tapTab(tester, 'Poolish');
    expect(find.text('1 / 3 ADDED'), findsOneWidget);
    // Dropping the preferment falls back to the dough tab.
    recipe((i) => i.copyWith(preferment: Preferment.none));
    await tester.pumpAndSettle();
    expect(find.text('Poolish'), findsNothing);
    expect(find.text('FINAL DOUGH'), findsOneWidget);
  });

  group('schedule', () {
    testWidgets('relative times until a bake time is set', (tester) async {
      await pump(tester);
      await tapTab(tester, 'Schedule');
      expect(find.text('BAKE TIME NOT SET'), findsOneWidget);
      expect(find.text('Mix + dough routine'), findsOneWidget);
      expect(find.text('Timers run it: 1 h 54.'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('+1 h 54'), findsOneWidget);
      expect(find.text('Fridge'), findsOneWidget);
      expect(find.text('Bake'), findsOneWidget);
    });

    testWidgets('date then time picker fills absolute times', (tester) async {
      await pump(tester);
      await tapTab(tester, 'Schedule');
      await tester.tap(find.text('Set bake time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // From the clock provider, not the wall clock: no midnight flakes.
      final at = DateTime(2026, 6, 11, 19);
      expect(c.read(bakeSetupProvider).bakeAt, at);
      expect(find.text('BAKE ${clockText(at).toUpperCase()}'), findsOneWidget);
      expect(find.text(clockText(at)), findsOneWidget);
      expect(find.text('Start'), findsNothing);

      // Reopening starts from the chosen time.
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(c.read(bakeSetupProvider).bakeAt, at);
    });

    testWidgets('cancelling either picker keeps the bake time', (tester) async {
      await pump(tester);
      await tapTab(tester, 'Schedule');
      await tester.tap(find.text('Set bake time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(c.read(bakeSetupProvider).bakeAt, isNull);

      await tester.tap(find.text('Set bake time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(c.read(bakeSetupProvider).bakeAt, isNull);
    });

    testWidgets('a bake time in the past reopens on tomorrow', (tester) async {
      c.read(bakeSetupProvider.notifier).setBakeAt(DateTime(2020, 1, 1, 12));
      await pump(tester);
      await tapTab(tester, 'Schedule');
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(c.read(bakeSetupProvider).bakeAt, DateTime(2026, 6, 11, 19));
    });

    testWidgets('preferment, bulk, fridge and warm-up rows', (tester) async {
      recipe(
        (i) => i.copyWith(
          preferment: Preferment.poolish,
          plan: const [Stage(1, 21), Stage(48, 4), Stage(2, 21)],
        ),
      );
      await pump(tester);
      await tapTab(tester, 'Times');
      for (final s in [
        'Mix poolish',
        'Bulk in container',
        'Fridge',
        'Divide into balls',
        'Warm up',
      ]) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
    });

    Color dot(WidgetTester tester, String name) {
      final row = find.ancestor(
        of: find.text(name),
        matching: find.byType(IntrinsicHeight),
      );
      final box = tester
          .widgetList<Container>(
            find.descendant(of: row, matching: find.byType(Container)),
          )
          .firstWhere(
            (w) => (w.decoration as BoxDecoration?)?.shape == BoxShape.circle,
          );
      return (box.decoration! as BoxDecoration).color!;
    }

    testWidgets('dots show where you are: past sage, now ember, next grey', (
      tester,
    ) async {
      // Neapolitan: mix 1 h 54, bulk 2 h, fridge 24 h, divide 5 min.
      final bake = DateTime(2026, 6, 11, 19);
      c.read(bakeSetupProvider.notifier).setBakeAt(bake);
      now = DateTime(2026, 6, 10, 17); // in the bulk
      await pump(tester, settle: false);
      await tester.pump(const Duration(seconds: 1));
      // The current dot pulses for ever: pump, never settle.
      await tester.tap(find.text('Schedule'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final k = PizzaColors.dark;
      expect(dot(tester, 'Mix + dough routine'), k.sage);
      expect(dot(tester, 'Bulk in container'), k.ember);
      expect(dot(tester, 'Fridge'), k.lineStrong);
      expect(dot(tester, 'Bake'), k.lineStrong);
      // It pulses, unless motion is reduced.
      await tester.pump(const Duration(milliseconds: 800));
      final pulse = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byWidgetPredicate(
                (w) =>
                    w is Container &&
                    (w.decoration as BoxDecoration?)?.color == k.ember &&
                    (w.decoration as BoxDecoration?)?.shape == BoxShape.circle,
              ),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(pulse.opacity.value, lessThan(1));
    });

    testWidgets('reduced motion: the current dot holds still', (tester) async {
      c.read(bakeSetupProvider.notifier).setBakeAt(DateTime(2026, 6, 11, 19));
      now = DateTime(2026, 6, 10, 17);
      await pump(tester, reduce: true);
      await tapTab(tester, 'Schedule');
      expect(dot(tester, 'Bulk in container'), PizzaColors.dark.ember);
    });

    testWidgets('no bake time: every dot is upcoming', (tester) async {
      await pump(tester);
      await tapTab(tester, 'Schedule');
      for (final s in ['Mix + dough routine', 'Fridge', 'Bake']) {
        expect(dot(tester, s), PizzaColors.dark.lineStrong, reason: s);
      }
    });
  });

  testWidgets('bake card and why these numbers', (tester) async {
    await pump(tester);
    await tapTab(tester, 'Bake card');
    expect(find.text('HOME OVEN · STEEL'), findsOneWidget);
    expect(find.text('Max 275 °C · 2nd rack from top'), findsOneWidget);
    expect(
      find.text('Preheat steel 45–60 min at max, fan off.'),
      findsOneWidget,
    );
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('5.'), findsOneWidget);
    expect(find.text('WHY THESE NUMBERS'), findsOneWidget);
    expect(
      find.text(
        whyTheseNumbers(
          c.read(recipeProvider),
          c.read(outputsProvider),
          OvenSetup.homeSteel,
        ),
      ),
      findsOneWidget,
    );

    c.read(ovenProvider.notifier).set(OvenSetup.outdoor);
    await tester.pumpAndSettle();
    expect(find.text('OUTDOOR OVEN'), findsOneWidget);
  });

  testWidgets('log this bake: the entry, over the bake log', (tester) async {
    await pump(tester);
    expect(find.text('Log this bake'), findsNothing);
    await tapTab(tester, 'Bake card');
    await tapVisible(tester, find.text('Log this bake'));
    expect(find.text('Log entry page'), findsOneWidget);
    // Back from the entry lands on the log, where the new bake shows.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.text('Bake log page'), findsOneWidget);
    // And Back from the log goes home, as its header link says.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Home page'), findsOneWidget);
  });

  testWidgets('copy as plain text, with a toast', (tester) async {
    final clipboard = FakeClipboard()..install(tester);
    await pump(tester);
    await tapVisible(tester, find.text('Copy as text'));
    expect(find.text('Recipe copied'), findsOneWidget);
    expect(
      clipboard.text,
      recipeText(
        inputs: c.read(recipeProvider),
        outputs: c.read(outputsProvider),
        oven: c.read(ovenProvider),
        schedule: c.read(scheduleProvider),
        water: c.read(waterTempProvider),
      ),
    );
    expect(clipboard.text, startsWith('Neapolitan · 7 × 30 cm'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // The calculator's cm / in toggle carries over to the header and copy.
    c.read(lengthUnitProvider.notifier).toggle();
    await tester.pumpAndSettle();
    expect(find.textContaining('7 × 11.8 in · '), findsOneWidget);
    await tapVisible(tester, find.text('Copy as text'));
    expect(clipboard.text, startsWith('Neapolitan · 7 × 11.8 in'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('save recipe: a name first; then Saved until edited', (
    tester,
  ) async {
    bool enabled(String label) => tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, label))
        .enabled;
    await pump(tester);
    expect(find.text('Recipe'), findsOneWidget);
    await tapVisible(tester, find.text('Save recipe'));
    // Backing out saves nothing.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(c.read(savedRecipesProvider), isEmpty);

    await tapVisible(tester, find.text('Save recipe'));
    await tester.enterText(find.byType(TextField), 'Friday NY');
    await tester.tap(find.text('Save recipe').last);
    await tester.pumpAndSettle();
    // The header takes the recipe's name.
    expect(find.text('Friday NY'), findsOneWidget);
    expect(find.text('Recipe'), findsNothing);
    expect(enabled('Saved'), isFalse);

    recipe((i) => i.copyWith(flourG: 600));
    await tester.pumpAndSettle();
    expect(enabled('Save changes'), isTrue);
    await tapVisible(tester, find.text('Save changes'));
    expect(enabled('Saved'), isFalse);
    expect(c.read(activeRecipeProvider)!.inputs.flourG, 600);
  });

  testWidgets('primary CTA starts the dough timers', (tester) async {
    await pump(tester);
    final cta = find.widgetWithText(FilledButton, 'Start dough timers');
    expect(tester.getSize(cta).height, 56);
    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(find.text('Timers page'), findsOneWidget);
  });

  testWidgets('a live run: the CTA opens it instead', (tester) async {
    c = ProviderContainer.test(
      overrides: [
        clockProvider.overrideWithValue(() => now),
        jsonStoreProvider.overrideWithValue(MemoryStore()),
        liveTimerProvider.overrideWithValue(FakeLiveTimer()),
      ],
    );
    await tester.runAsync(() => c.read(timerRunProvider.notifier).start());
    await pump(tester);
    expect(find.text('Open dough timers'), findsOneWidget);
    expect(find.text('Start dough timers'), findsNothing);
  });

  testWidgets('ingredient rows grow with large text, grams never clip', (
    tester,
  ) async {
    await pump(tester, scale: 1.75);
    // One line of grams (15 px × 1.75 at a 20 px line), never wrapped and
    // cut off by a fixed row height.
    final grams = tester.getSize(find.text('625 g'));
    expect(grams.height, lessThanOrEqualTo(20 * 1.75 + 0.5));
    final row = find.ancestor(
      of: find.text('625 g'),
      matching: find.byWidgetPredicate(
        (w) => w is ConstrainedBox && w.constraints.minHeight == 48,
      ),
    );
    expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
  });

  testWidgets('no log-bake entry point yet', (tester) async {
    await pump(tester);
    expect(find.text('Log this bake'), findsNothing);
  });

  group('calibration hint', () {
    Future<void> twoBakes(Map<Outcome, int> outcomes) async {
      for (final id in ['a', 'b']) {
        await c
            .read(bakeLogProvider.notifier)
            .add(
              BakeEntry(
                id: id,
                date: now,
                name: 'Bake',
                inputs: c.read(recipeProvider),
                oven: c.read(ovenProvider),
                outcomes: outcomes,
              ),
            );
      }
    }

    testWidgets('above the tab content; Apply edits the header too', (
      tester,
    ) async {
      await twoBakes(const {Outcome.dough: 2});
      final hyd = c.read(outputsProvider).hydrationPct;
      await pump(tester);
      expect(find.text('CALIBRATION HINT · NEAPOLITAN'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Not now')).dy,
        lessThan(tester.getTopLeft(find.text('FINAL DOUGH')).dy),
      );
      await tapTab(tester, 'Bake card');
      expect(find.text('Apply +2 pp'), findsOneWidget);
      await tester.tap(find.text('Apply +2 pp'));
      await tester.pumpAndSettle();
      expect(c.read(outputsProvider).hydrationPct, r01(hyd + 2));
      expect(find.text(pctText(r01(hyd + 2))), findsOneWidget);
      expect(find.textContaining('CALIBRATION HINT'), findsNothing);
    });

    testWidgets('Not now under reduced motion: gone at once, saved', (
      tester,
    ) async {
      await twoBakes(const {Outcome.proof: 0});
      await pump(tester, reduce: true);
      expect(find.text('Apply +15%'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pump();
      expect(find.textContaining('CALIBRATION HINT'), findsNothing);
      expect(c.read(hintDismissalsProvider), {'proof0:b'});
      expect(c.read(recipeProvider).yeastKnob, 1);
    });
  });
}
