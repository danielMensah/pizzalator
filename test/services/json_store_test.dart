import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pizzalator/services/json_store.dart';

void main() {
  late Directory dir;
  late JsonStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('json_store_test');
    store = JsonStore(dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  File file(String name) => File('${dir.path}/$name.json');

  test('missing file reads as null', () async {
    expect(await store.read('nope'), isNull);
  });

  test('write then read round-trips, one file per name', () async {
    await store.write('a', {
      'x': 1,
      'y': [true, 'z'],
    });
    await store.write('b', [1.5]);
    expect(await store.read('a'), {
      'x': 1,
      'y': [true, 'z'],
    });
    expect(await store.read('b'), [1.5]);
    expect(file('a').existsSync(), isTrue);
    expect(dir.listSync().where((f) => f.path.endsWith('.tmp')), isEmpty);
  });

  test('corrupt JSON reads as null', () async {
    file('a').writeAsStringSync('{"x": ');
    expect(await store.read('a'), isNull);
  });

  test('non UTF-8 bytes read as null', () async {
    file('a').writeAsBytesSync([0xff, 0xfe, 0xfd]);
    expect(await store.read('a'), isNull);
  });

  test('a failed write keeps the previous good file', () async {
    await store.write('a', {'v': 1});
    await expectLater(store.write('a', {'v': Object()}), throwsA(anything));
    expect(await store.read('a'), {'v': 1});
  });

  test('a stray temp file from a killed write is ignored', () async {
    await store.write('a', {'v': 1});
    File('${file('a').path}.tmp').writeAsStringSync('{"v": ');
    expect(await store.read('a'), {'v': 1});
    await store.write('a', {'v': 2});
    expect(await store.read('a'), {'v': 2});
  });

  test('overlapping writes land in call order; a failure does not block', () {
    final writes = [
      for (var i = 0; i < 20; i++) store.write('a', {'v': i}),
      store.write('a', {'v': Object()}).catchError((Object _) {}),
      store.write('a', {'v': 'last'}),
    ];
    return Future.wait(writes).then((_) async {
      expect(await store.read('a'), {'v': 'last'});
    });
  });

  test('keepBad moves the file aside; a missing file is fine', () async {
    await store.write('a', {'v': 1});
    await store.keepBad('a');
    expect(await store.read('a'), isNull);
    expect(File('${file('a').path}.bad').readAsStringSync(), '{"v":1}');
    await store.keepBad('nope');
    expect(File('${file('nope').path}.bad').existsSync(), isFalse);
  });

  test('jsonStoreProvider must be overridden', () {
    final c = ProviderContainer.test();
    expect(() => c.read(jsonStoreProvider), throwsA(anything));
    final o = ProviderContainer.test(
      overrides: [jsonStoreProvider.overrideWithValue(store)],
    );
    expect(o.read(jsonStoreProvider), same(store));
  });
}
