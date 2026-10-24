import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pizzalator/services/photos.dart';

const picker = MethodChannel('plugins.flutter.io/image_picker');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  late Directory docs;
  late String shot;
  String? picked;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('photos');
    addTearDown(() => docs.deleteSync(recursive: true));
    // Where image_picker leaves its (already resized) copy.
    shot = '${docs.path}/picker_cache.jpg';
    File(shot).writeAsBytesSync([1, 2, 3]);
    picked = shot;
    calls.clear();
    messenger.setMockMethodCallHandler(picker, (call) async {
      calls.add(call);
      return picked;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(picker, null));
  });

  test('pick: resized, copied into photos/, named by the file', () async {
    final store = PhotoStore(docs);
    final name = (await store.pick(ImageSource.camera))!;
    final args = calls.single.arguments as Map;
    expect(args['source'], ImageSource.camera.index);
    expect(args['maxWidth'], 1600);
    expect(args['imageQuality'], 85);
    expect(name, endsWith('.jpg'));
    expect(store.file(name).path, '${docs.path}/photos/$name');
    expect(store.file(name).readAsBytesSync(), [1, 2, 3]);

    // A second pick never lands on the first.
    final again = (await store.pick(ImageSource.gallery))!;
    expect(again, isNot(name));
    expect((calls.last.arguments as Map)['source'], ImageSource.gallery.index);
  });

  test('pick: backed out of the camera, nothing copied', () async {
    picked = null;
    expect(await PhotoStore(docs).pick(ImageSource.camera), isNull);
    expect(Directory('${docs.path}/photos').existsSync(), isFalse);
  });

  test('delete removes the file; a missing one is fine', () async {
    final store = PhotoStore(docs);
    final name = (await store.pick(ImageSource.camera))!;
    await store.delete(name);
    expect(store.file(name).existsSync(), isFalse);
    await store.delete(name);
  });

  test('photoStoreProvider must be overridden', () {
    final c = ProviderContainer.test();
    expect(() => c.read(photoStoreProvider), throwsA(anything));
  });
}
