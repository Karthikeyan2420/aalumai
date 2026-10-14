import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/providers/providers.dart';

enum MealType {
  breakfast,
  lunch,
  dinner,
  snacks;

  static MealType fromIndex(int v) =>
      MealType.values[v.clamp(0, MealType.values.length - 1)];
}

class MealRepository {
  MealRepository(this._db);

  final AppDatabase _db;

  // ---- Recipes ------------------------------------------------------------

  Stream<List<Recipe>> watchRecipes() =>
      (_db.select(_db.recipes)
        ..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();

  Future<int> createRecipe({
    required String name,
    int servings = 1,
    String instructions = '',
    String notes = '',
  }) {
    return _db
        .into(_db.recipes)
        .insert(
          RecipesCompanion.insert(
            name: name,
            servings: Value(servings),
            instructions: Value(instructions),
            notes: Value(notes),
          ),
        );
  }

  Future<void> deleteRecipe(int id) =>
      (_db.delete(_db.recipes)..where((t) => t.id.equals(id))).go();

  Future<int> addIngredient({
    required int recipeId,
    required String name,
    double quantity = 0,
    String unit = '',
  }) {
    return _db
        .into(_db.recipeIngredients)
        .insert(
          RecipeIngredientsCompanion.insert(
            recipeId: recipeId,
            name: name,
            quantity: Value(quantity),
            unit: Value(unit),
          ),
        );
  }

  Stream<List<RecipeIngredient>> watchIngredients(int recipeId) =>
      (_db.select(_db.recipeIngredients)
        ..where((t) => t.recipeId.equals(recipeId))).watch();

  // ---- Meal plan ----------------------------------------------------------

  Stream<List<MealPlanEntry>> watchPlanForWeek(DateTime weekStart) {
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 7));
    return (_db.select(_db.mealPlanEntries)
          ..where((t) => t.day.isBetweenValues(start, end))
          ..orderBy([(t) => OrderingTerm(expression: t.day)]))
        .watch();
  }

  Future<int> addPlanEntry({
    required DateTime day,
    required MealType mealType,
    int? recipeId,
    String customName = '',
    String note = '',
  }) {
    return _db
        .into(_db.mealPlanEntries)
        .insert(
          MealPlanEntriesCompanion.insert(
            day: DateTime(day.year, day.month, day.day),
            mealType: Value(mealType.index),
            recipeId: Value(recipeId),
            customName: Value(customName),
            note: Value(note),
          ),
        );
  }

  Future<void> deletePlanEntry(int id) =>
      (_db.delete(_db.mealPlanEntries)..where((t) => t.id.equals(id))).go();

  // ---- Grocery list -------------------------------------------------------

  Stream<List<GroceryItem>> watchGrocery() =>
      (_db.select(_db.groceryItems)..orderBy([
        (t) => OrderingTerm(expression: t.isChecked),
        (t) => OrderingTerm(expression: t.name),
      ])).watch();

  Future<int> addManualItem({
    required String name,
    double quantity = 0,
    String unit = '',
    String category = '',
  }) {
    return _db
        .into(_db.groceryItems)
        .insert(
          GroceryItemsCompanion.insert(
            name: name,
            quantity: Value(quantity),
            unit: Value(unit),
            category: Value(category),
          ),
        );
  }

  Future<void> toggleChecked(GroceryItem item, bool checked) =>
      (_db.update(_db.groceryItems)..where(
        (t) => t.id.equals(item.id),
      )).write(GroceryItemsCompanion(isChecked: Value(checked)));

  Future<void> deleteItem(int id) =>
      (_db.delete(_db.groceryItems)..where((t) => t.id.equals(id))).go();

  Future<void> clearChecked() =>
      (_db.delete(_db.groceryItems)
        ..where((t) => t.isChecked.equals(true))).go();

  /// Generates grocery items from the planned meals for a week.
  ///
  /// Items are de-duplicated by name+unit (quantities are summed). Manually
  /// added items are never deleted or overwritten.
  Future<int> generateFromPlan(DateTime weekStart) async {
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 7));
    final entries =
        await (_db.select(_db.mealPlanEntries)..where(
          (t) => t.day.isBetweenValues(start, end) & t.recipeId.isNotNull(),
        )).get();
    final recipeIds = entries.map((e) => e.recipeId!).toSet();
    var added = 0;
    for (final recipeId in recipeIds) {
      final ingredients =
          await (_db.select(_db.recipeIngredients)
            ..where((t) => t.recipeId.equals(recipeId))).get();
      for (final ing in ingredients) {
        final existing =
            await (_db.select(_db.groceryItems)..where(
              (t) =>
                  t.isManual.equals(false) &
                  t.name.equals(ing.name) &
                  t.unit.equals(ing.unit),
            )).get();
        if (existing.isEmpty) {
          await _db
              .into(_db.groceryItems)
              .insert(
                GroceryItemsCompanion.insert(
                  name: ing.name,
                  quantity: Value(ing.quantity),
                  unit: Value(ing.unit),
                  isManual: const Value(false),
                  sourceMealId: Value(recipeId),
                ),
              );
          added++;
        } else {
          final item = existing.first;
          await (_db.update(_db.groceryItems)
            ..where((t) => t.id.equals(item.id))).write(
            GroceryItemsCompanion(
              quantity: Value(item.quantity + ing.quantity),
            ),
          );
        }
      }
    }
    return added;
  }
}

final mealRepositoryProvider = Provider<MealRepository>(
  (ref) => MealRepository(ref.watch(appDatabaseProvider)),
);

final recipesProvider = StreamProvider<List<Recipe>>(
  (ref) => ref.watch(mealRepositoryProvider).watchRecipes(),
);

final groceryProvider = StreamProvider<List<GroceryItem>>(
  (ref) => ref.watch(mealRepositoryProvider).watchGrocery(),
);
