import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

const _details = NotificationDetails(
  android: AndroidNotificationDetails(
    'timers',
    'Dough timers',
    channelDescription: 'Rest and step timer ends',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
  ),
);

/// Thin wrapper over flutter_local_notifications: the timers only need
/// init, permission, schedule-at-instant and cancel-all.
class Notifications {
  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() => _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  /// Android 13+ runtime prompt; a no-op on older versions.
  Future<void> requestPermission() async => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.requestNotificationsPermission();

  /// Absolute instant, so UTC needs no time zone database. Exact: an inexact
  /// alarm can land many minutes late, and a dough timer is what exact alarms
  /// are for (USE_EXACT_ALARM in the manifest, no prompt). On Android 12 the
  /// user can still revoke SCHEDULE_EXACT_ALARM; then a late alarm beats none.
  Future<void> scheduleAt(
    int id,
    DateTime at,
    String title,
    String body,
  ) async {
    if (!at.isAfter(DateTime.now())) return; // the plugin throws on the past
    Future<void> schedule(AndroidScheduleMode mode) => _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(at, tz.UTC),
      notificationDetails: _details,
      androidScheduleMode: mode,
      title: title,
      body: body,
    );
    try {
      await schedule(AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException catch (e) {
      if (e.code != 'exact_alarms_not_permitted') rethrow;
      await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  /// Pending and shown.
  Future<void> cancelAll() => _plugin.cancelAll();
}

/// Overridden in main.dart with the initialised instance, and with fakes in
/// tests.
final notificationsProvider = Provider<Notifications>((ref) => Notifications());
