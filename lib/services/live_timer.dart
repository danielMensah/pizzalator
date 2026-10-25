import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/live_timer.dart';

const _channel = MethodChannel('pizzalator/live_timer');

/// The native live notification (android/.../LiveTimer.kt) that runs the
/// timers while the app is hidden, and the end chime.
class LiveTimer {
  const LiveTimer();

  /// Android 13+ runtime prompt; a no-op on older versions.
  Future<void> requestPermission() =>
      _channel.invokeMethod('requestPermission');

  /// Posts the first frame and steps through [legs] from [startedAt],
  /// paused from [pausedAt] if set. Replaces whatever was shown.
  Future<void> show(
    List<List<LiveFrame>> legs,
    DateTime startedAt, {
    DateTime? pausedAt,
  }) => _channel.invokeMethod('show', {
    'legs': jsonEncode(legs),
    'startedAt': startedAt.millisecondsSinceEpoch,
    'pausedAt': pausedAt?.millisecondsSinceEpoch,
  });

  /// Cancels the notification and its alarm; hands back the taps made on it
  /// since [show], and forgets them.
  Future<List<LiveAction>> stop() async => [
    for (final a
        in jsonDecode(await _channel.invokeMethod<String>('stop') ?? '[]')
            as List<Object?>)
      LiveAction.fromJson(a! as Map<String, Object?>),
  ];

  /// The ding, now, on the alarm stream: it sounds on silent too.
  Future<void> chime() => _channel.invokeMethod('chime');
}

/// Faked in tests.
final liveTimerProvider = Provider<LiveTimer>((ref) => const LiveTimer());
