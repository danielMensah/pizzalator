import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pizzalator/services/label_scanner.dart';

const picker = MethodChannel('plugins.flutter.io/image_picker');
const ocr = MethodChannel('google_mlkit_text_recognizer');

Map<String, Object?> rect(double l, double t, double r, double b) => {
  'left': l,
  'top': t,
  'right': r,
  'bottom': b,
};

Map<String, Object?> line(String text, Map<String, Object?> box) => {
  'text': text,
  'rect': box,
  'recognizedLanguages': <Object?>[],
  'points': <Object?>[],
  'elements': <Object?>[],
  'confidence': 0.9,
  'angle': 0.0,
};

/// What ML Kit's Android side sends back: blocks of lines.
final recognised = {
  'text': 'Fibre 3.1g\nProtein 13.7g',
  'blocks': [
    {
      'text': 'Fibre 3.1g\nProtein 13.7g',
      'rect': rect(10, 20, 200, 80),
      'recognizedLanguages': <Object?>[],
      'points': <Object?>[],
      'lines': [
        line('Fibre 3.1g', rect(10, 20, 190, 44)),
        line('Protein 13.7g', rect(10, 56, 200, 80)),
      ],
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  late String photo;
  Object? Function(MethodCall) onOcr = (_) => recognised;
  String? picked = '';

  setUpAll(() async {
    // A real 3 × 2 PNG, so the size comes from the file's header.
    final r = ui.PictureRecorder();
    ui.Canvas(r).drawPaint(ui.Paint());
    final image = await r.endRecording().toImage(3, 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory.systemTemp.createTempSync('label_scan');
    photo = '${dir.path}/label.png';
    File(photo).writeAsBytesSync(png!.buffer.asUint8List());
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  setUp(() {
    calls.clear();
    onOcr = (_) => recognised;
    picked = photo;
    messenger
      ..setMockMethodCallHandler(picker, (call) async {
        calls.add(call);
        return picked;
      })
      ..setMockMethodCallHandler(ocr, (call) async {
        calls.add(call);
        return call.method == 'vision#startTextRecognizer' ? onOcr(call) : null;
      });
  });

  tearDown(() {
    messenger
      ..setMockMethodCallHandler(picker, null)
      ..setMockMethodCallHandler(ocr, null);
  });

  test('camera photo → lines in image pixels, Latin model, closed', () async {
    final scan = (await LabelScanner().scan(ImageSource.camera))!;
    expect(calls.map((c) => c.method), [
      'pickImage',
      'vision#startTextRecognizer',
      'vision#closeTextRecognizer',
    ]);
    expect((calls[0].arguments as Map)['source'], ImageSource.camera.index);
    final args = calls[1].arguments as Map;
    expect(args['script'], 0, reason: 'Latin');
    expect((args['imageData'] as Map)['path'], photo);
    expect((args['imageData'] as Map)['type'], 'file');
    expect(
      (calls[2].arguments as Map)['id'],
      args['id'],
      reason: 'the recognizer that ran is the one closed',
    );

    expect(scan.imagePath, photo);
    expect(scan.size, const ui.Size(3, 2));
    expect(scan.lines.map((l) => l.text), ['Fibre 3.1g', 'Protein 13.7g']);
    final p = scan.lines.last;
    expect([p.left, p.top, p.right, p.bottom], [10, 56, 200, 80]);
  });

  test('gallery works the same way', () async {
    await LabelScanner().scan(ImageSource.gallery);
    expect((calls[0].arguments as Map)['source'], ImageSource.gallery.index);
  });

  test('cancelled at the camera: null, no OCR', () async {
    picked = null;
    expect(await LabelScanner().scan(ImageSource.camera), isNull);
    expect(calls.map((c) => c.method), ['pickImage']);
  });

  test('OCR fails: the error surfaces, the recognizer still closes', () async {
    onOcr = (_) => throw PlatformException(code: 'no-model');
    await expectLater(
      LabelScanner().scan(ImageSource.camera),
      throwsA(isA<PlatformException>()),
    );
    expect(calls.last.method, 'vision#closeTextRecognizer');
  });

  test('labelScannerProvider is the real scanner by default', () {
    final c = ProviderContainer.test();
    expect(c.read(labelScannerProvider), isA<LabelScanner>());
  });
}
