import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/widgets/common.dart';
import 'data/meal_repository.dart';

class MealsScreen extends ConsumerStatefulWidget {
  const MealsScreen({super.key});

  @override
  ConsumerState<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends ConsumerState<MealsScreen> {
  DateTime _weekStart = _startOfWeek(DateTime.now());

  static DateTime _startOfWeek(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.meals),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.mealPlan),
              Tab(text: l10n.recipes),
              Tab(text: l10n.groceryList),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PlanTab(
              weekStart: _weekStart,
              onShift: (days) {
                setState(
                  () => _weekStart = _weekStart.add(Duration(days: days)),
                );
              },
            ),
            const _RecipesTab(),
            _GroceryTab(weekStart: _weekStart),
          ],
        ),
      ),
    );
  }
}

class _PlanTab extends ConsumerWidget {
  const _PlanTab({required this.weekStart, required this.onShift});
  final DateTime weekStart;
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final plan = ref.watch(_weekPlanProvider(weekStart));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => onShift(-7),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${DateFormat.MMMd(locale).format(weekStart)} – '
                    '${DateFormat.MMMd(locale).format(weekStart.add(const Duration(days: 6)))}',
                  ),
                ),
              ),
              IconButton(
                onPressed: () => onShift(7),
                icon: const Icon(Icons.chevron_right),
              ),
              IconButton(
                tooltip: l10n.add,
                onPressed: () => showPlanEntryEditor(context, ref, weekStart),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Expanded(
          child: plan.when(
            loading: () => const LoadingState(),
            error: (e, _) => ErrorState(message: e.toString()),
            data: (entries) {
              if (entries.isEmpty) {
                return EmptyState(
                  icon: Icons.restaurant_menu,
                  message: l10n.emptyMeals,
                  actionLabel: l10n.add,
                  onAction: () => showPlanEntryEditor(context, ref, weekStart),
                );
              }
              final byDay = <String, List<MealPlanEntry>>{};
              for (final e in entries) {
                final key = DateFormat.yMMMd(locale).format(e.day);
                byDay.putIfAbsent(key, () => []).add(e);
              }
              return ListView(
                children: [
                  for (final entry in byDay.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        entry.key,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    for (final meal in entry.value)
                      ListTile(
                        dense: true,
                        leading: Icon(_mealIcon(meal.mealType)),
                        title: Text(
                          meal.customName.isEmpty
                              ? MealType.fromIndex(meal.mealType).name
                              : meal.customName,
                        ),
                        subtitle: Text(meal.note),
                        onLongPress: () async {
                          final ok = await confirmDialog(
                            context,
                            title: l10n.deleteConfirmTitle,
                            body: l10n.deleteConfirmBody,
                            confirmLabel: l10n.delete,
                          );
                          if (ok) {
                            await ref
                                .read(mealRepositoryProvider)
                                .deletePlanEntry(meal.id);
                          }
                        },
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _mealIcon(int type) => switch (type) {
    0 => Icons.free_breakfast,
    1 => Icons.lunch_dining,
    2 => Icons.dinner_dining,
    _ => Icons.cookie_outlined,
  };
}

final _weekPlanProvider = StreamProvider.family<List<MealPlanEntry>, DateTime>((
  ref,
  weekStart,
) {
  return ref.watch(mealRepositoryProvider).watchPlanForWeek(weekStart);
});

class _RecipesTab extends ConsumerWidget {
  const _RecipesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final recipes = ref.watch(recipesProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'mealsAddRecipe',
        onPressed: () => showRecipeEditor(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.add),
      ),
      body: recipes.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data:
            (list) =>
                list.isEmpty
                    ? EmptyState(
                      icon: Icons.menu_book_outlined,
                      message: l10n.emptyMeals,
                      actionLabel: l10n.add,
                      onAction: () => showRecipeEditor(context, ref),
                    )
                    : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final r = list[i];
                        return ListTile(
                          leading: const Icon(Icons.receipt_long_outlined),
                          title: Text(r.name),
                          subtitle: Text(
                            '${l10n.ingredients}: '
                            '${r.servings} ${l10n.quantity}',
                          ),
                          onTap:
                              () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => RecipeDetailScreen(recipe: r),
                                ),
                              ),
                        );
                      },
                    ),
      ),
    );
  }
}

