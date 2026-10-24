// Fails when line coverage in coverage/lcov.info is under the threshold, or
// when a lib/ file is missing from it (no test loads it: 0 %, not skipped).
// Usage: dart run tool/check_coverage.dart [min_pct] [lcov_path]
import 'dart:io';

/// Files that cannot be unit tested: entry points only. main.dart is wiring;
/// the launch sequence it runs is bootstrap() in app.dart, which is tested.
const excluded = ['lib/main.dart'];

/// Files with no executable lines, which lcov never lists.
const codeless = ['lib/routes.dart', 'lib/widgets/widgets.dart'];

void main(List<String> args) {
  final min = args.isEmpty ? 98.0 : double.parse(args.first);
  final path = args.length > 1 ? args[1] : 'coverage/lcov.info';
  final lines = File(path).readAsLinesSync();
  var found = 0;
  var hit = 0;
  var skip = false;
  final low = <String>[];
  final seen = <String>{};
  String file = '';
  var fileFound = 0;
  var fileHit = 0;
  for (final l in lines) {
    if (l.startsWith('SF:')) {
      file = l.substring(3);
      seen.add(file);
      skip = excluded.any(file.endsWith);
      fileFound = fileHit = 0;
    } else if (!skip && l.startsWith('LF:')) {
      fileFound = int.parse(l.substring(3));
    } else if (!skip && l.startsWith('LH:')) {
      fileHit = int.parse(l.substring(3));
    } else if (l == 'end_of_record' && !skip) {
      found += fileFound;
      hit += fileHit;
      if (fileFound > 0 && fileHit < fileFound) {
        low.add('$file $fileHit/$fileFound');
      }
    }
  }
  final missing = [
    for (final f in Directory('lib').listSync(recursive: true))
      if (f is File && f.path.endsWith('.dart'))
        if (![...excluded, ...codeless].contains(f.path) &&
            !seen.any((s) => s.endsWith(f.path)))
          f.path,
  ]..sort();
  final pct = found == 0 ? 0.0 : hit * 100 / found;
  stdout.writeln('coverage ${pct.toStringAsFixed(2)}% ($hit/$found lines)');
  for (final f in low) {
    stdout.writeln('  partial: $f');
  }
  for (final f in missing) {
    stderr.writeln('  not loaded by any test: $f');
  }
  if (pct < min || missing.isNotEmpty) {
    stderr.writeln(pct < min ? 'FAIL: below $min%' : 'FAIL: untested files');
    exit(1);
  }
}
