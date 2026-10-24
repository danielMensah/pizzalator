import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'screens/splash.dart';
import 'services/json_store.dart';
import 'services/notifications.dart';
import 'services/photos.dart';

/// Wiring only. No time zone database: notifications are scheduled as UTC
/// instants (see Notifications.scheduleAt).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notifications = Notifications();
  await notifications.init();
  final docs = await getApplicationDocumentsDirectory();
  final container = ProviderContainer(
    overrides: [
      jsonStoreProvider.overrideWithValue(JsonStore(docs)),
      photoStoreProvider.overrideWithValue(PhotoStore(docs)),
      notificationsProvider.overrideWithValue(notifications),
    ],
  );
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: Launch(ready: bootstrap(container), child: const PizzalatorApp()),
    ),
  );
}
