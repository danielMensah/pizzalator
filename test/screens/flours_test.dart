import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pizzalator/core/calc.dart';
import 'package:pizzalator/core/label_scan.dart';
import 'package:pizzalator/routes.dart';
import 'package:pizzalator/screens/flours.dart';
import 'package:pizzalator/services/json_store.dart';
import 'package:pizzalator/services/label_scanner.dart';
import 'package:pizzalator/state/flours.dart';
import 'package:pizzalator/theme/pizza_theme.dart';
import 'package:pizzalator/widgets/widgets.dart';

import '../fakes.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late MemoryStore store;
  late FakeScanner scanner;
  late ProviderContainer c;

  setUp(() {
    store = MemoryStore();
    scanner = FakeScanner();
    c = ProviderContainer.test(
      overrides: [
        jsonStoreProvider.overrideWithValue(store),
        labelScannerProvider.overrideWithValue(scanner),
      ],
    );
  });

  List<Flour> mine() => c.read(customFloursProvider);
  const sains = Flour('Sainsbury’s strong white', 13.7, fibrePct: 3.1);
  const marriage = Flour(
    'Marriage’s wholemeal',
    12.9,
    wholegrain: true,
    fibrePct: 9.2,
    note: 'scanned',
  );

  Future<void> pump(
    WidgetTester tester, [
    List<Flour> flours = const [],
  ]) async {
    for (final f in flours.reversed) {
      await c.read(customFloursProvider.notifier).add(f);
    }
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: pizzaTheme(Brightness.dark),
          initialRoute: Routes.flours,
          routes: {
            Routes.calculator: (_) => const Scaffold(body: Text('Dough page')),
            // Non-const so the constructor itself runs under coverage.
            Routes.flours: (_) => FloursScreen(key: UniqueKey()),
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

  Finder field(String key) => find.byKey(ValueKey(key));
  String text(WidgetTester tester, String key) =>
      tester.widget<TextField>(field(key)).controller!.text;
  Future<void> type(WidgetTester tester, String key, String value) async {
    await tester.enterText(field(key), value);
    await tester.pump();
  }

  bool saveEnabled(WidgetTester tester) => tester
      .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save flour'))
      .enabled;
  bool wholegrain(WidgetTester tester) =>
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value;

  testWidgets('lists my flours and the presets, mockup copy', (tester) async {
    await pump(tester, [sains, marriage]);
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('SETTINGS')).style!.color,
      PizzaColors.dark.inkMuted,
      reason: 'mockup: the muted label colour',
    );
    expect(find.text('Flours'), findsOneWidget);
    expect(find.text('Calculator'), findsOneWidget);
    expect(find.text('12 FLOURS'), findsOneWidget);
    expect(find.text('Add by hand'), findsOneWidget);
    expect(find.text('MY FLOURS'), findsOneWidget);
    expect(find.text('PRESETS · TAP TO DUPLICATE AND EDIT'), findsOneWidget);
    // Mine: sub-line from note and fibre; pill by type.
    expect(find.text('Sainsbury’s strong white'), findsOneWidget);
    expect(find.text('fibre 3.1 g'), findsOneWidget);
    expect(find.text('13.7%'), findsOneWidget);
    expect(find.text('scanned · fibre 9.2 g'), findsOneWidget);
    expect(find.text('mine'), findsOneWidget);
    expect(find.text('wholemeal'), findsNWidgets(2));
    expect(find.text('white'), findsNWidgets(9));
    // Presets: their note, or "preset".
    expect(find.text('Caputo Pizzeria class'), findsOneWidget);
    expect(find.text('absorbs ~75%'), findsOneWidget);
    expect(find.text('preset'), findsNWidgets(3));
    expect(find.text('14.5%'), findsOneWidget);
    expect(find.textContaining('Bags never print W strength.'), findsOneWidget);
    // Mine come first, newest on top.
    expect(
      tester.getTopLeft(find.text('Sainsbury’s strong white')).dy,
      lessThan(tester.getTopLeft(find.text('Marriage’s wholemeal')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Marriage’s wholemeal')).dy,
      lessThan(tester.getTopLeft(find.text('Italian 00 pizza')).dy),
    );
    final row = find.ancestor(
      of: find.text('UK plain'),
      matching: find.byType(ConstrainedBox),
    );
    expect(tester.getSize(row.first).height, greaterThanOrEqualTo(56));
  });

  testWidgets('the list ends above the system navigation bar', (tester) async {
    tester.view.padding = const FakeViewPadding(bottom: 48);
    await pump(tester);
    expect(
      tester.widget<ListView>(find.byType(ListView)).padding,
      const EdgeInsets.fromLTRB(20, 4, 20, 24 + 48),
    );
  });

  testWidgets('a flour with no note or fibre reads "custom"', (tester) async {
    await pump(tester, [const Flour('Bare', 12)]);
    expect(find.text('custom'), findsOneWidget);
  });

  testWidgets('no flours of mine yet: the mark and a line of copy', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('10 FLOURS'), findsOneWidget);
    expect(find.textContaining('None yet'), findsOneWidget);
    expect(find.byType(PizzaMark), findsOneWidget);
    expect(find.text('mine'), findsNothing);
  });

  testWidgets('add by hand: Save only for a name and label values', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, find.text('Add by hand'));
    expect(find.text('New flour'), findsOneWidget);
    expect(find.text('Delete flour'), findsNothing);
    expect(saveEnabled(tester), isFalse);

    await type(tester, 'name', '  Doves strong  ');
    expect(saveEnabled(tester), isFalse, reason: 'no protein');
    await type(tester, 'protein', '4');
    expect(saveEnabled(tester), isFalse, reason: 'protein under 5 g');
    await type(tester, 'protein', '21');
    expect(saveEnabled(tester), isFalse, reason: 'protein over 20 g');
    for (final edge in ['5', '20']) {
      await type(tester, 'protein', edge);
      expect(saveEnabled(tester), isTrue, reason: 'protein $edge g is in');
    }
    await type(tester, 'protein', '13,7');
    expect(saveEnabled(tester), isTrue, reason: 'decimal comma');
    await type(tester, 'fibre', '16');
    expect(saveEnabled(tester), isFalse, reason: 'fibre over 15 g');
    for (final edge in ['0', '15']) {
      await type(tester, 'fibre', edge);
      expect(saveEnabled(tester), isTrue, reason: 'fibre $edge g is in');
    }
    await type(tester, 'fibre', 'x');
    expect(saveEnabled(tester), isFalse, reason: 'not a number');
    await type(tester, 'fibre', '3.1');
    expect(saveEnabled(tester), isTrue);
    await type(tester, 'name', ' ');
    expect(saveEnabled(tester), isFalse, reason: 'blank name');
    await type(tester, 'name', 'Doves strong ');

    await tap(tester, find.text('Save flour'));
    expect(mine(), [const Flour('Doves strong', 13.7, fibrePct: 3.1)]);
    expect(mine().single.note, '');
    expect(store.data[floursStoreName], hasLength(1));
    expect(find.text('Saved to my flours'), findsOneWidget);
    expect(find.text('New flour'), findsNothing, reason: 'sheet closed');
    expect(find.text('Doves strong'), findsOneWidget);
    expect(find.text('11 FLOURS'), findsOneWidget);
  });

  testWidgets('wholegrain follows fibre until flipped by hand', (tester) async {
    await pump(tester);
    await tap(tester, find.text('Add by hand'));
    expect(wholegrain(tester), isFalse);
    expect(find.text('Auto-set from fibre ≥ 6 g'), findsOneWidget);

    await type(tester, 'fibre', '9,2');
    expect(wholegrain(tester), isTrue);
    expect(find.text('Fibre 9.2 g → wholegrain'), findsOneWidget);
    await type(tester, 'fibre', '3.1');
    expect(wholegrain(tester), isFalse);
    expect(find.text('Fibre 3.1 g → white flour'), findsOneWidget);
    await type(tester, 'fibre', '');
    expect(wholegrain(tester), isFalse, reason: 'blank leaves it');
    expect(find.text('Auto-set from fibre ≥ 6 g'), findsOneWidget);

    await type(tester, 'fibre', '3.1');
    await tap(tester, find.byType(SwitchListTile));
    expect(wholegrain(tester), isTrue);
    expect(find.text('Set by hand'), findsOneWidget);
    await type(tester, 'fibre', '2');
    expect(wholegrain(tester), isTrue, reason: 'set by hand stays');

    await type(tester, 'name', 'Rye-ish');
    await type(tester, 'protein', '11');
    await tap(tester, find.text('Save flour'));
    expect(
      mine().single,
      const Flour('Rye-ish', 11, wholegrain: true, fibrePct: 2),
    );
  });

  testWidgets('a switch set by hand stays set by hand when edited', (
    tester,
  ) async {
    const rye = Flour('Rye-ish', 11, wholegrain: true, fibrePct: 2);
    await pump(tester, [rye]);
    await tap(tester, find.text('Rye-ish'));
    expect(wholegrain(tester), isTrue);
    expect(find.text('Set by hand'), findsOneWidget);
    await type(tester, 'fibre', '2.1');
    expect(wholegrain(tester), isTrue, reason: 'fibre no longer sets it');
  });

  testWidgets('values round to label precision, as shown when edited', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, find.text('Add by hand'));
    await type(tester, 'name', 'Doves strong');
    await type(tester, 'protein', '12.76');
    await type(tester, 'fibre', '3.14');
    await tap(tester, find.text('Save flour'));
    expect(mine(), [const Flour('Doves strong', 12.8, fibrePct: 3.1)]);
    await tap(tester, find.text('Doves strong'));
    expect(text(tester, 'protein'), '12.8');
    expect(text(tester, 'fibre'), '3.1');
  });

  testWidgets('a name another flour has: no Save, and why', (tester) async {
    await pump(tester, [sains]);
    await tap(tester, find.text('Add by hand'));
    await type(tester, 'protein', '13');
    await type(tester, 'name', 'SAINSBURY’S STRONG WHITE ');
    expect(saveEnabled(tester), isFalse, reason: 'one of mine');
    expect(find.text('Another flour has this name'), findsOneWidget);
    await type(tester, 'name', 'UK plain');
    expect(saveEnabled(tester), isFalse, reason: 'a preset');
    await type(tester, 'name', 'Doves strong');
    expect(saveEnabled(tester), isTrue);
    expect(find.text('Another flour has this name'), findsNothing);
  });

  testWidgets('tap my flour: edit it in place, note kept', (tester) async {
    await pump(tester, [marriage, sains]);
    await tap(tester, find.text('Sainsbury’s strong white'));
    expect(find.text('Edit flour'), findsOneWidget);
    expect(text(tester, 'name'), 'Sainsbury’s strong white');
    expect(text(tester, 'protein'), '13.7');
    expect(text(tester, 'fibre'), '3.1');
    expect(wholegrain(tester), isFalse);
    expect(find.text('Fibre 3.1 g → white flour'), findsOneWidget);

    await type(tester, 'protein', '13.5');
    await tap(tester, find.text('Save flour'));
    expect(mine(), [
      marriage,
      const Flour('Sainsbury’s strong white', 13.5, fibrePct: 3.1),
    ]);

    // Editing keeps a scanned flour's note; clearing fibre drops it.
    await tap(tester, find.text('Marriage’s wholemeal'));
    expect(wholegrain(tester), isTrue);
    await type(tester, 'fibre', '');
    await tap(tester, find.text('Save flour'));
    expect(
      mine().first,
      const Flour('Marriage’s wholemeal', 12.9, wholegrain: true),
    );
    expect(mine().first.note, 'scanned');
    expect(find.text('scanned'), findsOneWidget);
  });

  testWidgets('delete flour, in alert colours', (tester) async {
    await pump(tester, [sains, marriage]);
    await tap(tester, find.text('Marriage’s wholemeal'));
    final delete = find.widgetWithText(SecondaryButton, 'Delete flour');
    expect(tester.widget<SecondaryButton>(delete).alert, isTrue);
    await tap(tester, delete);
    expect(mine(), [sains]);
    expect(store.data[floursStoreName], [sains.toJson()]);
    expect(find.text('Edit flour'), findsNothing);
    expect(find.text('Marriage’s wholemeal'), findsNothing);
  });

  testWidgets('tap a preset: a prefilled copy, saved as mine', (tester) async {
    await pump(tester);
    await tap(tester, find.text('Italian 00 pizza'));
    expect(find.text('New flour'), findsOneWidget);
    expect(find.text('Delete flour'), findsNothing);
    expect(text(tester, 'name'), 'Italian 00 pizza');
    expect(text(tester, 'protein'), '12.5');
    expect(text(tester, 'fibre'), '');
    // An unchanged copy would equal the preset and hide behind it.
    expect(saveEnabled(tester), isFalse, reason: 'the preset has the name');
    expect(find.text('Another flour has this name'), findsOneWidget);

    await type(tester, 'name', 'Caputo Nuvola');
    expect(saveEnabled(tester), isTrue);
    await tap(tester, find.text('Save flour'));
    expect(mine(), [const Flour('Caputo Nuvola', 12.5)]);
    expect(mine().single.note, '', reason: 'the preset note is not mine');
    expect(Flour.presets.first.name, 'Italian 00 pizza');

    // The wholemeal preset copies as wholegrain.
    await tap(tester, find.text('Wholemeal'));
    expect(wholegrain(tester), isTrue);
  });

  testWidgets('Close leaves without saving', (tester) async {
    await pump(tester);
    await tap(tester, find.text('Add by hand'));
    await type(tester, 'name', 'Half typed');
    await tap(tester, find.text('Close'));
    expect(find.text('New flour'), findsNothing);
    expect(mine(), isEmpty);
  });

  group('label scan', () {
    const photo = '/cache/label.jpg';
    // A 1000 × 800 photo of a UK panel: per 100 g, then per 80 g.
    OcrLine l(String t, double x, double y, double w) =>
        OcrLine(t, x, y, x + w, y + 30);
    final uk = LabelScan(photo, const Size(1000, 800), [
      l('Typical values', 20, 100, 280),
      l('Per 100g', 400, 100, 160),
      l('Per 80g', 700, 100, 160),
      l('Fibre', 20, 300, 180),
      l('3.1g', 400, 300, 100),
      l('2.5g', 700, 300, 100),
      l('Protein', 20, 350, 200),
      l('13.7g', 400, 350, 120),
      l('11.0g', 700, 350, 120),
    ]);
    // Wholemeal, two columns and no header to say which is per 100 g.
    final unsure = LabelScan(photo, const Size(1000, 800), [
      l('Fibre 9.2g 7.4g', 20, 300, 500),
      l('Protein 12.9g 10.3g', 20, 350, 500),
    ]);
    Color border(WidgetTester tester, String key) =>
        (tester.widget<TextField>(field(key)).decoration!.enabledBorder!
                as OutlineInputBorder)
            .borderSide
            .color;

    testWidgets('Scan a bag leads, left of Add by hand; gallery link', (
      tester,
    ) async {
      await pump(tester);
      final scan = find.widgetWithText(PrimaryButton, 'Scan a bag');
      expect(
        tester.widget<PrimaryButton>(scan).icon,
        Icons.photo_camera_outlined,
      );
      final byHand = find.widgetWithText(SecondaryButton, 'Add by hand');
      expect(tester.getCenter(scan).dx, lessThan(tester.getCenter(byHand).dx));
      expect(tester.getSize(scan).height, tester.getSize(byHand).height);
      // One shape and type for the pair, as the mockup's .btn.
      final pri = tester
          .widget<FilledButton>(
            find.descendant(of: scan, matching: find.byType(FilledButton)),
          )
          .style!;
      final sec = tester
          .widget<OutlinedButton>(
            find.descendant(of: byHand, matching: find.byType(OutlinedButton)),
          )
          .style!;
      expect(pri.shape!.resolve({}), sec.shape!.resolve({}));
      expect(pri.textStyle!.resolve({}), sec.textStyle!.resolve({}));
      expect(
        tester.getTopLeft(find.text('Read a photo from the gallery')).dy,
        greaterThan(tester.getBottomLeft(scan).dy),
      );
    });

    testWidgets('found the panel: values prefilled, lines boxed, saved', (
      tester,
    ) async {
      scanner.next = uk;
      await pump(tester);
      await tap(tester, find.text('Scan a bag'));
      expect(scanner.sources, [ImageSource.camera]);
      expect(find.text('ON-DEVICE OCR'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('ON-DEVICE OCR')).style!.color,
        PizzaColors.dark.emberBright,
      );
      expect(find.text('Found the panel'), findsOneWidget);
      expect(find.text('New flour'), findsNothing);
      expect(
        find.text('Protein and fibre read from the per-100 g column'),
        findsOneWidget,
      );
      expect(text(tester, 'protein'), '13.7');
      expect(text(tester, 'fibre'), '3.1');
      expect(text(tester, 'name'), '');
      for (final k in ['protein', 'fibre']) {
        expect(border(tester, k), PizzaColors.dark.sage, reason: k);
      }
      expect(border(tester, 'name'), PizzaColors.dark.lineStrong);
      expect(wholegrain(tester), isFalse);
      expect(find.text('Fibre 3.1 g → white flour'), findsOneWidget);

      // The photo, contained in 220 px (scale 0.275), with the read lines
      // boxed: Protein and its value, Fibre and its value.
      final image = find.byType(Image);
      final provider = tester.widget<Image>(image).image as ResizeImage;
      expect((provider.imageProvider as FileImage).file.path, photo);
      final shown = tester.getRect(image);
      expect(shown.size, const Size(275, 220));
      final hits = find.byKey(const ValueKey('hit'));
      expect(hits, findsNWidgets(4));
      final protein = tester.getRect(hits.first);
      expect(protein.topLeft - shown.topLeft, const Offset(5.5, 96.25));
      expect(protein.size, const Size(55, 8.25));

      expect(saveEnabled(tester), isFalse, reason: 'no name yet');
      await type(tester, 'name', 'Sainsbury’s strong white');
      await tap(tester, find.text('Save flour'));
      expect(mine(), [
        const Flour('Sainsbury’s strong white', 13.7, fibrePct: 3.1),
      ]);
      expect(mine().single.note, 'scanned');
      expect(find.text('Saved to my flours'), findsOneWidget);
      expect(find.text('scanned · fibre 3.1 g'), findsOneWidget);
    });

    testWidgets('gallery photo, columns disagree: check against the bag', (
      tester,
    ) async {
      scanner.next = unsure;
      await pump(tester);
      await tap(tester, find.text('Read a photo from the gallery'));
      expect(scanner.sources, [ImageSource.gallery]);
      expect(find.text('Could not read the panel'), findsOneWidget);
      expect(find.text('Check these against the bag'), findsOneWidget);
      expect(text(tester, 'protein'), '12.9');
      expect(text(tester, 'fibre'), '9.2');
      expect(wholegrain(tester), isTrue, reason: 'fibre 9.2 g');
      expect(find.text('Fibre 9.2 g → wholegrain'), findsOneWidget);
    });

    testWidgets('nothing on the photo: manual entry, photo still shown', (
      tester,
    ) async {
      scanner.next = LabelScan(photo, const Size(1000, 800), const []);
      await pump(tester);
      await tap(tester, find.text('Scan a bag'));
      expect(find.text('Could not read the panel'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.byKey(const ValueKey('hit')), findsNothing);
      expect(text(tester, 'protein'), '');
      expect(border(tester, 'protein'), PizzaColors.dark.lineStrong);
      await type(tester, 'name', 'Typed');
      await type(tester, 'protein', '12');
      await tap(tester, find.text('Save flour'));
      expect(mine().single.note, '', reason: 'nothing came off the label');
    });

    testWidgets('one scan at a time: taps while it runs do nothing', (
      tester,
    ) async {
      scanner
        ..next = uk
        ..gate = Completer<void>();
      await pump(tester);
      await tap(tester, find.text('Scan a bag'));
      final button = find.widgetWithText(FilledButton, 'Scan a bag');
      expect(tester.widget<FilledButton>(button).enabled, isFalse);
      await tap(tester, find.text('Scan a bag'));
      await tap(tester, find.text('Read a photo from the gallery'));
      expect(scanner.sources, [ImageSource.camera]);
      expect(find.byType(BottomSheet), findsNothing);

      scanner.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Found the panel'), findsOneWidget);
      await tap(tester, find.text('Close'));
      expect(tester.widget<FilledButton>(button).enabled, isTrue);

      // A failed scan frees the button too.
      scanner
        ..gate = null
        ..error = PlatformException(code: 'no-camera');
      await tap(tester, find.text('Read a photo from the gallery'));
      await tap(tester, find.text('Close'));
      expect(tester.widget<FilledButton>(button).enabled, isTrue);
      expect(scanner.sources, [ImageSource.camera, ImageSource.gallery]);
    });

    testWidgets('fibre off the label range leaves wholegrain off', (
      tester,
    ) async {
      // "3.1" read as 31: a dropped decimal point.
      scanner.next = LabelScan(photo, const Size(1000, 800), [
        l('Fibre 31g', 20, 300, 500),
        l('Protein 13.7g', 20, 350, 500),
      ]);
      await pump(tester);
      await tap(tester, find.text('Scan a bag'));
      expect(text(tester, 'fibre'), '31');
      expect(wholegrain(tester), isFalse);
      expect(find.text('Auto-set from fibre ≥ 6 g'), findsOneWidget);
    });

    testWidgets('backed out of the camera: no sheet', (tester) async {
      await pump(tester);
      await tap(tester, find.text('Scan a bag'));
      expect(scanner.sources, [ImageSource.camera]);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('the scanner fails: the same sheet, typed by hand', (
      tester,
    ) async {
      scanner.error = PlatformException(code: 'no-camera');
      await pump(tester);
      await tap(tester, find.text('Scan a bag'));
      expect(find.text('ON-DEVICE OCR'), findsOneWidget);
      expect(find.text('Could not read the panel'), findsOneWidget);
      expect(find.text('Check these against the bag'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.byType(SnackBar), findsNothing, reason: 'no toast');
      await type(tester, 'name', 'Doves strong');
      await type(tester, 'protein', '13');
      await tap(tester, find.text('Save flour'));
      expect(mine(), [const Flour('Doves strong', 13)]);
    });
  });

  testWidgets('back link returns to the calculator', (tester) async {
    await pump(tester);
    await tap(tester, find.text('Calculator'));
    expect(find.text('Dough page'), findsOneWidget);
  });
}
