import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pizzalator/core/presets.dart';
import 'package:pizzalator/core/routine.dart';
import 'package:pizzalator/screens/routine.dart';
import 'package:pizzalator/services/json_store.dart';
import 'package:pizzalator/state/recipe.dart';
import 'package:pizzalator/state/routine.dart';
import 'package:pizzalator/theme/pizza_theme.dart';
import 'package:pizzalator/widgets/widgets.dart';

import '../fakes.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late MemoryStore store;
  late ProviderContainer c;

  setUp(() {
    store = MemoryStore();
    c = ProviderContainer.test(
      overrides: [jsonStoreProvider.overrideWithValue(store)],
    );
  });

  RoutineState s() => c.read(routineProvider);
  List<RoutineStep> steps() => s().current.steps;
  List<String> names() => steps().map((x) => x.name).toList();

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: pizzaTheme(Brightness.dark),
          initialRoute: '/routine',
          routes: {
            '/': (_) => const Scaffold(body: Text('Timers page')),
            '/routine': (_) => const RoutineScreen(),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> outlastToast(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  Finder less(int i) => find.bySemanticsLabel('Less time').at(i);
  Finder more(int i) => find.bySemanticsLabel('More time').at(i);
  Finder resetButton() => find.ancestor(
    of: find.text('Reset to default routine'),
    matching: find.byType(OutlinedButton),
  );

  testWidgets('shows header total, presets and the default steps', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Routine'), findsOneWidget);
    expect(find.text('Timers'), findsOneWidget);
    expect(find.text('HANDS-ON + RESTS'), findsOneWidget);
    // 119 min of steps + the bound bulk: Neapolitan's 2 h room + 24 h fridge.
    expect(find.text('27 h 59'), findsOneWidget);
    expect(find.bySemanticsLabel('Hands-on and rests 27 h 59'), findsOneWidget);
    expect(find.text('My default'), findsOneWidget);
    expect(find.text('Mix all ingredients'), findsOneWidget);
    expect(find.text('Divide into balls'), findsOneWidget);
    expect(find.text('30 min'), findsNWidgets(2));
    expect(find.text('26 h'), findsOneWidget);
    expect(find.text('From the ferment plan'), findsOneWidget);
    expect(find.text('Covered rest · auto'), findsNWidgets(4));
    expect(find.text('Hands on · tap when done'), findsNWidgets(6));
    expect(find.text('Add step'), findsOneWidget);
    expect(tester.getSize(find.byType(PrimaryButton)).height, 56);
    expect(find.text('Save as preset'), findsOneWidget);
    // Nothing to reset on a clean default.
    expect(tester.widget<OutlinedButton>(resetButton()).onPressed, isNull);
    expect(
      tester.getSize(find.byType(IconButton).first).shortestSide,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('minus and plus step the minutes and persist', (tester) async {
    await pump(tester);
    await tap(tester, more(1));
    expect(steps()[1].minutes, 45);
    expect(find.text('45 min'), findsOneWidget);
    expect(find.text('28 h 14'), findsOneWidget);
    expect(store.data[routineStoreName], isNotNull);

    await tap(tester, less(1));
    expect(steps()[1].minutes, 30);

    // 5 → floored at 1, then minus is disabled.
    await tap(tester, less(0));
    expect(steps()[0].minutes, 1);
    expect(find.text('1 min'), findsOneWidget);
    await tap(tester, less(0));
    expect(steps()[0].minutes, 1);
    await tap(tester, more(0));
    expect(steps()[0].minutes, 6);

    // Long rests step by the hour.
    await c.read(routineProvider.notifier).setMinutes(1, 120);
    await tester.pumpAndSettle();
    expect(find.text('2 h'), findsOneWidget);
    await tap(tester, more(1));
    expect(find.text('3 h'), findsOneWidget);
    await tap(tester, less(1));
    expect(steps()[1].minutes, 120);
  });

  testWidgets('bound bulk step follows the plan, not the stepper', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, more(9));
    await tap(tester, less(9));
    expect(steps()[9].minutes, 240);
    expect(s().dirty, isFalse);

    c
        .read(recipeProvider.notifier)
        .update((i) => i.copyWith(plan: const [Stage(6, 20)]));
    await tester.pumpAndSettle();
    expect(find.text('6 h'), findsOneWidget);
    expect(find.text('7 h 59'), findsOneWidget);
  });

  testWidgets('kind toggles between rest and hands-on', (tester) async {
    await pump(tester);
    expect(find.byIcon(Icons.back_hand_outlined), findsNWidgets(6));
    final toggle = find.byTooltip('Toggle rest or hands-on').first;
    await tap(tester, toggle);
    expect(steps()[0].kind, StepKind.rest);
    expect(find.byIcon(Icons.back_hand_outlined), findsNWidgets(5));
    expect(find.byIcon(Icons.schedule), findsNWidgets(6));
    await tap(tester, toggle);
    expect(steps()[0].kind, StepKind.active);
  });

  testWidgets('move buttons reorder; edges do nothing', (tester) async {
    await pump(tester);
    final before = names();
    await tap(tester, find.byTooltip('Move up').first);
    await tap(tester, find.byTooltip('Move down').last);
    expect(s().dirty, isFalse);

    await tap(tester, find.byTooltip('Move down').first);
    expect(names().take(2), ['Rest in bowl, covered', 'Mix all ingredients']);
    await tap(tester, find.byTooltip('Move up').at(1));
    expect(names(), before);
  });

  testWidgets('remove deletes a row but keeps the last step', (tester) async {
    await pump(tester);
    await tap(tester, find.byTooltip('Remove step').first);
    expect(steps(), hasLength(10));
    expect(find.text('Mix all ingredients'), findsNothing);
    for (var i = 0; i < 10; i++) {
      await tap(tester, find.byTooltip('Remove step').first);
    }
    expect(names(), ['Divide into balls']);
  });

  testWidgets('add step appends a 15 min rest', (tester) async {
    await pump(tester);
    await tap(tester, find.text('Add step'));
    expect(steps(), hasLength(12));
    expect(steps().last.name, 'New step');
    expect(steps().last.kind, StepKind.rest);
    expect(steps().last.minutes, 15);
    expect(find.text('New step'), findsOneWidget);
  });

  testWidgets('tapping a step edits its name and note in a sheet', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, find.text('Knead on the counter'));
    expect(find.text('Edit step'), findsOneWidget);
    final fields = find.byType(TextField);
    expect(
      tester.widget<TextField>(fields.at(1)).controller!.text,
      'Timed active step',
    );
    await tester.enterText(fields.at(0), '  Slap and fold  ');
    await tester.enterText(fields.at(1), ' Until smooth ');
    await tap(tester, find.text('Save step'));
    expect(find.text('Edit step'), findsNothing);
    expect(steps()[6].name, 'Slap and fold');
    expect(steps()[6].note, 'Until smooth');
    expect(steps()[6].kind, StepKind.active);
    expect(steps()[6].minutes, 10);

    // A blank name keeps the old one.
    await tap(tester, find.text('Slap and fold'));
    await tester.enterText(find.byType(TextField).first, '   ');
    await tap(tester, find.text('Save step'));
    expect(steps()[6].name, 'Slap and fold');

    // Dismissing changes nothing.
    await tap(tester, find.text('Slap and fold'));
    await tester.enterText(find.byType(TextField).first, 'Gone');
    await tester.tapAt(const Offset(195, 20));
    await tester.pumpAndSettle();
    expect(find.text('Edit step'), findsNothing);
    expect(steps()[6].name, 'Slap and fold');
  });

  testWidgets('save as preset asks for a name, selects it, toasts', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, more(1));
    expect(s().dirty, isTrue);

    // Dismissed: nothing saved.
    await tap(tester, find.text('Save as preset'));
    await tester.tapAt(const Offset(195, 20));
    await tester.pumpAndSettle();
    expect(s().presets, hasLength(1));

    await tap(tester, find.text('Save as preset'));
    expect(find.text('e.g. Same-day NY'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Same-day NY');
    await tap(tester, find.text('Save preset'));
    expect(s().presets, hasLength(2));
    expect(s().selected, 1);
    expect(s().dirty, isFalse);
    expect(s().current.steps[1].minutes, 45);
    expect(find.text('Same-day NY'), findsOneWidget);
    expect(find.text('Preset "Same-day NY" saved'), findsOneWidget);
    await outlastToast(tester);
    expect(find.text('Preset "Same-day NY" saved'), findsNothing);

    // Blank name gets a numbered one.
    await tap(tester, find.text('Save as preset'));
    await tap(tester, find.text('Save preset'));
    expect(find.text('Preset "Routine 3" saved'), findsOneWidget);
    await outlastToast(tester);
  });

  testWidgets('preset chips switch the current routine', (tester) async {
    await pump(tester);
    await tap(tester, more(1));
    // Re-tapping the selected chip keeps the working copy.
    await tap(tester, find.text('My default'));
    expect(s().dirty, isTrue);

    await c.read(routineProvider.notifier).saveAsPreset('Cold');
    await tester.pumpAndSettle();
    await tap(tester, find.text('My default'));
    expect(s().selected, 0);
    expect(steps()[1].minutes, 30);
    await tap(tester, find.text('Cold'));
    expect(s().selected, 1);
    expect(steps()[1].minutes, 45);
  });

  testWidgets('reset restores the default with a toast', (tester) async {
    await pump(tester);
    await tap(tester, more(1));
    await tap(tester, resetButton());
    expect(s().dirty, isFalse);
    expect(s().selected, 0);
    expect(steps()[1].minutes, 30);
    expect(find.text('Default routine restored'), findsOneWidget);
    await outlastToast(tester);
  });

  testWidgets('back link returns to Timers', (tester) async {
    await pump(tester);
    await tap(tester, find.text('Timers'));
    expect(find.text('Timers page'), findsOneWidget);
    expect(find.byType(RoutineScreen), findsNothing);
  });
}