class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen({super.key, required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ingredients = ref.watch(_ingredientsProvider(recipe.id));
    return Scaffold(
      appBar: AppBar(title: Text(recipe.name)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'mealsAddIngredient',
        onPressed: () => showIngredientEditor(context, ref, recipe.id),
        icon: const Icon(Icons.add),
        label: Text(l10n.ingredients),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (recipe.instructions.isNotEmpty) ...[
            Text(
              l10n.instructions,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(recipe.instructions),
            const SizedBox(height: 16),
          ],
          Text(
            l10n.ingredients,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ingredients.when(
            loading: () => const LoadingState(),
            error: (e, _) => ErrorState(message: e.toString()),
            data:
                (list) =>
                    list.isEmpty
                        ? Text(l10n.emptyMeals)
                        : Column(
                          children: [
                            for (final ing in list)
                              ListTile(
                                title: Text(ing.name),
                                trailing: Text('${ing.quantity} ${ing.unit}'),
                              ),
                          ],
                        ),
          ),
        ],
      ),
    );
  }
}

final _ingredientsProvider = StreamProvider.family<List<RecipeIngredient>, int>(
  (ref, recipeId) {
    return ref.watch(mealRepositoryProvider).watchIngredients(recipeId);
  },
);

class _GroceryTab extends ConsumerWidget {
  const _GroceryTab({required this.weekStart});
  final DateTime weekStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final grocery = ref.watch(groceryProvider);
    return Scaffold(
      body: grocery.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.shopping_cart_outlined,
              message: l10n.groceryList,
              actionLabel: l10n.add,
              onAction: () => showGroceryItemEditor(context, ref),
            );
          }
          return ListView(
            children: [
              for (final item in list)
                CheckboxListTile(
                  value: item.isChecked,
                  title: Text(item.name),
                  subtitle:
                      item.quantity > 0
                          ? Text('${item.quantity} ${item.unit}')
                          : null,
                  onChanged:
                      (v) => ref
                          .read(mealRepositoryProvider)
                          .toggleChecked(item, v ?? false),
                  secondary: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed:
                        () => ref
                            .read(mealRepositoryProvider)
                            .deleteItem(item.id),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'groceryAdd',
            onPressed: () => showGroceryItemEditor(context, ref),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'groceryGenerate',
            tooltip: l10n.generateList,
            onPressed: () async {
              final added = await ref
                  .read(mealRepositoryProvider)
                  .generateFromPlan(weekStart);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$added ${l10n.itemsCount}')),
                );
              }
            },
            child: const Icon(Icons.auto_awesome),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'groceryClear',
            tooltip: l10n.clear,
            onPressed: () => ref.read(mealRepositoryProvider).clearChecked(),
            child: const Icon(Icons.cleaning_services_outlined),
          ),
        ],
      ),
    );
  }
}

// ---- Editors ---------------------------------------------------------------

