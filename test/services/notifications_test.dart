import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pizzalator/services/notifications.dart';

const channel = MethodChannel('dexterous.com/flutter/local_notifications');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'initialize' ||
                  call.method == 'requestNotificationsPermission'
              ? true
              : null;
        });
  });

  Map<Object?, Object?> args(int i) => calls[i].arguments as Map;

  test('init uses the launcher icon', () async {
    await Notifications().init();
    expect(calls.single.method, 'initialize');
    expect(args(0)['defaultIcon'], '@mipmap/ic_launcher');
  });

  test('requestPermission asks Android for POST_NOTIFICATIONS', () async {
    await Notifications().requestPermission();
    expect(calls.single.method, 'requestNotificationsPermission');
  });

  test('scheduleAt sends an exact UTC instant on the timer channel', () async {
    final at = DateTime.now().add(const Duration(minutes: 30));
    await Notifications().scheduleAt(3, at, 'Rest over', 'Next: Fold');
    final a = args(0);
    expect(calls.single.method, 'zonedSchedule');
    expect(a['id'], 3);
    expect(a['title'], 'Rest over');
    expect(a['body'], 'Next: Fold');
    expect(a['timeZoneName'], 'Etc/UTC');
    expect(
      DateTime.parse(
        a['scheduledDateTimeISO8601']! as String,
      ).millisecondsSinceEpoch,
      at.millisecondsSinceEpoch,
    );
    final p = a['platformSpecifics']! as Map;
    expect(p['scheduleMode'], 'exactAllowWhileIdle');
    expect(p['channelId'], 'timers');
    expect(p['importance'], Importance.high.value);
  });

  group('exact alarms refused (Android 12 Alarms & reminders off)', () {
    void refuse(String code) => TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          final mode =
              ((call.arguments as Map)['platformSpecifics']
                  as Map?)?['scheduleMode'];
          if (mode == 'exactAllowWhileIdle') {
            throw PlatformException(code: code);
          }
          return null;
        });

    test('falls back to an inexact alarm: late beats never', () async {
      refuse('exact_alarms_not_permitted');
      final at = DateTime.now().add(const Duration(minutes: 30));
      await Notifications().scheduleAt(1, at, 'Rest over', 'Next: Fold');
      expect(calls.map((c) => c.method), ['zonedSchedule', 'zonedSchedule']);
      final p = args(1)['platformSpecifics']! as Map;
      expect(p['scheduleMode'], 'inexactAllowWhileIdle');
      expect(args(1)['id'], 1);
    });

    test('other platform errors still surface', () async {
      refuse('something_else');
      final at = DateTime.now().add(const Duration(minutes: 30));
      await expectLater(
        Notifications().scheduleAt(1, at, 'Rest over', 'Next: Fold'),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  test('scheduleAt skips instants already past', () async {
    await Notifications().scheduleAt(
      0,
      DateTime.now().subtract(const Duration(seconds: 1)),
      'Rest over',
      'Routine done',
    );
    expect(calls, isEmpty);
  });

  test('cancelAll', () async {
    await Notifications().cancelAll();
    expect(calls.single.method, 'cancelAll');
  });

  test('provider gives the real wrapper', () {
    final c = ProviderContainer.test();
    expect(c.read(notificationsProvider), isA<Notifications>());
  });
}
