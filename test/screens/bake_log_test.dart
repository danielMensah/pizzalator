import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pizzalator/core/bake_log.dart';
import 'package:pizzalator/core/calc.dart';
import 'package:pizzalator/core/export_text.dart';
import 'package:pizzalator/core/oven.dart';
import 'package:pizzalator/routes.dart';
import 'package:pizzalator/screens/bake_log.dart';
import 'package:pizzalator/services/json_store.dart';
import 'package:pizzalator/services/photos.dart';
import 'package:pizzalator/state/bake_log.dart';
import 'package:pizzalator/state/calibration.dart';
import 'package:pizzalator/state/oven.dart';
import 'package:pizzalator/state/recipe.dart';
import 'package:pizzalator/theme/pizza_theme.dart';
import 'package:pizzalator/widgets/widgets.dart';

import '../fakes.dart';

const c = PizzaColors.dark;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late MemoryStore store;
  late FakePhotoStore photos;
  late ProviderContainer pc;

  setUp(() {
    store = MemoryStore();
    photos = FakePhotoStore();
    pc = ProviderContainer.test(
      overrides: [
        jsonStoreProvider.overrideWithValue(store),
        photoStoreProvider.overrideWithValue(photos),
      ],
    );
  });

  final fri = DateTime(2026, 10, 16, 20);

  Future<void> log(
    String id,
    String name,
    PizzaStyle style, {
    int rating = 3,
    Map<Outcome, int> outcomes = const {},
    String? photo,
    DateTime? date,
    OvenSetup oven = OvenSetup.homeSteel,
  }) => pc
      .read(bakeLogProvider.notifier)
      .add(
        BakeEntry(
          id: id,
          date: date ?? fri,
          name: name,
          inputs: RecipeInputs(style: style),
          oven: oven,
          rating: rating,
          outcomes: outcomes,
          photo: photo,
        ),
      );

  Future<void> pump(WidgetTester tester, {bool reduce = false}) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: pc,
        child: MaterialApp(
          theme: pizzaTheme(Brightness.dark),
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
            child: app!,
          ),
          initialRoute: Routes.bakeLog,
          routes: {
            Routes.calculator: (_) => const Scaffold(body: Text('Dough page')),
            // Non-const so the constructor itself runs under coverage.
            Routes.bakeLog: (_) => BakeLogScreen(key: UniqueKey()),
            Routes.logEntry: (context) =>
                Text('Entry ${ModalRoute.of(context)!.settings.arguments}'),
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

  Color tagFill(WidgetTester tester, String text) {
    final tag = find.ancestor(
      of: find.text(text),
      matching: find.byType(Container),
    );
    final box = tester.widget<Container>(tag.first).decoration!;
    return (box as BoxDecoration).color!;
  }

  testWidgets('empty: the mark, a line of copy, no filters', (tester) async {
    await pump(tester);
    expect(find.text('Bake log'), findsOneWidget);
    expect(find.text('Calculator'), findsOneWidget);
    expect(find.text('0 BAKES'), findsOneWidget);
    expect(find.byType(PizzaMark), findsOneWidget);
    expect(find.textContaining('No bakes logged yet'), findsOneWidget);
    expect(find.byType(PizzaChip), findsNothing);
  });

  testWidgets('the + button: 60 px ember, logs a new bake', (tester) async {
    await pump(tester);
    final fab = find.byTooltip('Log a bake');
    expect(tester.getSize(fab), const Size.square(60));
    final button = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(button.backgroundColor, c.ember);
    await tap(tester, fab);
    expect(find.text('Entry null'), findsOneWidget);
  });

  testWidgets('cards: newest first, name, date, stars, tags bad first', (
    tester,
  ) async {
    await log(
      'a',
      'Detroit, pepperoni cups',
      PizzaStyle.detroit,
      rating: 5,
      date: DateTime(2026, 10, 11),
    );
    await log(
      'b',
      'Friday NY',
      PizzaStyle.newYork,
      outcomes: const {Outcome.dough: 0},
    );
    await pump(tester);
    expect(find.text('2 BAKES'), findsOneWidget);
    expect(find.byType(PizzaMark), findsNothing);
    expect(
      tester.getTopLeft(find.text('Friday NY')).dy,
      lessThan(tester.getTopLeft(find.text('Detroit, pepperoni cups')).dy),
    );
    expect(find.text(dayText(fri)), findsOneWidget);
    expect(find.text('Sun 11 Oct'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('3 of 5 stars')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('5 of 5 stars')), findsOneWidget);
    final lit = tester
        .widgetList<Icon>(find.byIcon(Icons.star_rounded))
        .where((i) => i.color == c.emberBright);
    expect(lit, hasLength(8));
    expect(find.text('too wet'), findsOneWidget);
    expect(tagFill(tester, 'too wet'), c.alertTint);
    expect(tagFill(tester, 'proof right'), c.sageTint);
    // Three tags a card.
    expect(find.text('bottom right'), findsNothing);
  });

  testWidgets('a photo shows its file; none, the warm placeholder', (
    tester,
  ) async {
    await log('a', 'With photo', PizzaStyle.newYork, photo: 'a.jpg');
    await log('b', 'Without', PizzaStyle.newYork);
    await pump(tester);
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      ((image.image as ResizeImage).imageProvider as FileImage).file.path,
      photos.file('a.jpg').path,
    );
    expect(find.byKey(const ValueKey('no photo')), findsOneWidget);
  });

  testWidgets('filters: All plus the styles logged; the count follows', (
    tester,
  ) async {
    await log('a', 'Detroit bake', PizzaStyle.detroit);
    await log('b', 'NY one', PizzaStyle.newYork);
    await log('c', 'NY two', PizzaStyle.newYork);
    await pump(tester);
    final chips = tester.widgetList<PizzaChip>(find.byType(PizzaChip));
    expect([for (final ch in chips) ch.label], ['All', 'New York', 'Detroit']);
    expect(chips.first.selected, isTrue);
    await tap(tester, find.text('Detroit'));
    expect(find.text('1 BAKE'), findsOneWidget);
    expect(find.text('NY one'), findsNothing);
    expect(find.text('Detroit bake'), findsOneWidget);

    // The last Detroit bake goes: back to All.
    await pc.read(bakeLogProvider.notifier).delete('a');
    await tester.pumpAndSettle();
    expect(find.text('2 BAKES'), findsOneWidget);
    expect(find.text('Detroit'), findsNothing);
    await tap(tester, find.text('New York'));
    await tap(tester, find.text('All'));
    expect(find.text('2 BAKES'), findsOneWidget);
  });

  testWidgets('tap a card: it opens for editing', (tester) async {
    await log('b7', 'Friday NY', PizzaStyle.newYork);
    await pump(tester);
    await tap(tester, find.text('Friday NY'));
    expect(find.text('Entry b7'), findsOneWidget);
  });

  testWidgets('back lands on the calculator', (tester) async {
    await pump(tester);
    await tap(tester, find.text('Calculator'));
    expect(find.text('Dough page'), findsOneWidget);
  });

  group('calibration hint', () {
    // The working copy is New York on the steel; two bakes of it too wet.
    setUp(() => pc.read(recipeProvider.notifier).setStyle(PizzaStyle.newYork));
    final hyd = r01(
      Pct.hydration.value(const RecipeInputs(style: PizzaStyle.newYork)),
    );
    const wet = {Outcome.dough: 0};

    Future<void> twoWet() async {
      await log('a', 'Friday NY', PizzaStyle.newYork, outcomes: wet);
      await log('b', 'Friday NY', PizzaStyle.newYork, outcomes: wet);
    }

    testWidgets('the sage card at the top: label, text, two buttons', (
      tester,
    ) async {
      await twoWet();
      await pump(tester);
      expect(find.text('CALIBRATION HINT · NEW YORK'), findsOneWidget);
      expect(
        find.text(
          'Two bakes logged "too wet" with UK strong white. Suggest '
          'hydration ${pctText(hyd)}% → ${pctText(hyd - 2)}% on this recipe.',
        ),
        findsOneWidget,
      );
      final card = tester.widget<PizzaCard>(
        find.ancestor(
          of: find.text('Apply −2 pp'),
          matching: find.byType(PizzaCard),
        ),
      );
      expect(card.variant, PizzaCardVariant.hint);
      final apply = tester.widget<SecondaryButton>(
        find.widgetWithText(SecondaryButton, 'Apply −2 pp'),
      );
      expect(apply.success, isTrue);
      expect(
        tester.getSize(find.widgetWithText(SecondaryButton, 'Not now')).height,
        greaterThanOrEqualTo(44),
      );
      // Above the first bake.
      expect(
        tester.getTopLeft(find.text('Not now')).dy,
        lessThan(tester.getTopLeft(find.text('Friday NY').first).dy),
      );
      // Nothing applied by itself.
      expect(pc.read(recipeProvider).hydrationOverride, isNull);
    });

    testWidgets('Apply: hydration down, a toast, the card collapses', (
      tester,
    ) async {
      await twoWet();
      await pump(tester);
      await tester.tap(find.text('Apply −2 pp'));
      await tester.pump();
      expect(pc.read(outputsProvider).hydrationPct, r01(hyd - 2));
      expect(find.text('Hydration now ${pctText(hyd - 2)}%'), findsOneWidget);
      // Still there, collapsing, and a second tap does nothing.
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Apply −2 pp'), findsOneWidget);
      await tester.tap(find.text('Apply −2 pp'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(pc.read(outputsProvider).hydrationPct, r01(hyd - 2));
      expect(find.textContaining('Calibration hint'), findsNothing);
    });

    testWidgets('Not now: hidden and remembered, recipe untouched', (
      tester,
    ) async {
      await twoWet();
      await pump(tester);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.textContaining('CALIBRATION HINT'), findsNothing);
      expect(store.data[hintsStoreName], ['dough0:b']);
      expect(pc.read(recipeProvider).hydrationOverride, isNull);
    });

    testWidgets('reduced motion: gone on the next frame', (tester) async {
      await twoWet();
      await pump(tester, reduce: true);
      await tester.tap(find.text('Not now'));
      await tester.pump();
      // No 450 ms fold: with motion on it is still there now (see Apply).
      expect(find.textContaining('CALIBRATION HINT'), findsNothing);
    });

    testWidgets('an oven hint edits the oven', (tester) async {
      const burnt = {Outcome.bottom: 2};
      await log('a', 'Friday NY', PizzaStyle.newYork, outcomes: burnt);
      await log('b', 'Friday NY', PizzaStyle.newYork, outcomes: burnt);
      await pump(tester);
      await tester.tap(find.text('Apply −25 °C'));
      await tester.pumpAndSettle();
      expect(pc.read(ovenProvider).maxTempC, 250);
      expect(pc.read(recipeProvider).hydrationOverride, isNull);
      expect(find.textContaining('CALIBRATION HINT'), findsNothing);
    });

    testWidgets('shown under All and the recipe\'s style only', (tester) async {
      await twoWet();
      await log('c', 'Pan', PizzaStyle.detroit);
      await pump(tester);
      expect(find.textContaining('CALIBRATION HINT'), findsOneWidget);
      await tap(tester, find.text('Detroit'));
      expect(find.textContaining('CALIBRATION HINT'), findsNothing);
      await tap(tester, find.text('New York'));
      expect(find.textContaining('CALIBRATION HINT'), findsOneWidget);
    });
  });
}
