import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Habits,
    HabitCompletions,
    Tags,
    Tasks,
    Events,
    EventExceptions,
    Notes,
    Accounts,
    Categories,
    RecurringRules,
    Transactions,
    Budgets,
    Debts,
    DebtPayments,
    SavingsGoals,
    SavingsContributions,
    Exercises,
    WorkoutSessions,
    WorkoutSetLogs,
    WorkoutPlans,
    WorkoutPlanItems,
    WaterLogs,
    BodyMeasurements,
    PersonalRecords,
    FitnessGoals,
    MusicFolders,
    MusicTracks,
    Playlists,
    PlaylistItems,
    MusicState,
    Alarms,
    Recipes,
    RecipeIngredients,
    MealPlanEntries,
    GroceryItems,
    LearningCourses,
    Lessons,
    Vocabulary,
    LearningExercises,
    LearningAttempts,
    VocabReviews,
    PronunciationAttempts,
    LearningProgress,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'aalumai.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
