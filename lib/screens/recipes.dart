import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calc.dart';
import '../core/export_text.dart';
import '../core/recipe_json.dart';
import '../routes.dart';
import '../state/recipes.dart';
import '../state/units.dart';
import '../theme/pizza_theme.dart';
import '../widgets/widgets.dart';

/// Asks a name, then saves the working copy as a new recipe (Recipe screen
/// and Recipes share it).
Future<void> saveAsNew(BuildContext context, WidgetRef ref) async {
  final v = await askText(context, 'Name this recipe', 'Save recipe', [
    ('Name', '', 'e.g. Friday NY'),
  ]);
  if (v == null || !context.mounted) return;
  await ref.read(savedRecipesProvider.notifier).saveAs(v.single);
}

String _count(int n) => '$n ${n == 1 ? 'recipe' : 'recipes'}';

/// Saved recipes (PRD §5, FR9). No mockup: BakeLog / Flours style.
// ponytail: export and import go through the clipboard; a file share or
// picker dependency when files are wanted.
class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(savedRecipesProvider);
    final activeId = ref.watch(activeRecipeProvider)?.id;
    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            backLabel: 'Calculator',
            title: 'Recipes',
            trailing: SectionLabel('${recipes.length} saved'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                SizedBox(
                  height: 48,
                  child: Row(
                    spacing: 10,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'Export',
                          icon: Icons.upload_outlined,
                          onPressed: recipes.isEmpty
                              ? null
                              : () => unawaited(_export(context, ref)),
                        ),
                      ),
                      Expanded(
                        child: SecondaryButton(
                          label: 'Import',
                          icon: Icons.download_outlined,
                          onPressed: () => unawaited(_import(context, ref)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (recipes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Column(
                      spacing: 10,
                      children: [
                        const PizzaMark(size: 56),
                        Text(
                          'No saved recipes yet. Save the one on the '
                          'calculator to come back to it.',
                          textAlign: TextAlign.center,
                          style: context.text.captionRegular,
                        ),
                      ],
                    ),
                  ),
                for (final (i, r) in recipes.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _RecipeCard(
                      index: i,
                      recipe: r,
                      open: r.id == activeId,
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PrimaryButton(
                label: 'Save current as new',
                icon: Icons.bookmark_add_outlined,
                onPressed: () => unawaited(saveAsNew(context, ref)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final n = ref.read(savedRecipesProvider).length;
    final json = ref.read(savedRecipesProvider.notifier).exportJson();
    await Clipboard.setData(ClipboardData(text: json));
    if (context.mounted) showPizzaToast(context, '${_count(n)} copied as JSON');
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final recipes = ref.read(savedRecipesProvider.notifier);
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    var n = 0;
    try {
      if (text != null) n = await recipes.importJson(text);
    } on FormatException {
      // Not an export: says so below.
    }
    if (!context.mounted) return;
    showPizzaToast(
      context,
      n == 0
          ? 'No Pizzalator recipes on the clipboard'
          : 'Imported ${_count(n)}',
    );
  }
}

enum _Action { duplicate, rename, delete }

/// Name with an "open" pill on the active one, summary line, hydration; tap
/// opens it, the 44 px button offers duplicate, rename and delete.
class _RecipeCard extends ConsumerWidget {
  const _RecipeCard({
    required this.index,
    required this.recipe,
    required this.open,
  });

  final int index;
  final SavedRecipe recipe;
  final bool open;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final out = calc(recipe.inputs);
    return PizzaCard(
      delay: Duration(milliseconds: 60 * index.clamp(0, 5)),
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _open(context, ref),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Row(
                    spacing: 12,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            Row(
                              spacing: 8,
                              children: [
                                Flexible(
                                  child: Text(
                                    recipe.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.bodyStrong,
                                  ),
                                ),
                                if (open)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: c.sageTint,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'open',
                                      style: t.label.copyWith(
                                        letterSpacing: 0,
                                        color: c.sageBright,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              summaryText(
                                recipe.inputs,
                                out,
                                recipe.oven,
                                unit: ref.watch(lengthUnitProvider),
                              ),
                              style: t.captionRegular,
                            ),
                          ],
                        ),
                      ),
                      Text('${pctText(out.hydrationPct)}%', style: t.number),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Options for ${recipe.name}',
            color: c.inkMuted,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: () => unawaited(_more(context, ref)),
            icon: const Icon(Icons.more_vert, size: 20),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, WidgetRef ref) {
    unawaited(ref.read(savedRecipesProvider.notifier).open(recipe));
    showPizzaToast(context, 'Loaded "${recipe.name}"');
    Navigator.popUntil(context, ModalRoute.withName(Routes.calculator));
  }

  Future<void> _more(BuildContext context, WidgetRef ref) async {
    final n = ref.read(savedRecipesProvider.notifier);
    final action = await showPizzaSheet<_Action>(
      context,
      (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            Text(recipe.name, style: sheet.text.h2),
            SecondaryButton(
              label: 'Duplicate',
              icon: Icons.copy_all_outlined,
              onPressed: () => Navigator.pop(sheet, _Action.duplicate),
            ),
            SecondaryButton(
              label: 'Rename',
              icon: Icons.edit_outlined,
              onPressed: () => Navigator.pop(sheet, _Action.rename),
            ),
            SecondaryButton(
              label: 'Delete',
              icon: Icons.delete_outline,
              alert: true,
              onPressed: () => Navigator.pop(sheet, _Action.delete),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _Action.duplicate:
        await n.duplicate(index);
      case _Action.rename:
        final v = await askText(context, 'Rename recipe', 'Save name', [
          ('Name', recipe.name, null),
        ]);
        if (v != null) await n.rename(index, v.single);
      case _Action.delete:
        await n.delete(index);
    }
  }
}
