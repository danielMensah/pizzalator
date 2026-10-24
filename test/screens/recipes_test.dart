import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pizzalator/core/calc.dart';
import 'package:pizzalator/core/export_text.dart';
import 'package:pizzalator/core/oven.dart';
import 'package:pizzalator/core/recipe_json.dart';
import 'package:pizzalator/routes.dart';
import 'package:pizzalator/screens/recipes.dart';
import 'package:pizzalator/services/json_store.dart';
import 'package:pizzalator/state/oven.dart';
import 'package:pizzalator/state/recipe.dart';
import 'package:pizzalator/state/recipes.dart';
import 'package:pizzalator/theme/pizza_theme.dart';
import 'package:pizzalator/widgets/widgets.dart';

import '../fakes.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late MemoryStore store;
  late ProviderContainer c;

  late FakeClipboard clip;

  setUp(() {
    store = MemoryStore();
    clip = FakeClipboard();
    c = ProviderContainer.test(
      overrides: [jsonStoreProvider.overrideWithValue(store)],
    );
  });

  List<SavedRecipe> saved() => c.read(savedRecipesProvider);
  List<String> names() => [for (final r in saved()) r.name];
  SavedRecipesNotifier n() => c.read(savedRecipesProvider.notifier);

  /// Saves the working copy as [name], after [change].
  Future<void> keep(
    String name, [
    RecipeInputs Function(RecipeInputs)? change,
  ]) async {
    if (change != null) c.read(recipeProvider.notifier).update(change);
    await n().saveAs(name);
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    clip.install(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: pizzaTheme(Brightness.dark),
          initialRoute: Routes.recipes,
          routes: {
            Routes.calculator: (_) => const Scaffold(body: Text('Dough page')),
            // Non-const so the constructor itself runs under coverage.
            Routes.recipes: (_) => RecipesScreen(key: UniqueKey()),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) =>
      tap(tester, find.text(text));

  Future<void> more(WidgetTester tester, String name) =>
      tap(tester, find.byTooltip('Options for $name'));

  bool enabled(WidgetTester tester, String label) => tester
      .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, label))
      .enabled;

  testWidgets('empty: the mark, one line of copy, nothing to export', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Recipes'), findsOneWidget);
    expect(find.text('Calculator'), findsOneWidget);
    expect(find.text('0 SAVED'), findsOneWidget);
    expect(find.byType(PizzaMark), findsOneWidget);
    expect(find.textContaining('No saved recipes yet'), findsOneWidget);
    expect(enabled(tester, 'Export'), isFalse);
    expect(enabled(tester, 'Import'), isTrue);
    expect(find.text('Save current as new'), findsOneWidget);
  });

  testWidgets('cards: name, summary, hydration; the open one is marked', (
    tester,
  ) async {
    await keep('Friday NY', (i) => i.copyWith(style: PizzaStyle.newYork));
    c.read(ovenProvider.notifier).set(OvenSetup.homeStone);
    await keep('Detroit', (i) => i.copyWith(style: PizzaStyle.detroit));
    await n().open(saved()[1]);
    await pump(tester);
    expect(find.text('2 SAVED'), findsOneWidget);
    expect(find.byType(PizzaMark), findsNothing);
    final ny = saved()[1];
    final out = calc(ny.inputs);
    expect(find.text(summaryOf(ny)), findsOneWidget);
    expect(find.text('${pctText(out.hydrationPct)}%'), findsOneWidget);
    expect(find.textContaining('Detroit · '), findsOneWidget);
    expect(find.text('open'), findsOneWidget);
    // The pill sits on the open card, and the newest card is on top.
    final pill = tester.getTopLeft(find.text('open')).dy;
    final top = tester.getTopLeft(find.text('Detroit')).dy;
    final fri = tester.getTopLeft(find.text('Friday NY')).dy;
    expect(top, lessThan(fri));
    expect((pill - fri).abs(), lessThan(20));
    final button = tester.getSize(find.byTooltip('Options for Detroit'));
    expect(button.width, greaterThanOrEqualTo(44));
    expect(button.height, greaterThanOrEqualTo(44));
  });

  testWidgets('tap a card: it opens, back on the calculator, a toast', (
    tester,
  ) async {
    await keep('Friday NY', (i) => i.copyWith(style: PizzaStyle.newYork));
    c.read(activeRecipeIdProvider.notifier).set(null);
    c.read(recipeProvider.notifier).setStyle(PizzaStyle.thin);
    await pump(tester);
    await tapText(tester, 'Friday NY');
    expect(find.text('Dough page'), findsOneWidget);
    expect(find.text('Loaded "Friday NY"'), findsOneWidget);
    expect(c.read(recipeProvider).style, PizzaStyle.newYork);
    expect(c.read(activeRecipeProvider)!.name, 'Friday NY');
  });

  testWidgets('save current as new asks a name; dismissed saves nothing', (
    tester,
  ) async {
    await pump(tester);
    await tapText(tester, 'Save current as new');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(saved(), isEmpty);

    await tapText(tester, 'Save current as new');
    expect(find.text('Name this recipe'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Friday NY');
    await tapText(tester, 'Save recipe');
    expect(names(), ['Friday NY']);
    expect(find.text('Friday NY'), findsOneWidget);
    expect(find.text('open'), findsOneWidget);
    expect(store.data[recipesStoreName], hasLength(1));
  });

  testWidgets('more: duplicate, rename, delete', (tester) async {
    await keep('Friday NY');
    await pump(tester);

    await more(tester, 'Friday NY');
    await tapText(tester, 'Duplicate');
    expect(names(), ['Friday NY', 'Friday NY copy']);

    await more(tester, 'Friday NY copy');
    await tapText(tester, 'Rename');
    expect(find.text('Rename recipe'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Saturday NY');
    await tapText(tester, 'Save name');
    expect(names(), ['Friday NY', 'Saturday NY']);
    expect(find.text('Saturday NY'), findsOneWidget);

    // Backing out of the sheets changes nothing.
    await more(tester, 'Saturday NY');
    await tapText(tester, 'Rename');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await more(tester, 'Saturday NY');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(names(), ['Friday NY', 'Saturday NY']);

    await more(tester, 'Friday NY');
    expect(
      tester
          .widget<SecondaryButton>(
            find.widgetWithText(SecondaryButton, 'Delete'),
          )
          .alert,
      isTrue,
    );
    await tapText(tester, 'Delete');
    expect(names(), ['Saturday NY']);
    expect(c.read(activeRecipeProvider), isNull);
    expect(find.text('1 SAVED'), findsOneWidget);
  });

  testWidgets('export copies the JSON, with a toast', (tester) async {
    await keep('A');
    await keep('B');
    await pump(tester);
    await tapText(tester, 'Export');
    expect(clip.text, exportRecipes(saved()));
    expect(find.text('2 recipes copied as JSON'), findsOneWidget);
  });

  testWidgets('one recipe reads as one', (tester) async {
    await keep('A');
    await pump(tester);
    await tapText(tester, 'Export');
    expect(find.text('1 recipe copied as JSON'), findsOneWidget);
    await n().delete(0);
    await tapText(tester, 'Import');
    expect(find.text('Imported 1 recipe'), findsOneWidget);
  });

  testWidgets('import reads the clipboard, with a toast', (tester) async {
    await keep('A');
    await keep('B');
    clip.text = n().exportJson();
    await pump(tester);
    await tapText(tester, 'Import');
    expect(find.text('Imported 2 recipes'), findsOneWidget);
    expect(names(), ['B', 'A', 'B', 'A']);
  });

  testWidgets('import of anything else says so, changes nothing', (
    tester,
  ) async {
    await pump(tester);
    await tapText(tester, 'Import');
    expect(find.text('No Pizzalator recipes on the clipboard'), findsOneWidget);
    clip.text = 'Neapolitan · 7 × 30 cm';
    await tester.pump(const Duration(seconds: 3));
    await tapText(tester, 'Import');
    expect(find.text('No Pizzalator recipes on the clipboard'), findsOneWidget);
    clip.text = exportRecipes(const []);
    await tester.pump(const Duration(seconds: 3));
    await tapText(tester, 'Import');
    expect(find.text('No Pizzalator recipes on the clipboard'), findsOneWidget);
    expect(saved(), isEmpty);
  });

  testWidgets('back link returns to the calculator', (tester) async {
    await pump(tester);
    await tapText(tester, 'Calculator');
    expect(find.text('Dough page'), findsOneWidget);
  });
}

String summaryOf(SavedRecipe r) =>
    summaryText(r.inputs, calc(r.inputs), r.oven);
