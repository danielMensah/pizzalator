import 'package:flutter/material.dart';

import 'core/calc.dart';
import 'theme/pizza_theme.dart';

void main() => runApp(const PizzalatorApp());

class PizzalatorApp extends StatelessWidget {
  const PizzalatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pizzalator',
      theme: pizzaTheme(Brightness.light),
      darkTheme: pizzaTheme(Brightness.dark),
      themeMode: ThemeMode.dark,
      home: const CalculatorScreen(),
    );
  }
}

/// Placeholder until mockups/Main.dc.html is built. Proves theme + core wiring.
class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final out = calc(const RecipeInputs(style: PizzaStyle.neapolitan));
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Text('Dough', style: t.h1),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('HYDRATION', style: t.label),
                    Text('${out.hydrationPct}%', style: t.displayMd.copyWith(color: c.emberBright)),
                    const SizedBox(height: 12),
                    for (final l in out.finalDough)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(l.name, style: t.body),
                            Text('${l.grams} g', style: t.number),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
