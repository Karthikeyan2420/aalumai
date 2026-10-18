import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/features/fitness/data/fitness_repository.dart';
import 'package:aalumai/features/fitness/domain/exercise_collections.dart';
import 'package:aalumai/features/fitness/domain/exercise_format.dart';
import 'package:aalumai/features/fitness/domain/weekly_planner.dart';
import 'package:aalumai/features/fitness/domain/workout_preferences.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The seeded library is read from a bundled asset, so the binding must exist.
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FitnessRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FitnessRepository(db);
  });

  tearDown(() => db.close());

  group('exercise seed metadata', () {
    test('seeds the whole bundled library', () async {
      await repo.seedExercises();
      final all = await db.select(db.exercises).get();
      expect(all.length, greaterThanOrEqualTo(1000));
      expect(all.every((e) => e.name.isNotEmpty), isTrue);
      expect(all.every((e) => e.sourceId.isNotEmpty), isTrue);
    });

    test('seeding twice never duplicates rows', () async {
      await repo.seedExercises();
      final first = await db.select(db.exercises).get();
      await repo.seedExercises();
      final second = await db.select(db.exercises).get();
      expect(second.length, first.length);
    });

    test('persists the dataset metadata the UI reads', () async {
      await repo.seedExercises();
      final all = await db.select(db.exercises).get();
      expect(
        all.every((e) => e.exerciseType >= 0 && e.exerciseType <= 3),
        isTrue,
      );
      expect(all.every((e) => e.category >= 0 && e.category <= 8), isTrue);
      expect(all.every((e) => e.slug.isNotEmpty), isTrue);
      expect(all.every((e) => e.instructions.isNotEmpty), isTrue);
      // The dataset publishes no difficulty, so the app must not claim one.
      expect(all.every((e) => !hasKnownDifficulty(e.difficulty)), isTrue);
      // Every record ships an animated demonstration on the dataset CDN.
      expect(all.every((e) => e.gifUrl.isNotEmpty), isTrue);
    });

    test('files every exercise into exactly one workout collection', () async {
      await repo.seedExercises();
      final all = await db.select(db.exercises).get();
      final counts = <WorkoutCollection, int>{};
      for (final e in all) {
        final collection = exerciseCollection(e);
        expect(collection, isNotNull, reason: e.name);
        counts.update(collection!, (v) => v + 1, ifAbsent: () => 1);
      }
      // Dumbbell work is its own, non-empty category, never mixed into a
      // generic list.
      for (final collection in WorkoutCollection.values) {
        expect(counts[collection], greaterThan(0), reason: collection.name);
      }
    });

    test('replaces the legacy library instead of mixing it in', () async {
      await db
          .into(db.exercises)
          .insert(ExercisesCompanion.insert(name: 'Legacy move'));
      await repo.seedExercises();
      final all = await db.select(db.exercises).get();
      expect(all.any((e) => e.name == 'Legacy move'), isFalse);
      expect(all.every((e) => e.sourceId.isNotEmpty), isTrue);
    });
  });

  group('workout preferences', () {
    test('preferencesRow creates a default row once', () async {
      final row = await repo.preferencesRow();
      expect(row.id, 1);
      expect(row.sessionMinutes, 30);
      final again = await repo.preferencesRow();
      expect(again.id, row.id);
    });

    test('savePreferences round-trips through the database', () async {
      await repo.savePreferences(
        const WorkoutPreferences(
          planStyle: WorkoutPlanStyle.muscleSplit,
          fitnessLevel: FitnessLevel.advanced,
          equipment: ['Mat', 'Dumbbells'],
          sessionMinutes: 45,
          trainingDaysMask: 0x15,
          goal: WorkoutGoal.strength,
          goalMuscles: [2, 3],
          preferredMinuteOfDay: 420,
          substitutions: {1: 2},
          safetyAcknowledged: true,
        ),
      );
      final loaded = WorkoutPreferences.fromRow(await repo.preferencesRow());
      expect(loaded.planStyle, WorkoutPlanStyle.muscleSplit);
      expect(loaded.fitnessLevel, FitnessLevel.advanced);
      expect(loaded.equipment, ['Mat', 'Dumbbells']);
      expect(loaded.sessionMinutes, 45);
      expect(loaded.trainingDaysMask, 0x15);
      expect(loaded.goal, WorkoutGoal.strength);
      expect(loaded.goalMuscles, [2, 3]);
      expect(loaded.preferredMinuteOfDay, 420);
      expect(loaded.substitutions, {1: 2});
      expect(loaded.safetyAcknowledged, isTrue);
    });
  });

  group('weekly planner', () {
    final monday = DateTime(2026, 1, 5);

    test('addScheduleEntry is visible in its week', () async {
      await repo.addScheduleEntry(date: DateTime(2026, 1, 6), title: 'Chest');
      final week = await repo.watchWeek(monday).first;
      expect(week, hasLength(1));
      expect(week.first.title, 'Chest');
      // A different week is unaffected.
      final otherWeek =
          await repo.watchWeek(WeekDates.shiftWeeks(monday, 1)).first;
      expect(otherWeek, isEmpty);
    });

    test('updateScheduleStatus records completion and session link', () async {
      final id = await repo.addScheduleEntry(date: monday);
      await repo.updateScheduleStatus(
        id,
        ScheduleStatus.completed.index,
        sessionId: 7,
      );
      final entry = (await repo.watchWeek(monday).first).single;
      expect(entry.status, ScheduleStatus.completed.index);
      expect(entry.sessionId, 7);
    });

    test('moveScheduleEntry re-dates the entry', () async {
      final id = await repo.addScheduleEntry(date: monday);
      await repo.moveScheduleEntry(id, DateTime(2026, 1, 9));
      final week = await repo.watchWeek(monday).first;
      expect(week.single.date, DateTime(2026, 1, 9));
    });

    test('generateWeek creates entries and preserves completed ones', () async {
      await repo.seedExercises();
      await repo.savePreferences(
        const WorkoutPreferences(
          trainingDaysMask: 0x7F, // every day
          planStyle: WorkoutPlanStyle.fullBody,
        ),
      );
      final created = await repo.generateWeek(monday);
      expect(created, greaterThan(0));
      var week = await repo.watchWeek(monday).first;
      expect(week.where((e) => e.planId != null), isNotEmpty);

      // Mark one planned entry complete, then regenerate.
      final completed = week.firstWhere((e) => e.planId != null);
      await repo.updateScheduleStatus(
        completed.id,
        ScheduleStatus.completed.index,
      );
      await repo.generateWeek(monday);
      week = await repo.watchWeek(monday).first;
      expect(
        week.any(
          (e) =>
              e.id == completed.id &&
              e.status == ScheduleStatus.completed.index,
        ),
        isTrue,
      );
    });
  });

  group('session outcome', () {
    test('finishSession records the outcome', () async {
      final id = await repo.startSession(name: 'Test');
      await repo.finishSession(id, durationSec: 120, outcome: 1);
      final session =
          await (db.select(db.workoutSessions)
            ..where((t) => t.id.equals(id))).getSingle();
      expect(session.endedAt, isNotNull);
      expect(session.durationSec, 120);
      expect(session.outcome, 1);
    });
  });
}
