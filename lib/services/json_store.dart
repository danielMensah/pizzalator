import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One JSON file per name in [dir]. Missing or corrupt files read as null;
/// a corrupt one is set aside first (see [keepBad]).
class JsonStore {
  JsonStore(this.dir);

  final Directory dir;

  /// Writes run one at a time, in call order, so a slower earlier write can
  /// never land on top of a later one.
  Future<void> _queue = Future.value();

  File _file(String name) => File('${dir.path}/$name.json');

  Future<Object?> read(String name) async {
    final file = _file(name);
    try {
      return jsonDecode(await file.readAsString());
    } on FileSystemException {
      if (!file.existsSync()) return null; // missing
      // unreadable or not UTF-8: corrupt
    } on FormatException {
      // truncated or hand-edited: corrupt
    }
    // Before the next write can land on it, so it can be recovered by hand.
    await keepBad(name);
    return null;
  }

  /// Moves `<name>.json` to `<name>.json.bad`, so a file this build cannot
  /// read is not overwritten and can be recovered by hand.
  Future<void> keepBad(String name) =>
      _queue = _queue.catchError((Object _) {}).then((_) async {
        final file = _file(name);
        if (file.existsSync()) await file.rename('${file.path}.bad');
      });

  /// Atomic: writes `<name>.json.tmp`, then renames over the old file.
  Future<void> write(String name, Object? json) =>
      _queue = _queue.catchError((Object _) {}).then((_) async {
        final file = _file(name);
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(jsonEncode(json), flush: true);
        await tmp.rename(file.path);
      });
}

/// Overridden in main.dart with the app documents dir, and in tests.
final jsonStoreProvider = Provider<JsonStore>(
  (ref) => throw UnimplementedError('Override jsonStoreProvider'),
);
