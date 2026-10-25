import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'screens/splash.dart';
import 'services/json_store.dart';
import 'services/photos.dart';

/// Wiring only. The live timer notification needs no setup: its provider
/// already gives the real platform channel.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final docs = await getApplicationDocumentsDirectory();
  final container = ProviderContainer(
    overrides: [
      jsonStoreProvider.overrideWithValue(JsonStore(docs)),
      photoStoreProvider.overrideWithValue(PhotoStore(docs)),
    ],
  );
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: Launch(ready: bootstrap(container), child: const PizzalatorApp()),
    ),
  );
}
