import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pizzalator/core/calc.dart';
import 'package:pizzalator/core/oven.dart';
import 'package:pizzalator/routes.dart';
import 'package:pizzalator/screens/calculator.dart';
import 'package:pizzalator/state/oven.dart';
import 'package:pizzalator/state/recipe.dart';
import 'package:pizzalator/state/units.dart';
import 'package:pizzalator/theme/pizza_theme.dart';
import 'package:pizzalator/widgets/widgets.dart';

/// Pumps the screen on a 360 dp wide phone, tall enough to build every card.
Future<ProviderContainer> pumpCalc(
  WidgetTester tester, {
  double scale = 1,
  double width = 360,
}) async {
  tester.view.physicalSize = Size(width * 3, 9000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final c = ProviderContainer.test();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: pizzaTheme(Brightness.dark),
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: app!,
        ),
        routes: {Routes.ferment: (_) => const Text('Ferment stub')},
        // Non-const so the constructor itself runs under coverage.
        home: CalculatorScreen(key: UniqueKey()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

RecipeInputs inputs(ProviderContainer c) => c.read(recipeProvider);

Finder field(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(TextField),
);

TextField fieldOf(WidgetTester tester, String key) =>
    tester.widget<TextField>(field(key));

String fieldText(WidgetTester tester, String key) =>
    fieldOf(tester, key).controller!.text;

Future<void> type(WidgetTester tester, String key, String text) async {
  await tester.enterText(field(key), text);
  await tester.pumpAndSettle();
}

Future<void> tapOn(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) =>
    tapOn(tester, find.text(text));

Finder step(String label) =>
    find.byWidgetPredicate((w) => w is StepButton && w.semanticLabel == label);

bool enabled(WidgetTester tester, Finder f) =>
    tester.widget<StepButton>(f).onPressed != null;

/// Picks [flour] in flour row [row].
Future<void> pickFlour(WidgetTester tester, int row, String flour) async {
  await tapOn(tester, find.byType(DropdownButton<Flour>).at(row));
  await tester.tap(find.text(flour).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('renders the default formula', (tester) async {
    await pumpCalc(tester);
    expect(find.text('PIZZALATOR'), findsOneWidget);
    expect(find.text('Dough'), findsOneWidget);
    for (final s in PizzaStyle.values) {
      expect(find.text(s.label), findsOneWidget, reason: s.label);
    }
    expect(find.text('I have flour'), findsOneWidget);
    expect(find.text('I want pizzas'), findsOneWidget);
    expect(fieldText(tester, 'flour'), '1000');
    expect(find.text('UK strong white'), findsOneWidget);
    expect(find.text('13%'), findsOneWidget);
    for (final o in ['Steel', 'Stone', 'Tray', 'Outdoor']) {
      expect(find.text(o), findsOneWidget);
    }
    expect(find.text('275 °C'), findsOneWidget);
    // Hydration 62.5 % (12.5 % base + 0.5 pp for 13 % protein).
    expect(find.text('62.5'), findsOneWidget);
    expect(find.text('%'), findsOneWidget);
    expect(find.text('58% style min'), findsOneWidget);
    expect(find.text('protein 13%'), findsOneWidget);
    expect(find.text('65% max'), findsOneWidget);
    expect(find.text('1000 g'), findsOneWidget);
    expect(find.text('625 g'), findsOneWidget);
    expect(find.text('28.0 g'), findsOneWidget);
    expect(find.text('Oil'), findsNothing);
    expect(find.text('Sugar'), findsNothing);
    expect(find.text('Instant yeast'), findsOneWidget);
    expect(find.text('2 h @ 20 °C + 24 h @ 4 °C'), findsOneWidget);
    expect(find.text('3.00 g'), findsOneWidget);
    expect(find.text('Makes'), findsOneWidget);
    expect(find.text('7 balls · 237 g'), findsOneWidget);
    expect(find.text('WARNINGS'), findsNothing);
    expect(find.text('NOTES'), findsNothing);
    expect(find.text('ADVANCED'), findsOneWidget);
    expect(find.text('OVEN SUGGESTION'), findsOneWidget);
    expect(find.text('Apply +1.5% oil, +1% sugar'), findsOneWidget);
    expect(find.text('Plan fermentation'), findsOneWidget);
  });

  testWidgets('formula follows state: Detroit switch', (tester) async {
    final c = await pumpCalc(tester);
    await tapText(tester, 'Detroit');
    expect(inputs(c).style, PizzaStyle.detroit);
    expect(find.text('72.5'), findsOneWidget);
    expect(find.text('70% style min'), findsOneWidget);
    expect(find.text('75% max'), findsOneWidget);
    expect(find.text('Oil'), findsOneWidget);
    expect(find.text('30.0 g'), findsOneWidget);
    expect(find.text('Sugar'), findsOneWidget);
    expect(find.text('Fills'), findsOneWidget);
    expect(find.text('4 pans · 409 g'), findsOneWidget);
    // Pan styles get no home-oven Neapolitan tip.
    expect(find.text('OVEN SUGGESTION'), findsNothing);
  });

  testWidgets('Roman shows malt instead of sugar', (tester) async {
    final c = await pumpCalc(tester);
    await tapText(tester, 'Roman teglia');
    expect(inputs(c).style, PizzaStyle.roman);
    expect(find.text('Malt'), findsOneWidget);
    expect(find.text('Sugar'), findsNothing);
  });

  testWidgets('total flour field drives the formula', (tester) async {
    final c = await pumpCalc(tester);
    await type(tester, 'flour', '500');
    expect(inputs(c).flourG, 500);
    expect(find.text('313 g'), findsOneWidget);

    // Below 100 g is ignored while typing and restored when editing ends.
    await type(tester, 'flour', '50');
    expect(inputs(c).flourG, 500);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'flour'), '500');

    // Letters never reach the field.
    await type(tester, 'flour', '5x');
    expect(fieldText(tester, 'flour'), '500');

    // Changes from elsewhere show up in the field.
    c.read(recipeProvider.notifier).setFlourG(150);
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'flour'), '150');
    expect(find.text('1 ball · 248 g'), findsOneWidget);
  });

  testWidgets('pizzas mode keeps percentages and the ball count', (
    tester,
  ) async {
    final c = await pumpCalc(tester);
    await tapText(tester, 'I want pizzas');
    expect(inputs(c).mode, EntryMode.pizzas);
    expect(inputs(c).pizzas, 7);
    expect(find.text('62.5'), findsOneWidget);
    expect(fieldText(tester, 'pizzas'), '7');
    expect(fieldText(tester, 'diameter'), '30');
    expect(find.byKey(const ValueKey('flour')), findsNothing);
    expect(find.text('Per ball'), findsOneWidget);
    expect(find.text('250 g'), findsOneWidget);

    await type(tester, 'pizzas', '2');
    expect(inputs(c).pizzas, 2);
    expect(find.text('302 g'), findsOneWidget);
    await type(tester, 'diameter', '35');
    expect(inputs(c).diameterCm, 35);

    await tapText(tester, 'I have flour');
    expect(inputs(c).mode, EntryMode.flour);
    expect(
      fieldText(tester, 'flour'),
      '${c.read(outputsProvider).totalFlourG.round()}',
    );
  });

  testWidgets('cm/in toggle converts sizes, ingredients stay grams', (
    tester,
  ) async {
    final c = await pumpCalc(tester);
    await tapText(tester, 'I want pizzas');
    await type(tester, 'diameter', '35');
    await tapText(tester, 'cm');
    expect(c.read(lengthUnitProvider), LengthUnit.inch);
    expect(find.text('in'), findsOneWidget);
    expect(fieldText(tester, 'diameter'), '13.8');
    expect(inputs(c).diameterCm, 35);

    await type(tester, 'diameter', '12');
    expect(inputs(c).diameterCm, closeTo(30.48, 1e-9));
    expect(find.textContaining(' g'), findsWidgets);

    // 5 in is under the 20 cm minimum.
    await type(tester, 'diameter', '5');
    expect(inputs(c).diameterCm, closeTo(30.48, 1e-9));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'diameter'), '12');

    await tapText(tester, 'in');
    expect(c.read(lengthUnitProvider), LengthUnit.cm);
    expect(fieldText(tester, 'diameter'), '30.5');
  });

  testWidgets('pan styles take width and length', (tester) async {
    final c = await pumpCalc(tester);
    await tapText(tester, 'Detroit');
    await tapText(tester, 'I want pizzas');
    expect(find.text('Per pan'), findsOneWidget);
    expect(find.byKey(const ValueKey('diameter')), findsNothing);
    expect(fieldText(tester, 'panW'), '25');
    expect(fieldText(tester, 'panL'), '35');
    await type(tester, 'panW', '20');
    await type(tester, 'panL', '30');
    expect(inputs(c).panWCm, 20);
    expect(inputs(c).panLCm, 30);
  });

  group('flour rows (FR2)', () {
    testWidgets('pick, add, share and remove; last row balances', (
      tester,
    ) async {
      final c = await pumpCalc(tester);
      await pickFlour(tester, 0, 'UK plain');
      expect(inputs(c).flours.single.flour.name, 'UK plain');
      expect(find.text('59.5'), findsOneWidget);
      expect(find.text('protein 10%'), findsOneWidget);
      expect(find.text('Share'), findsNothing, reason: 'one flour is 100 %');

      await tapText(tester, 'Add flour');
      List<(String, double)> blend() => [
        for (final f in inputs(c).flours) (f.flour.name, f.sharePct),
      ];
      expect(blend(), [('UK plain', 80), ('Wholemeal', 20)]);
      expect(find.text('auto'), findsOneWidget);
      expect(find.text('· UK plain'), findsOneWidget);
      expect(find.text('800 g'), findsOneWidget);
      expect(find.text('· Wholemeal'), findsOneWidget);
      expect(find.text('200 g'), findsOneWidget);
      expect(find.textContaining('Wholegrain in the mix'), findsOneWidget);

      // Semolina for the 00 + semolina blend the preset is for.
      await pickFlour(tester, 1, 'Semolina rimacinata');
      expect(blend(), [('UK plain', 80), ('Semolina rimacinata', 20)]);
      await tapOn(tester, step('Less share').first);
      expect(blend(), [('UK plain', 75), ('Semolina rimacinata', 25)]);

      await tapText(tester, 'Add flour');
      expect(blend().map((b) => b.$2), [75, 15, 10]);
      expect(find.text('Add flour'), findsNothing, reason: 'three at most');
      await tapOn(tester, step('More share').at(1));
      expect(blend().map((b) => b.$2), [75, 20, 5]);
      expect(enabled(tester, step('More share').at(1)), isFalse);

      await tapOn(tester, step('Remove flour 1'));
      expect(blend().map((b) => b.$2), [20, 80]);
      await tapOn(tester, step('Remove flour 2'));
      expect(blend().single.$2, 100);
      expect(step('Remove flour 1'), findsNothing);
    });

    testWidgets('long flour names keep their protein visible', (tester) async {
      await pumpCalc(tester);
      await tapOn(tester, find.byType(DropdownButton<Flour>));
      // The name truncates; the protein is its own text and never does.
      final name = find.text('UK very strong / Canadian').last;
      expect(tester.widget<Text>(name).overflow, TextOverflow.ellipsis);
      final pct = find.text('14.5%').last;
      expect(tester.widget<Text>(pct).overflow, isNull);
      expect(tester.getRect(pct).left, greaterThan(tester.getRect(name).right));
    });

    testWidgets('a flour outside the presets still shows', (tester) async {
      final c = await pumpCalc(tester);
      c
          .read(recipeProvider.notifier)
          .update(
            (i) => i.copyWith(
              flours: const [FlourShare(Flour('Very strong', 16), 100)],
            ),
          );
      await tester.pumpAndSettle();
      expect(find.text('Very strong'), findsOneWidget);
      expect(find.text('16%'), findsOneWidget);
    });
  });

  testWidgets('weak flour: a flour tip lowers hydration 2 pp', (tester) async {
    final c = await pumpCalc(tester);
    await pickFlour(tester, 0, 'UK plain');
    await tapText(tester, 'New York');
    expect(find.text('WARNINGS'), findsNothing, reason: 'advice, not alarm');
    expect(find.text('FLOUR SUGGESTION'), findsOneWidget);
    expect(find.textContaining('Weak flour for this style'), findsOneWidget);
    await tapText(tester, 'Lower hydration 2 pp');
    expect(inputs(c).hydrationOverride, 58.5);
    expect(find.text('58.5'), findsOneWidget);
    expect(find.text('FLOUR SUGGESTION'), findsNothing);
  });

  testWidgets('notes are muted; real warnings are alert red', (tester) async {
    final c = await pumpCalc(tester);
    await tapText(tester, 'Add flour');
    final notes = tester.widget<Text>(find.text('NOTES'));
    expect(notes.style!.color, PizzaColors.dark.inkMuted);
    expect(find.text('WARNINGS'), findsNothing);

    await tapText(tester, 'Tray');
    final warn = tester.widget<Text>(find.text('WARNINGS'));
    expect(warn.style!.color, PizzaColors.dark.alert);
    expect(find.textContaining('A tray cannot heat'), findsOneWidget);
    expect(c.read(ovenProvider).surface, Surface.none);
  });

  group('oven', () {
    testWidgets('picker drives tips and warnings', (tester) async {
      final c = await pumpCalc(tester);
      await tapText(tester, 'Outdoor');
      expect(identical(c.read(ovenProvider), OvenSetup.outdoor), isTrue);
      expect(find.text('OVEN SUGGESTION'), findsNothing);
      expect(find.text('450 °C'), findsOneWidget);

      await tapText(tester, 'Tray');
      expect(find.text('WARNINGS'), findsOneWidget);
      expect(find.textContaining('A tray cannot heat'), findsOneWidget);
    });

    testWidgets('max temperature steps, keeps the surface, warns', (
      tester,
    ) async {
      final c = await pumpCalc(tester);
      await tapText(tester, 'Stone');
      await tapOn(tester, step('Less max temperature'));
      expect(c.read(ovenProvider).maxTempC, 250);
      expect(c.read(ovenProvider).surface, Surface.stone);
      expect(find.text('250 °C'), findsOneWidget);
      expect(find.textContaining('under 260 °C'), findsOneWidget);
      // Stone stays selected after the temperature change.
      final stone = tester.widget<Text>(find.text('Stone'));
      expect(stone.style!.color, PizzaColors.dark.ink);
      await tapText(tester, 'Steel');
      expect(c.read(ovenProvider).maxTempC, 250, reason: 'same oven');
      for (var n = 0; n < 4; n++) {
        await tapOn(tester, step('More max temperature'));
      }
      expect(c.read(ovenProvider).maxTempC, 300);
      expect(enabled(tester, step('More max temperature')), isFalse);
    });

    testWidgets('tip applies and reverts with one tap', (tester) async {
      final c = await pumpCalc(tester);
      await tapText(tester, 'Apply +1.5% oil, +1% sugar');
      expect(inputs(c).oilPct, 1.5);
      expect(inputs(c).sugarPct, 1);
      expect(find.text('Oil'), findsOneWidget);
      expect(find.text('15.0 g'), findsOneWidget);
      expect(find.text('Sugar'), findsOneWidget);

      await tapText(tester, 'Revert to style');
      expect(inputs(c).oilPct, isNull);
      expect(find.text('Oil'), findsNothing);
    });
  });

  group('advanced (FR5)', () {
    Future<ProviderContainer> open(WidgetTester tester) async {
      final c = await pumpCalc(tester);
      await tapText(tester, 'ADVANCED');
      return c;
    }

    testWidgets('closed until tapped: one tap from the hydration override', (
      tester,
    ) async {
      await pumpCalc(tester);
      expect(step('More hydration'), findsNothing);
      await tapText(tester, 'ADVANCED');
      expect(step('More hydration'), findsOneWidget);
      await tapText(tester, 'ADVANCED');
      expect(step('More hydration'), findsNothing);
    });

    testWidgets('every baker\'s % shows its style default and a badge', (
      tester,
    ) async {
      final c = await open(tester);
      for (final l in ['Hydration', 'Salt', 'Oil', 'Sugar', 'Bowl residue']) {
        expect(find.text(l), findsWidgets, reason: l);
      }
      expect(find.text('style 2.8%'), findsOneWidget);
      expect(find.text('MODIFIED'), findsNothing);

      await tapOn(tester, step('More salt'));
      expect(inputs(c).saltPct, closeTo(2.9, 1e-9));
      expect(inputs(c).fromTip, isEmpty, reason: 'an explicit edit');
      expect(find.text('2.9%'), findsOneWidget);
      expect(find.text('29.0 g'), findsOneWidget);
      expect(find.text('MODIFIED'), findsOneWidget);

      await tapOn(tester, step('More hydration'));
      expect(inputs(c).hydrationOverride, 63.5);
      expect(find.text('style 62.5%'), findsOneWidget);
      expect(find.text('MODIFIED'), findsNWidgets(2));

      await tapOn(tester, step('Reset salt to style'));
      expect(inputs(c).saltPct, isNull);
      expect(find.text('MODIFIED'), findsOneWidget);

      // A style switch keeps what the user set (FR1).
      await tapText(tester, 'New York');
      expect(inputs(c).hydrationOverride, 63.5);

      await tapText(tester, 'Reset to style');
      expect(inputs(c).hydrationOverride, isNull);
      expect(find.text('MODIFIED'), findsNothing);
    });

    testWidgets('steppers stop at zero', (tester) async {
      final c = await open(tester);
      expect(enabled(tester, step('Less oil')), isFalse);
      await tapOn(tester, step('More oil'));
      expect(inputs(c).oilPct, 0.5);
      await tapOn(tester, step('Less oil'));
      expect(inputs(c).oilPct, 0);
    });

    testWidgets('Roman calls the sweetener malt', (tester) async {
      await pumpCalc(tester);
      await tapText(tester, 'Roman teglia');
      await tapText(tester, 'ADVANCED');
      expect(step('More malt'), findsOneWidget);
    });

    testWidgets('thickness presets; Detroit in g/in²', (tester) async {
      final c = await open(tester);
      await tapText(tester, 'Thick');
      expect(inputs(c).thickness, 1.15);
      await tapText(tester, 'Detroit');
      expect(find.text('3.15 g/in²'), findsOneWidget);
      expect(find.text('2.95 g/in²'), findsOneWidget);
      expect(inputs(c).thickness, thicknessPresets(PizzaStyle.detroit).last);
      await tapText(tester, '2.75 g/in²');
      expect(inputs(c).thickness, thicknessPresets(PizzaStyle.detroit).first);
    });

    testWidgets('k, wholegrain absorption and the yeast knob', (tester) async {
      final c = await open(tester);
      expect(find.text('1'), findsOneWidget, reason: 'k');
      await tapOn(tester, step('More protein slope k'));
      await tapOn(tester, step('More protein slope k'));
      expect(inputs(c).hydrationSlope, closeTo(1.2, 1e-9));
      expect(c.read(outputsProvider).hydrationPct, 62.6); // 62 + 1.2 × 0.5
      expect(find.text('62.6'), findsOneWidget);
      await tapOn(tester, step('Less wholegrain absorption'));
      expect(inputs(c).wholegrainAbsorption, 74);
      await tapOn(tester, step('More yeast knob'));
      expect(inputs(c).yeastKnob, closeTo(1.05, 1e-9));
      expect(find.text('105%'), findsOneWidget);
    });
  });

  testWidgets('leavening rows sum preferment and final dough', (tester) async {
    final c = await pumpCalc(tester);
    final n = c.read(recipeProvider.notifier);
    n.update((i) => i.copyWith(preferment: Preferment.poolish));
    await tester.pumpAndSettle();
    // 0.30 g in the poolish + 1.50 g in the final dough.
    expect(find.text('1.80 g'), findsOneWidget);
    expect(find.text('625 g'), findsOneWidget);

    n.update(
      (i) => i.copyWith(yeast: Yeast.fresh, preferment: Preferment.poolish),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fresh yeast'), findsOneWidget);
    // Both in fresh yeast: 0.9 g + 4.5 g.
    expect(find.text('5.40 g'), findsOneWidget);

    n.update((i) => withYeast(i, Yeast.sourdough));
    await tester.pumpAndSettle();
    expect(find.text('Starter'), findsOneWidget);
    expect(find.text('Instant yeast'), findsNothing);
  });

  testWidgets('Plan fermentation opens the ferment screen', (tester) async {
    await pumpCalc(tester);
    await tapText(tester, 'Plan fermentation');
    expect(find.text('Ferment stub'), findsOneWidget);
  });

  testWidgets('fields only accept numbers', (tester) async {
    await pumpCalc(tester);
    await tapText(tester, 'I want pizzas');
    await type(tester, 'pizzas', '123');
    expect(fieldText(tester, 'pizzas'), '7');
    await tapText(tester, 'cm');
    await type(tester, 'diameter', '11.85');
    expect(fieldText(tester, 'diameter'), '11.8');
    final diameter = fieldOf(tester, 'diameter');
    expect(
      diameter.keyboardType,
      const TextInputType.numberWithOptions(decimal: true),
    );
    expect(diameter.textInputAction, TextInputAction.done);
    expect(fieldOf(tester, 'pizzas').keyboardType, TextInputType.number);
  });

  testWidgets('fields, rows and the unit button read well on TalkBack', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpCalc(tester);
    expect(
      tester.getSemantics(field('flour')),
      isSemantics(label: 'Total flour in grams', isTextField: true),
    );
    // A formula row is one stop: its label with its grams.
    expect(find.bySemanticsLabel('Water\n625 g'), findsOneWidget);
    expect(find.bySemanticsLabel('Hydration 62.5%'), findsOneWidget);
    await tapText(tester, 'I want pizzas');
    expect(find.bySemanticsLabel('Switch sizes to inches'), findsOneWidget);
    await tapText(tester, 'cm');
    expect(
      find.bySemanticsLabel('Switch sizes to centimetres'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('large text: the unit label shrinks inside its 44 px', (
    tester,
  ) async {
    // Wide, so the 1 em test font does not overflow the other rows.
    await pumpCalc(tester, scale: 2, width: 1200);
    await tapText(tester, 'I want pizzas');
    expect(tester.takeException(), isNull);
    final box = find.ancestor(
      of: find.text('cm'),
      matching: find.byType(FittedBox),
    );
    expect(box, findsOneWidget);
    expect(tester.getSize(box).width, lessThanOrEqualTo(36));
  });
}
