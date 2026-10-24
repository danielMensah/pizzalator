import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'services/json_store.dart';
import 'services/notifications.dart';

/// Wiring only. No time zone database: notifications are scheduled as UTC
/// instants (see Notifications.scheduleAt).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notifications = Notifications();
  await notifications.init();
  final container = ProviderContainer(
    overrides: [
      jsonStoreProvider.overrideWithValue(
        JsonStore(await getApplicationDocumentsDirectory()),
      ),
      notificationsProvider.overrideWithValue(notifications),
    ],
  );
  await bootstrap(container);
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PizzalatorApp(),
    ),
  );
}
