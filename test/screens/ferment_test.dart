import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pizzalator/core/calc.dart';
import 'package:pizzalator/routes.dart';
import 'package:pizzalator/screens/ferment.dart';
import 'package:pizzalator/state/recipe.dart';
import 'package:pizzalator/theme/pizza_theme.dart';
import 'package:pizzalator/widgets/widgets.dart';

Widget host(ProviderContainer c) => UncontrolledProviderScope(
  container: c,
  child: MaterialApp(
    theme: pizzaTheme(Brightness.dark),
    initialRoute: Routes.ferment,
    routes: {
      Routes.calculator: (_) => const Scaffold(body: Text('calculator page')),
      Routes.ferment: (_) => const FermentScreen(),
      Routes.recipe: (_) => const Scaffold(body: Text('recipe page')),
    },
  ),
);

/// Pumps the screen on a 390 × 844 phone, optionally from a changed recipe.
Future<ProviderContainer> pumpFerment(
  WidgetTester tester, [
  RecipeInputs Function(RecipeInputs)? change,
]) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final c = ProviderContainer.test();
  if (change != null) c.read(recipeProvider.notifier).update(change);
  await tester.pumpWidget(host(c));
  await tester.pumpAndSettle();
  return c;
}

Future<void> tapOn(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Finder step(String label) =>
    find.byWidgetPredicate((w) => w is StepButton && w.semanticLabel == label);

bool enabled(WidgetTester tester, String label) =>
    tester.widget<StepButton>(step(label)).onPressed != null;

double line(ProviderContainer c, String name) =>
    c.read(outputsProvider).finalDough.firstWhere((l) => l.name == name).grams;

Preferment pref(ProviderContainer c) => c.read(recipeProvider).preferment;

List<Stage>? plan(ProviderContainer c) => c.read(recipeProvider).plan;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('shows leavening, schedule and yeast for the default recipe', (
    tester,
  ) async {
    final c = await pumpFerment(tester);
    expect(find.text('Fermentation'), findsOneWidget);
    expect(find.text('Calculator'), findsOneWidget);
    for (final s in ['Instant', 'Active dry', 'Fresh', 'Sourdough']) {
      expect(find.text(s), findsOneWidget);
    }
    for (final s in ['None', 'Poolish', 'Biga']) {
      expect(find.text(s), findsOneWidget);
    }
    // Neapolitan default: 2 h room, 24 h fridge, no warm-up.
    expect(find.text('26 h total'), findsOneWidget);
    expect(find.text('2h'), findsOneWidget);
    expect(find.text('24h'), findsOneWidget);
    expect(find.text('0h'), findsOneWidget);
    expect(find.text('20°'), findsOneWidget);
    expect(find.text('20 °C · yeast works fast'), findsOneWidget);
    expect(find.text('4 °C · flavour, slow rise'), findsOneWidget);
    expect(find.text('INSTANT DRY YEAST'), findsOneWidget);
    final o = c.read(outputsProvider);
    expect(find.text(line(c, 'IDY').toStringAsFixed(2)), findsOneWidget);
    expect(
      find.text('g · ${o.yeastPct.toStringAsFixed(2)}% of flour'),
      findsOneWidget,
    );
    expect(find.textContaining('longer or warmer'), findsOneWidget);
    expect(find.textContaining('pinch'), findsNothing);
    expect(find.text('Final dough'), findsNothing);
    expect(step('More hydration'), findsNothing);
    expect(find.text('Build recipe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back link returns to the calculator', (tester) async {
    await pumpFerment(tester);
    await tapOn(tester, find.text('Calculator'));
    expect(find.text('calculator page'), findsOneWidget);
  });

  testWidgets('Build recipe opens the recipe', (tester) async {
    await pumpFerment(tester);
    await tapOn(tester, find.text('Build recipe'));
    expect(find.text('recipe page'), findsOneWidget);
  });

  testWidgets('leavening picks the yeast type and keeps a preferment', (
    tester,
  ) async {
    final c = await pumpFerment(tester);
    await tapOn(tester, find.text('Poolish'));
    await tapOn(tester, find.text('Active dry'));
    expect(c.read(recipeProvider).yeast, Yeast.ady);
    expect(c.read(recipeProvider).preferment.kind, PrefermentKind.poolish);
    expect(find.text('ACTIVE DRY YEAST'), findsOneWidget);
    expect(find.text(line(c, 'ADY').toStringAsFixed(2)), findsOneWidget);
    await tapOn(tester, find.text('Fresh'));
    expect(find.text('FRESH YEAST'), findsOneWidget);
    final before = c.read(recipeProvider);
    await tapOn(tester, find.text('Fresh'));
    expect(c.read(recipeProvider), same(before));
  });

  testWidgets('sourdough swaps in a starter and hides yeast preferments', (
    tester,
  ) async {
    final c = await pumpFerment(tester);
    await tapOn(tester, find.text('Poolish'));
    await tapOn(tester, find.text('Sourdough'));
    final i = c.read(recipeProvider);
    expect(i.yeast, Yeast.sourdough);
    expect(i.preferment.kind, PrefermentKind.sourdough);
    expect(i.preferment.flourShare, 15);
    expect(find.text('Poolish'), findsNothing);
    expect(find.text('None'), findsNothing);
    expect(find.text('SOURDOUGH STARTER'), findsOneWidget);
    // PRD §4.5: 15 % starter of 1000 g flour = 150 g, half flour at 100 %.
    expect(find.text('150'), findsOneWidget);
    expect(find.text('g · 15% of flour'), findsOneWidget);
    expect(find.text('Starter'), findsWidgets);
    expect(find.text('% of flour, 10–25%'), findsOneWidget);
    expect(find.text('75 g flour'), findsOneWidget);
    expect(find.text('75 g water'), findsOneWidget);
    expect(find.text('Final dough'), findsOneWidget);
    expect(find.text('925 g flour'), findsOneWidget);
    expect(find.text('550 g water'), findsOneWidget);
    expect(find.textContaining('Starter at 100% hydration'), findsOneWidget);
    // And its own plan: 5 h room bulk + 18 h fridge (PRD §4.5).
    expect(i.plan, same(kSourdoughPlan));
    expect(find.text('23 h total'), findsOneWidget);
    await tapOn(tester, step('More hydration'));
    expect(pref(c).hydration, 105);
    expect(find.text('77 g water'), findsOneWidget);
    await tapOn(tester, find.text('Instant'));
    expect(c.read(recipeProvider).yeast, Yeast.idy);
    expect(pref(c).kind, PrefermentKind.none);
    expect(c.read(recipeProvider).plan, isNull, reason: 'style plan back');
    expect(find.text('26 h total'), findsOneWidget);
    expect(find.text('Poolish'), findsOneWidget);
    expect(find.text('Final dough'), findsNothing);
  });

  testWidgets('sourdough with no preferment reads as the default starter', (
    tester,
  ) async {
    final c = await pumpFerment(
      tester,
      (i) => i.copyWith(yeast: Yeast.sourdough),
    );
    expect(find.text('75 g flour'), findsOneWidget);
    expect(find.text('15%'), findsOneWidget);
    await tapOn(tester, step('More starter'));
    final p = pref(c);
    expect(p.kind, PrefermentKind.sourdough);
    expect(p.flourShare, 20);
    expect(find.text('100 g flour'), findsOneWidget);
  });

  testWidgets('preferment params step within the PRD ranges', (tester) async {
    final c = await pumpFerment(tester);
    Preferment pref() => c.read(recipeProvider).preferment;

    await tapOn(tester, find.text('Poolish'));
    expect(pref().kind, PrefermentKind.poolish);
    expect(step('More hydration'), findsNothing);
    expect(find.text('300 g flour'), findsOneWidget);
    expect(find.text('300 g water'), findsOneWidget);
    expect(find.text('700 g flour'), findsOneWidget);
    expect(find.text('325 g water'), findsOneWidget);
    expect(find.textContaining('Poolish: 30% of flour'), findsOneWidget);
    for (var n = 0; n < 4; n++) {
      await tapOn(tester, step('More flour share'));
    }
    expect(pref().flourShare, 50);
    expect(enabled(tester, 'More flour share'), isFalse);
    await tapOn(tester, step('Less flour share'));
    expect(pref().flourShare, 45);

    await tapOn(tester, find.widgetWithText(PizzaChip, 'Biga'));
    expect(pref().flourShare, 50);
    expect(pref().hydration, 50);
    await tapOn(tester, step('More hydration'));
    expect(pref().hydration, 55);
    expect(enabled(tester, 'More hydration'), isFalse);
    await tapOn(tester, step('Less hydration'));
    await tapOn(tester, step('Less hydration'));
    expect(pref().hydration, 45);
    expect(enabled(tester, 'Less hydration'), isFalse);
    await tapOn(tester, find.widgetWithText(PizzaChip, 'Biga'));
    expect(pref().hydration, 45, reason: 'reselecting keeps the params');

    await tapOn(tester, find.text('None'));
    expect(pref().kind, PrefermentKind.none);
    expect(find.text('Final dough'), findsNothing);
    expect(step('More flour share'), findsNothing);
    expect(step('More hours'), findsNothing);
  });

  testWidgets('poolish hours and temperature; its IDY follows the hours', (
    tester,
  ) async {
    final c = await pumpFerment(tester);
    await tapOn(tester, find.text('Poolish'));
    expect(find.text('14 h'), findsOneWidget);
    expect(find.text('20 °C'), findsOneWidget);
    expect(
      find.textContaining('0.1% IDY of its flour, 14 h at 20 °C'),
      findsOneWidget,
    );
    for (var n = 0; n < 6; n++) {
      await tapOn(tester, step('Less hours'));
    }
    expect(pref(c).hours, 8);
    expect(enabled(tester, 'Less hours'), isFalse);
    expect(find.textContaining('0.25% IDY of its flour, 8 h'), findsOneWidget);
    expect(c.read(outputsProvider).preferment.last.grams, 0.75);
    await tapOn(tester, step('More temperature'));
    expect(pref(c).tempC, 21);

    await tapOn(tester, find.widgetWithText(PizzaChip, 'Biga'));
    expect(find.text('18 h'), findsOneWidget);
    expect(find.text('17 °C'), findsOneWidget);
    await tapOn(tester, step('More temperature'));
    expect(pref(c).tempC, 18);
    expect(enabled(tester, 'More temperature'), isFalse);
  });

  testWidgets('a poolish share never holds more water than the dough', (
    tester,
  ) async {
    // Thin on UK plain: 49.5 % hydration; a poolish stops at 45 %.
    final c = await pumpFerment(
      tester,
      (i) => i.copyWith(
        style: PizzaStyle.thin,
        flours: const [FlourShare(Flour('UK plain', 10), 100)],
        preferment: Preferment.poolish,
      ),
    );
    for (var n = 0; n < 4; n++) {
      await tapOn(tester, step('More flour share'));
    }
    expect(pref(c).flourShare, 45);
    expect(enabled(tester, 'More flour share'), isFalse);
    expect(line(c, 'Water'), greaterThanOrEqualTo(0));
  });

  testWidgets('stage steppers write room, fridge and warm-up stages', (
    tester,
  ) async {
    final c = await pumpFerment(tester);
    await tapOn(tester, step('More room bulk'));
    expect(plan(c), const [Stage(3, 20), Stage(24, 4)]);
    expect(find.text('27 h total'), findsOneWidget);
    await tapOn(tester, step('More fridge'));
    expect(plan(c), const [Stage(3, 20), Stage(36, 4)]);
    await tapOn(tester, step('More warm up before bake'));
    expect(plan(c), const [Stage(3, 20), Stage(36, 4), Stage(1, 20)]);
    for (var n = 0; n < 3; n++) {
      await tapOn(tester, step('Less fridge'));
    }
    expect(plan(c), const [Stage(3, 20), Stage(0, 4), Stage(1, 20)]);
    expect(enabled(tester, 'Less fridge'), isFalse);
    await tapOn(tester, step('Less warm up before bake'));
    await tapOn(tester, step('Less room bulk'));
    expect(plan(c), const [Stage(2, 20)]);
    expect(find.text('2 h total'), findsOneWidget);
  });

  testWidgets('steppers stop at their limits and never empty the plan', (
    tester,
  ) async {
    await pumpFerment(
      tester,
      (i) =>
          i.copyWith(plan: const [Stage(24, 20), Stage(96, 4), Stage(4, 20)]),
    );
    for (final s in ['room bulk', 'fridge', 'warm up before bake']) {
      expect(enabled(tester, 'More $s'), isFalse, reason: s);
      expect(enabled(tester, 'Less $s'), isTrue, reason: s);
    }
    await tester.pumpWidget(const SizedBox());
    await pumpFerment(tester, (i) => i.copyWith(plan: const [Stage(1, 20)]));
    for (final s in ['room bulk', 'fridge', 'warm up before bake']) {
      expect(enabled(tester, 'Less $s'), isFalse, reason: s);
    }
  });

  testWidgets('room temperature retimes the room stages', (tester) async {
    final c = await pumpFerment(
      tester,
      (i) => i.copyWith(plan: const [Stage(2, 20), Stage(24, 4), Stage(1, 20)]),
    );
    await tester.ensureVisible(find.byType(Slider));
    tester.widget<Slider>(find.byType(Slider)).onChanged!(25);
    await tester.pumpAndSettle();
    expect(plan(c), const [Stage(2, 25), Stage(24, 4), Stage(1, 25)]);
    expect(find.text('25°'), findsOneWidget);
    expect(find.text('25 °C · yeast works fast'), findsOneWidget);
  });

  testWidgets('room temperature is spoken in °C, not a percentage', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpFerment(tester);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.semanticFormatterCallback!(20), '20 °C');
    final node = tester.getSemantics(find.byType(Slider));
    expect(node.value, '20 °C');
    expect(node.increasedValue, '21 °C');
    expect(find.bySemanticsLabel('Room temperature'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('fridge-only plan explains the margin', (tester) async {
    await pumpFerment(tester, (i) => i.copyWith(plan: const [Stage(48, 4)]));
    expect(find.textContaining('Fridge-only plan: +30%'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
  });

  testWidgets('tiny batches get pinch guidance', (tester) async {
    final c = await pumpFerment(tester, (i) => i.copyWith(flourG: 20));
    expect(line(c, 'IDY'), lessThan(kPinchG));
    expect(find.text(kPinchNote), findsOneWidget, reason: 'the calc note');
  });
}
