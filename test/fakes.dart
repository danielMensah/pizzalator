// Shared fakes. Anything that writes through jsonStoreProvider or
// notificationsProvider overrides them with these (CLAUDE.md); the label
// scan overrides labelScannerProvider, bake photos photoStoreProvider;
// clipboard tests install FakeClipboard.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pizzalator/core/timer_run.dart';
import 'package:pizzalator/services/json_store.dart';
import 'package:pizzalator/services/label_scanner.dart';
import 'package:pizzalator/services/notifications.dart';
import 'package:pizzalator/services/photos.dart';

/// In memory, round-tripping through JSON like the real store: real file IO
/// never completes inside fake-async widget tests.
class MemoryStore extends JsonStore {
  MemoryStore() : super(Directory.systemTemp);
  final data = <String, Object?>{};

  /// What [keepBad] set aside, by name.
  final bad = <String, Object?>{};
  var writes = 0;

  /// When set, every write throws it (a full disk, say).
  Object? failWrites;

  @override
  Future<Object?> read(String name) async => data[name];

  @override
  Future<void> write(String name, Object? json) async {
    if (failWrites case final e?) throw e;
    writes++;
    data[name] = jsonDecode(jsonEncode(json));
  }

  @override
  Future<void> keepBad(String name) async => bad[name] = data.remove(name);
}

class FakeNotifications implements Notifications {
  final pending = <int, RunAlarm>{};
  var asks = 0;
  var cancels = 0;

  /// Ids whose scheduleAt throws, like a refused exact alarm.
  final failIds = <int>{};

  @override
  Future<void> init() async {}

  @override
  Future<void> requestPermission() async => asks++;

  /// Yields first, as a platform call does: the reschedule queue must keep
  /// one reschedule from landing inside another.
  @override
  Future<void> scheduleAt(
    int id,
    DateTime at,
    String title,
    String body,
  ) async {
    await Future<void>.value();
    if (failIds.contains(id)) throw StateError('alarm $id refused');
    pending[id] = RunAlarm(at, title, body);
  }

  @override
  Future<void> cancelAll() async {
    await Future<void>.value();
    cancels++;
    pending.clear();
  }
}

/// Hands back [next] (null: the user backed out), or throws [error].
class FakeScanner implements LabelScanner {
  LabelScan? next;
  Object? error;
  final sources = <ImageSource>[];

  /// When set, scan() waits on it: the camera is open or OCR is running.
  Completer<void>? gate;

  @override
  Future<LabelScan?> scan(ImageSource source) async {
    sources.add(source);
    await gate?.future;
    if (error case final e?) throw e;
    return next;
  }
}

/// The system clipboard in memory: what copy wrote, what paste reads (null
/// reads as empty).
class FakeClipboard {
  String? text;

  /// Takes over the platform channel for [tester]'s test, and gives it back.
  void install(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          text = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        case 'Clipboard.getData':
          return text == null ? null : {'text': text};
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }
}

/// Photos without files: pick hands back [next] (null: the user backed
/// out) or throws [error]; delete only records the name.
class FakePhotoStore extends PhotoStore {
  FakePhotoStore() : super(Directory.systemTemp);
  String? next = 'p1.jpg';
  Object? error;
  final sources = <ImageSource>[];
  final deleted = <String>[];

  @override
  Future<String?> pick(ImageSource source) async {
    sources.add(source);
    if (error case final e?) throw e;
    return next;
  }

  @override
  Future<void> delete(String name) async => deleted.add(name);
}
