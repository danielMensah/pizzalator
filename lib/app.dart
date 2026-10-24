import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routes.dart';
import 'screens/bake_log.dart';
import 'screens/calculator.dart';
import 'screens/ferment.dart';
import 'screens/flours.dart';
import 'screens/log_entry.dart';
import 'screens/recipe.dart';
import 'screens/recipes.dart';
import 'screens/routine.dart';
import 'screens/timers.dart';
import 'state/bake_log.dart';
import 'state/calibration.dart';
import 'state/flours.dart';
import 'state/oven.dart';
import 'state/recipe.dart';
import 'state/recipes.dart';
import 'state/routine.dart';
import 'state/timer_run.dart';
import 'theme/fonts.dart';
import 'theme/pizza_theme.dart';

/// Launch, before the first frame: bundled fonts only, saved routine,
/// flours, recipes, bake log, hint dismissals, the last working copy and timer
/// run back, alarms rescheduled (FR10); from then on the working copy is saved
/// on every change (PRD §5). Never throws: an unreadable file, a full disk or a
/// refused alarm must not keep the app on its launch screen.
Future<void> bootstrap(ProviderContainer c) async {
  configureFonts();
  final recipes = c.read(savedRecipesProvider.notifier);
  await Future.wait([
    for (final step in [
      c.read(routineProvider.notifier).load,
      c.read(customFloursProvider.notifier).load,
      recipes.load,
      recipes.restoreCurrent,
      c.read(bakeLogProvider.notifier).load,
      c.read(hintDismissalsProvider.notifier).load,
      c.read(timerRunProvider.notifier).restore,
    ])
      step().catchError((Object e) => debugPrint('launch: $e')),
  ]);
  void save(Object? _, Object? _) => unawaited(
    recipes.saveCurrent().catchError((Object e) => debugPrint('save: $e')),
  );
  c
    ..listen<Object?>(recipeProvider, save)
    ..listen<Object?>(ovenProvider, save)
    ..listen<Object?>(activeRecipeIdProvider, save);
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
        Routes.flours: (_) => const FloursScreen(),
        Routes.recipes: (_) => const RecipesScreen(),
        Routes.bakeLog: (_) => const BakeLogScreen(),
        Routes.logEntry: (context) => LogEntryScreen(
          id: ModalRoute.of(context)!.settings.arguments as String?,
        ),
      },
    );
  }
}
