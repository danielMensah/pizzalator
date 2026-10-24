// Shared fakes. Anything that writes through jsonStoreProvider or
// notificationsProvider overrides them with these (CLAUDE.md).
import 'dart:convert';
import 'dart:io';

import 'package:pizzalator/core/timer_run.dart';
import 'package:pizzalator/services/json_store.dart';
import 'package:pizzalator/services/notifications.dart';

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
