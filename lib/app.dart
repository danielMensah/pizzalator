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
/// run back, with the taps made on its notification (FR10); from then on the
/// working copy is saved on every change (PRD §5). Never throws: an unreadable
/// file or a full disk must not keep the app on its launch screen.
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

/// Out of sight, the live notification runs the timers; on screen, a 1 s
/// tick chimes their ends on any screen.
class PizzalatorApp extends ConsumerStatefulWidget {
  const PizzalatorApp({super.key});

  @override
  ConsumerState<PizzalatorApp> createState() => _PizzalatorAppState();
}

class _PizzalatorAppState extends ConsumerState<PizzalatorApp> {
  late final AppLifecycleListener _life;
  Timer? _ticker;
  var _shown = true;

  TimerRunNotifier get _run => ref.read(timerRunProvider.notifier);

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(
      onHide: () => _show(false, _run.background),
      onShow: () => _show(true, _run.foreground),
    );
    ref.listenManual(
      timerRunProvider,
      (_, _) => _syncTicker(),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _life.dispose();
    super.dispose();
  }

  void _show(bool shown, Future<void> Function() handOver) {
    _shown = shown;
    _syncTicker();
    unawaited(handOver());
  }

  /// Ticks only while shown and a run exists.
  void _syncTicker() {
    final on = _shown && ref.read(timerRunProvider) != null;
    if (on == (_ticker != null)) return;
    _ticker?.cancel();
    _ticker = on
        ? Timer.periodic(
            const Duration(seconds: 1),
            (_) => unawaited(_run.tick()),
          )
        : null;
  }

  @override
  Widget build(BuildContext context) {
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
