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
    WorkoutPrefs,
    WorkoutSchedules,
    WaterLogs,
    BodyMeasurements,
    PersonalRecords,
    FitnessGoals,
    MusicFolders,
    MusicTracks,
    Playlists,
    PlaylistItems,
    MusicState,
    MusicHistory,
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
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Additive only: existing rows keep their data and gain the defaults.
        await m.addColumn(alarms, alarms.oneTime);
        await m.addColumn(alarms, alarms.volume);
        await m.addColumn(alarms, alarms.maxSnoozes);
        await m.addColumn(alarms, alarms.snoozeCount);
        await m.addColumn(workoutSessions, workoutSessions.planId);
        await m.addColumn(workoutSessions, workoutSessions.stepIndex);
        await m.addColumn(workoutSessions, workoutSessions.totalSteps);
      }
      if (from < 3) {
        // Additive only: the ordered dismissal-challenge sequence. Existing
        // alarms keep their data; their legacy single [challengeType] is used
        // as the initial sequence at read time, so no rows are rewritten.
        await m.addColumn(alarms, alarms.challengeSequence);
      }
      if (from < 4) {
        // Additive only: extend the exercise library metadata, remember how a
        // session ended and where it came from, and add the workout-preference
        // and weekly-planner tables. Existing records are never rewritten.
        await m.addColumn(exercises, exercises.exerciseType);
        await m.addColumn(exercises, exercises.formTips);
        await m.addColumn(exercises, exercises.commonMistakes);
        await m.addColumn(exercises, exercises.contraindications);
        await m.addColumn(exercises, exercises.easierAltId);
        await m.addColumn(exercises, exercises.harderAltId);
        await m.addColumn(exercises, exercises.demoAsset);
        await m.addColumn(exercises, exercises.nameKey);
        await m.addColumn(exercises, exercises.instructionsKey);
        await m.addColumn(exercises, exercises.safetyNotesKey);
        await m.addColumn(workoutPlans, workoutPlans.kind);
        await m.addColumn(workoutPlans, workoutPlans.muscleGroups);
        await m.addColumn(workoutPlans, workoutPlans.description);
        await m.addColumn(workoutPlans, workoutPlans.isArchived);
        await m.addColumn(workoutSessions, workoutSessions.scheduledId);
        await m.addColumn(workoutSessions, workoutSessions.outcome);
        await m.addColumn(workoutSetLogs, workoutSetLogs.isSkipped);
        await m.createTable(workoutPrefs);
        await m.createTable(workoutSchedules);
      }
      if (from < 5) {
        // Additive only: richer music metadata, custom-collection fields and a
        // local listening-history table. Existing tracks, favorites, playlists
        // and play counts are preserved; only new columns are added.
        await m.addColumn(musicTracks, musicTracks.mediaId);
        await m.addColumn(musicTracks, musicTracks.albumId);
        await m.addColumn(musicTracks, musicTracks.artistId);
        await m.addColumn(musicTracks, musicTracks.genre);
        await m.addColumn(musicTracks, musicTracks.mimeType);
        await m.addColumn(musicTracks, musicTracks.sizeBytes);
        await m.addColumn(musicTracks, musicTracks.dateModified);
        await m.addColumn(musicTracks, musicTracks.albumArtUri);
        await m.addColumn(musicTracks, musicTracks.trackNumber);
        await m.addColumn(musicTracks, musicTracks.isMissing);
        await m.addColumn(playlists, playlists.accentColor);
        await m.addColumn(playlists, playlists.coverUri);
        await m.addColumn(playlists, playlists.kind);
        await m.addColumn(playlists, playlists.sortOrder);
        await m.addColumn(playlists, playlists.description);
        await m.createTable(musicHistory);
      }
      if (from < 6) {
        // Additive only: alarm sound mode, a per-alarm motivational message and
        // its music/voice timing. Existing alarms keep their data and default
        // to music-only (sound_mode = 2), preserving their current behaviour;
        // no rows are rewritten.
        await m.addColumn(alarms, alarms.soundMode);
        await m.addColumn(alarms, alarms.message);
        await m.addColumn(alarms, alarms.musicIntervalSec);
        await m.addColumn(alarms, alarms.voiceTiming);
        await m.addColumn(alarms, alarms.voicePauseSec);
      }
      if (from < 7) {
        // Additive only: columns that carry the bundled exercise dataset
        // (Exercise Gym GIFs DB) — the dataset's own identifiers, body region,
        // movement category and animated demonstration URL. Existing rows keep
        // their data; legacy seed rows are replaced by the seeder, which runs
        // after the migration.
        await m.addColumn(exercises, exercises.sourceId);
        await m.addColumn(exercises, exercises.slug);
        await m.addColumn(exercises, exercises.bodyPart);
        await m.addColumn(exercises, exercises.secondaryMuscles);
        await m.addColumn(exercises, exercises.sourceCategory);
        await m.addColumn(exercises, exercises.gifUrl);
      }
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