Future<void> showPlanEntryEditor(
  BuildContext context,
  WidgetRef ref,
  DateTime weekStart,
) async {
  final l10n = context.l10n;
  final recipes = ref.read(recipesProvider).valueOrNull ?? const <Recipe>[];
  final customCtrl = TextEditingController();
  var day = DateTime(weekStart.year, weekStart.month, weekStart.day);
  var mealType = MealType.breakfast;
  var recipeId = -1;
  final saved = await showDialog<bool>(
    context: context,
    builder:
        (context) => StatefulBuilder(
          builder:
              (context, setState) => AlertDialog(
                title: Text(l10n.mealPlan),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        value: day.weekday,
                        decoration: InputDecoration(labelText: l10n.date),
                        items: [
                          for (var i = 0; i < 7; i++)
                            DropdownMenuItem(
                              value: i + 1,
                              child: Text(
                                DateFormat.EEEE().format(
                                  weekStart.add(Duration(days: i)),
                                ),
                              ),
                            ),
                        ],
                        onChanged:
                            (v) => setState(
                              () =>
                                  day = weekStart.add(
                                    Duration(days: (v ?? 1) - 1),
                                  ),
                            ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<MealType>(
                        value: mealType,
                        decoration: InputDecoration(labelText: l10n.meals),
                        items: [
                          for (final t in MealType.values)
                            DropdownMenuItem(value: t, child: Text(t.name)),
                        ],
                        onChanged:
                            (v) => setState(() => mealType = v ?? mealType),
                      ),
                      const SizedBox(height: 12),
                      if (recipes.isNotEmpty)
                        DropdownButtonFormField<int>(
                          value: recipeId,
                          decoration: InputDecoration(labelText: l10n.recipes),
                          items: [
                            DropdownMenuItem(value: -1, child: Text(l10n.none)),
                            for (final r in recipes)
                              DropdownMenuItem(
                                value: r.id,
                                child: Text(r.name),
                              ),
                          ],
                          onChanged: (v) => setState(() => recipeId = v ?? -1),
                        ),
                      if (recipeId == -1) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: customCtrl,
                          decoration: InputDecoration(labelText: l10n.name),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l10n.save),
                  ),
                ],
              ),
        ),
  );
  if (saved == true) {
    await ref
        .read(mealRepositoryProvider)
        .addPlanEntry(
          day: day,
          mealType: mealType,
          recipeId: recipeId == -1 ? null : recipeId,
          customName: recipeId == -1 ? customCtrl.text.trim() : '',
        );
  }
}

Future<void> showRecipeEditor(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final nameCtrl = TextEditingController();
  final servingsCtrl = TextEditingController(text: '1');
  final instructionsCtrl = TextEditingController();
  final saved = await showDialog<bool>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: Text(l10n.recipes),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(labelText: l10n.name),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: servingsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.quantity),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: instructionsCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: l10n.instructions),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.save),
            ),
          ],
        ),
  );
  if (saved == true && nameCtrl.text.trim().isNotEmpty) {
    await ref
        .read(mealRepositoryProvider)
        .createRecipe(
          name: nameCtrl.text.trim(),
          servings: int.tryParse(servingsCtrl.text.trim()) ?? 1,
          instructions: instructionsCtrl.text.trim(),
        );
  }
}

Future<void> showIngredientEditor(
  BuildContext context,
  WidgetRef ref,
  int recipeId,
) async {
  final l10n = context.l10n;
  final nameCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  final unitCtrl = TextEditingController();
  final saved = await showDialog<bool>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: Text(l10n.ingredients),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.name),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: l10n.quantity),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: unitCtrl,
                decoration: InputDecoration(labelText: l10n.unit),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.save),
            ),
          ],
        ),
  );
  if (saved == true && nameCtrl.text.trim().isNotEmpty) {
    await ref
        .read(mealRepositoryProvider)
        .addIngredient(
          recipeId: recipeId,
          name: nameCtrl.text.trim(),
          quantity: double.tryParse(qtyCtrl.text.trim()) ?? 0,
          unit: unitCtrl.text.trim(),
        );
  }
}

Future<void> showGroceryItemEditor(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final nameCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  final saved = await showDialog<bool>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: Text(l10n.groceryList),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.name),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: l10n.quantity),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.save),
            ),
          ],
        ),
  );
  if (saved == true && nameCtrl.text.trim().isNotEmpty) {
    await ref
        .read(mealRepositoryProvider)
        .addManualItem(
          name: nameCtrl.text.trim(),
          quantity: double.tryParse(qtyCtrl.text.trim()) ?? 0,
        );
  }
}
