import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pizzalator/core/live_timer.dart';
import 'package:pizzalator/services/live_timer.dart';

const channel = MethodChannel('pizzalator/live_timer');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  Object? reply;

  setUp(() {
    calls.clear();
    reply = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return reply;
        });
  });

  Map<Object?, Object?> args() => calls.single.arguments as Map;
  final t0 = DateTime(2026, 10, 24, 9);

  test('requestPermission', () async {
    await const LiveTimer().requestPermission();
    expect(calls.single.method, 'requestPermission');
  });

  test('show sends the legs as JSON and the start in epoch ms', () async {
    const legs = [
      [
        LiveFrame(
          at: Duration.zero,
          end: Duration(minutes: 30),
          title: 'A',
          text: 'Next: B',
        ),
        LiveFrame(
          at: Duration(minutes: 30),
          title: 'Rest over',
          text: 'Next: B',
          chime: true,
          go: LiveGo.next,
        ),
      ],
    ];
    await const LiveTimer().show(legs, t0);
    expect(calls.single.method, 'show');
    expect(args()['startedAt'], t0.millisecondsSinceEpoch);
    expect(args()['pausedAt'], isNull);
    final sent = jsonDecode(args()['legs']! as String) as List<Object?>;
    expect(sent, [
      [legs[0][0].toJson(), legs[0][1].toJson()],
    ]);
  });

  test('show while paused', () async {
    await const LiveTimer().show(const [], t0, pausedAt: t0);
    expect(args()['pausedAt'], t0.millisecondsSinceEpoch);
  });

  test('stop hands back the taps made on the notification', () async {
    reply = jsonEncode([
      {'type': 'pause', 'at': t0.millisecondsSinceEpoch},
      {'type': 'next', 'at': t0.millisecondsSinceEpoch + 1000},
    ]);
    final log = await const LiveTimer().stop();
    expect(calls.single.method, 'stop');
    expect(
      [for (final a in log) (a.type, a.at)],
      [(LiveTap.pause, t0), (LiveTap.next, t0.add(const Duration(seconds: 1)))],
    );
  });

  test('stop with nothing shown', () async {
    expect(await const LiveTimer().stop(), isEmpty);
  });

  test('chime', () async {
    await const LiveTimer().chime();
    expect(calls.single.method, 'chime');
  });

  test('provider gives the real channel', () {
    final c = ProviderContainer.test();
    expect(c.read(liveTimerProvider), isA<LiveTimer>());
  });
}
