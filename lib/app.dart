import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routes.dart';
import 'screens/calculator.dart';
import 'screens/ferment.dart';
import 'screens/recipe.dart';
import 'screens/routine.dart';
import 'screens/timers.dart';
import 'state/routine.dart';
import 'state/timer_run.dart';
import 'theme/fonts.dart';
import 'theme/pizza_theme.dart';

/// Launch, before the first frame: bundled fonts only, saved routine and
/// timer run back, alarms rescheduled (FR10). Never throws: an unreadable
/// file, a full disk or a refused alarm must not keep the app on its launch
/// screen.
Future<void> bootstrap(ProviderContainer c) {
  configureFonts();
  return Future.wait([
    for (final step in [
      c.read(routineProvider.notifier).load,
      c.read(timerRunProvider.notifier).restore,
    ])
      step().catchError((Object e) => debugPrint('launch: $e')),
  ]);
}

class PizzalatorApp extends ConsumerWidget {
  const PizzalatorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Pizzalator',
      theme: pizzaTheme(Brightness.light),
      darkTheme: pizzaTheme(Brightness.dark),
      themeMode: ThemeMode.dark,
      // A run that survived a kill opens where it is; '/timers' also stacks
      // the calculator underneath, so Back lands there.
      initialRoute: ref.read(timerRunProvider) != null
          ? Routes.timers
          : Routes.calculator,
      routes: {
        Routes.calculator: (_) => const CalculatorScreen(),
        Routes.ferment: (_) => const FermentScreen(),
        Routes.recipe: (_) => const RecipeScreen(),
        Routes.timers: (_) => const TimersScreen(),
        Routes.routine: (_) => const RoutineScreen(),
      },
    );
  }
}
