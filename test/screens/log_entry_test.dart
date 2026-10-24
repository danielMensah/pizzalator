import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pizzalator/core/bake_log.dart';
import 'package:pizzalator/core/calc.dart';
import 'package:pizzalator/core/export_text.dart';
import 'package:pizzalator/core/oven.dart';
import 'package:pizzalator/routes.dart';
import 'package:pizzalator/screens/log_entry.dart';
import 'package:pizzalator/services/json_store.dart';
import 'package:pizzalator/services/photos.dart';
import 'package:pizzalator/state/bake_log.dart';
import 'package:pizzalator/state/recipe.dart';
import 'package:pizzalator/state/recipes.dart';
import 'package:pizzalator/state/timer_run.dart';
import 'package:pizzalator/theme/pizza_theme.dart';
import 'package:pizzalator/widgets/widgets.dart';

import '../fakes.dart';

const c = PizzaColors.dark;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late MemoryStore store;
  late FakePhotoStore photos;
  late ProviderContainer pc;
  // A Saturday evening.
  final now = DateTime(2026, 10, 24, 20);

  setUp(() {
    store = MemoryStore();
    photos = FakePhotoStore();
    pc = ProviderContainer.test(
      overrides: [
        jsonStoreProvider.overrideWithValue(store),
        photoStoreProvider.overrideWithValue(photos),
        clockProvider.overrideWithValue(() => now),
      ],
    );
  });

  List<BakeEntry> log() => pc.read(bakeLogProvider);

  final friday = BakeEntry(
    id: 'f1',
    date: DateTime(2026, 10, 16, 20),
    name: 'Friday NY',
    inputs: const RecipeInputs(style: PizzaStyle.newYork),
    oven: OvenSetup.homeStone,
    rating: 3,
    outcomes: const {Outcome.dough: 0},
    roomC: 22,
    fridgeH: 46,
    ovenC: 275,
    bakeMin: 6,
    photo: 'old.jpg',
    notes: 'Floppy centre.',
  );

  /// The entry screen over a log page, so Save and Back have somewhere to
  /// land; [id] is the route argument.
  Future<void> pump(WidgetTester tester, {String? id}) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: pc,
        child: MaterialApp(
          theme: pizzaTheme(Brightness.dark),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  Routes.logEntry,
                  arguments: id,
                ),
                child: const Text('Log page'),
              ),
            ),
          ),
          routes: {
            Routes.logEntry: (context) => LogEntryScreen(
              id: ModalRoute.of(context)!.settings.arguments as String?,
            ),
          },
        ),
      ),
    );
    await tester.tap(find.text('Log page'));
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

  String field(WidgetTester tester, String key) =>
      tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

  Future<void> type(WidgetTester tester, String key, String text) async {
    await tester.enterText(find.byKey(ValueKey(key)), text);
    await tester.pump();
  }

  Segmented<int> row(WidgetTester tester, Outcome o) =>
      tester.widget<Segmented<int>>(find.byKey(ValueKey(o)));

  testWidgets('new: the working copy, named by style, plan prefilled', (
    tester,
  ) async {
    pc.read(recipeProvider.notifier).setStyle(PizzaStyle.newYork);
    pc.read(recipeProvider.notifier).setRoomC(22);
    await pump(tester);
    final i = pc.read(recipeProvider);
    expect(find.text('Log this bake'), findsOneWidget);
    expect(find.text('Bake log'), findsOneWidget);
    expect(
      find.text(
        'New York · ${dayText(now)} · '
        '${pctText(calc(i).hydrationPct)}% · steel',
      ),
      findsOneWidget,
    );
    expect(field(tester, 'room'), '22');
    expect(
      field(tester, 'fridge'),
      pctText(StagePlan.of(i.activePlan).fridgeH),
    );
    expect(field(tester, 'oven'), '275');
    expect(field(tester, 'bake'), '');
    expect(find.text('Tap a star'), findsOneWidget);
    expect(find.text('Add photo'), findsOneWidget);
    expect(find.text('Delete bake'), findsNothing);
    for (final o in Outcome.values) {
      expect(row(tester, o).value, 1, reason: o.name);
      expect(row(tester, o).selectedFill, c.sageTint, reason: o.name);
    }
  });

  testWidgets('new from a saved recipe: its name', (tester) async {
    await pc.read(savedRecipesProvider.notifier).saveAs('Friday NY');
    await pump(tester);
    expect(find.textContaining('Friday NY · '), findsOneWidget);
  });

  testWidgets('stars: 44 px targets, rating words', (tester) async {
    await pump(tester);
    final star = find.byTooltip('4 stars');
    expect(tester.getSize(star), const Size.square(44));
    await tap(tester, star);
    expect(find.text('Good'), findsOneWidget);
    final lit = tester
        .widgetList<Icon>(find.byIcon(Icons.star_rounded))
        .where((i) => i.color == c.emberBright);
    expect(lit, hasLength(4));
    await tap(tester, find.byTooltip('1 star'));
    expect(find.text('Bin it'), findsOneWidget);
    await tap(tester, find.byTooltip('5 stars'));
    expect(find.text('Best yet'), findsOneWidget);
  });

  testWidgets('outcomes: a bad pick turns alert, an open crumb sage', (
    tester,
  ) async {
    await pump(tester);
    await tapText(tester, 'too wet');
    expect(row(tester, Outcome.dough).value, 0);
    expect(row(tester, Outcome.dough).selectedFill, c.alertTint);
    expect(row(tester, Outcome.dough).selectedInk, c.alert);
    await tapText(tester, 'open');
    expect(row(tester, Outcome.crumb).selectedFill, c.sageTint);
    expect(row(tester, Outcome.crumb).selectedInk, c.sageBright);
  });

  testWidgets('save: everything on the screen, on top; toast, back', (
    tester,
  ) async {
    await pump(tester);
    await tap(tester, find.byTooltip('4 stars'));
    await tapText(tester, 'under');
    await type(tester, 'room', '23,5');
    await type(tester, 'fridge', '');
    await type(tester, 'bake', 'abc');
    await type(tester, 'oven', '250');
    await tapText(tester, 'Add photo');
    await tapText(tester, 'Gallery');
    expect(photos.sources, [ImageSource.gallery]);
    expect(find.text('Photo added · tap to replace'), findsOneWidget);
    await type(tester, 'notes', '  Rim blistered well.  ');
    await tapText(tester, 'Save bake');

    expect(find.text('Log page'), findsOneWidget);
    expect(
      find.text('Saved · calibration will update after 2 logs'),
      findsOneWidget,
    );
    final e = log().single;
    expect(e.rating, 4);
    expect(e.choice(Outcome.proof), 0);
    expect(e.choice(Outcome.dough), 1);
    expect([e.roomC, e.fridgeH, e.ovenC, e.bakeMin], [23.5, null, 250, null]);
    expect(e.photo, 'p1.jpg');
    expect(e.notes, 'Rim blistered well.');
    expect(e.date, now);
    expect(store.data[bakesStoreName], hasLength(1));
    expect(photos.deleted, isEmpty);
  });

  testWidgets('photo: camera; backing out keeps what was there', (
    tester,
  ) async {
    await pump(tester);
    await tapText(tester, 'Add photo');
    await tapText(tester, 'Camera');
    expect(photos.sources, [ImageSource.camera]);
    photos.next = null;
    await tapText(tester, 'Photo added · tap to replace');
    await tapText(tester, 'Gallery');
    expect(find.text('Photo added · tap to replace'), findsOneWidget);
    // Sheet dismissed: no picker at all.
    await tapText(tester, 'Photo added · tap to replace');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(photos.sources, hasLength(2));
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      ((image.image as ResizeImage).imageProvider as FileImage).file.path,
      photos.file('p1.jpg').path,
    );
  });

  testWidgets('photo: a picker error says so, nothing changes', (tester) async {
    await pump(tester);
    photos.error = PlatformException(code: 'camera_access_denied');
    await tapText(tester, 'Add photo');
    await tapText(tester, 'Camera');
    expect(find.text('Could not add the photo'), findsOneWidget);
    expect(find.text('Add photo'), findsOneWidget);
  });

  testWidgets('a photo picked and dropped is deleted, not left behind', (
    tester,
  ) async {
    await pump(tester);
    await tapText(tester, 'Add photo');
    await tapText(tester, 'Camera');
    photos.next = 'p2.jpg';
    await tapText(tester, 'Photo added · tap to replace');
    await tapText(tester, 'Camera');
    expect(photos.deleted, ['p1.jpg']);
    await tapText(tester, 'Bake log');
    expect(find.text('Log page'), findsOneWidget);
    expect(photos.deleted, ['p1.jpg', 'p2.jpg']);
    expect(log(), isEmpty);
  });

  testWidgets('edit: a replacement photo dropped goes, the logged one stays', (
    tester,
  ) async {
    await pc.read(bakeLogProvider.notifier).add(friday);
    await pump(tester, id: 'f1');
    await tapText(tester, 'Photo added · tap to replace');
    await tapText(tester, 'Camera');
    await tapText(tester, 'Bake log');
    expect(find.text('Log page'), findsOneWidget);
    expect(photos.deleted, ['p1.jpg']);
    expect(log().single.photo, 'old.jpg');
  });

  testWidgets('edit: the bake as logged; save keeps its id and date', (
    tester,
  ) async {
    await pc.read(bakeLogProvider.notifier).add(friday);
    await pump(tester, id: 'f1');
    expect(find.text('Edit bake'), findsOneWidget);
    expect(
      find.text(
        'Friday NY · Fri 16 Oct · '
        '${pctText(calc(friday.inputs).hydrationPct)}% · stone',
      ),
      findsOneWidget,
    );
    expect(find.text('Decent'), findsOneWidget);
    expect(row(tester, Outcome.dough).value, 0);
    expect(field(tester, 'room'), '22');
    expect(field(tester, 'fridge'), '46');
    expect(field(tester, 'bake'), '6');
    expect(field(tester, 'notes'), 'Floppy centre.');
    expect(find.text('Photo added · tap to replace'), findsOneWidget);

    await tap(tester, find.byTooltip('5 stars'));
    await tapText(tester, 'Photo added · tap to replace');
    await tapText(tester, 'Camera');
    await tapText(tester, 'Save bake');
    final e = log().single;
    expect([e.id, e.date, e.rating, e.photo], ['f1', friday.date, 5, 'p1.jpg']);
    // The replaced photo goes once the log stops pointing at it.
    expect(photos.deleted, ['old.jpg']);
  });

  testWidgets('delete asks first; Keep it keeps it', (tester) async {
    await pc.read(bakeLogProvider.notifier).add(friday);
    await pump(tester, id: 'f1');
    await tapText(tester, 'Delete bake');
    expect(find.text('Delete this bake?'), findsOneWidget);
    await tapText(tester, 'Keep it');
    expect(log(), hasLength(1));
    expect(find.text('Edit bake'), findsOneWidget);

    await tapText(tester, 'Delete bake');
    await tap(
      tester,
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Delete'),
      ),
    );
    expect(log(), isEmpty);
    expect(photos.deleted, ['old.jpg']);
    expect(find.text('Log page'), findsOneWidget);
  });

  testWidgets('an id that is gone logs a new bake instead', (tester) async {
    await pump(tester, id: 'gone');
    expect(find.text('Log this bake'), findsOneWidget);
  });
}
