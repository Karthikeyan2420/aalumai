import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/providers/providers.dart';
import 'exercise_library.dart';

class FitnessRepository {
  FitnessRepository(this._db);

  final AppDatabase _db;

  // ---- Exercise library ---------------------------------------------------

  Future<void> seedExercises() async {
    final existing = await _db.select(_db.exercises).get();
    if (existing.isNotEmpty) return;
    await _db.batch((b) {
      for (final e in kExerciseLibrary) {
        b.insert(
          _db.exercises,
          ExercisesCompanion.insert(
            name: e.name,
            category: Value(e.category),
            targetMuscles: Value(e.targetMuscles),
            equipment: Value(e.equipment),
            difficulty: Value(e.difficulty),
            instructions: Value(e.instructions),
            safetyNotes: Value(e.safetyNotes),
            isTimed: Value(e.isTimed),
            defaultSets: Value(e.sets),
            defaultReps: Value(e.reps),
            defaultDurationSec: Value(e.durationSec),
            restSec: Value(e.restSec),
          ),
        );
      }
    });
  }

  Stream<List<Exercise>> watchExercises({int? category}) {
    final q = _db.select(_db.exercises)..orderBy([
      (t) => OrderingTerm(expression: t.category),
      (t) => OrderingTerm(expression: t.name),
    ]);
    if (category != null) {
      q.where((t) => t.category.equals(category));
    }
    return q.watch();
  }

  Future<int> addCustomExercise({
    required String name,
    int category = 0,
    String targetMuscles = '',
    String equipment = '',
    int difficulty = 0,
    String instructions = '',
    String safetyNotes = '',
    bool isTimed = false,
    int sets = 3,
    int reps = 10,
    int durationSec = 0,
    int restSec = 60,
  }) {
    return _db
        .into(_db.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: name,
            category: Value(category),
            targetMuscles: Value(targetMuscles),
            equipment: Value(equipment),
            difficulty: Value(difficulty),
            instructions: Value(instructions),
            safetyNotes: Value(safetyNotes),
            isCustom: const Value(true),
            isTimed: Value(isTimed),
            defaultSets: Value(sets),
            defaultReps: Value(reps),
            defaultDurationSec: Value(durationSec),
            restSec: Value(restSec),
          ),
        );
  }

  // ---- Workout sessions ---------------------------------------------------

  Stream<List<WorkoutSession>> watchSessions({int limit = 100}) =>
      (_db.select(_db.workoutSessions)
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.startedAt,
                mode: OrderingMode.desc,
              ),
            ])
            ..limit(limit))
          .watch();

  Future<int> startSession({String name = '', int type = 0}) {
    return _db
        .into(_db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            name: Value(name),
            type: Value(type),
            startedAt: DateTime.now(),
          ),
        );
  }

  Future<void> finishSession(
    int sessionId, {
    required int durationSec,
    int distanceMeters = 0,
    int calories = 0,
    String notes = '',
    String routeJson = '',
  }) {
    final pace =
        distanceMeters > 0
            ? (durationSec / (distanceMeters / 1000)).round()
            : 0;
    return (_db.update(_db.workoutSessions)
      ..where((t) => t.id.equals(sessionId))).write(
      WorkoutSessionsCompanion(
        endedAt: Value(DateTime.now()),
        durationSec: Value(durationSec),
        distanceMeters: Value(distanceMeters),
        avgPaceSecPerKm: Value(pace),
        calories: Value(calories),
        notes: Value(notes),
        routeJson: Value(routeJson),
      ),
    );
  }

  Future<void> deleteSession(int sessionId) =>
      (_db.delete(_db.workoutSessions)
        ..where((t) => t.id.equals(sessionId))).go();

  Future<int> logSet({
    required int sessionId,
    required int exerciseId,
    required int setIndex,
    required int reps,
    int weightGrams = 0,
    int durationSec = 0,
    int restSec = 0,
    bool isCompleted = true,
  }) {
    return _db
        .into(_db.workoutSetLogs)
        .insert(
          WorkoutSetLogsCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            setIndex: Value(setIndex),
            reps: Value(reps),
            weightGrams: Value(weightGrams),
            durationSec: Value(durationSec),
            restSec: Value(restSec),
            isCompleted: Value(isCompleted),
          ),
        );
  }

  Stream<List<WorkoutSetLog>> watchSetLogs(int sessionId) =>
      (_db.select(_db.workoutSetLogs)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm(expression: t.setIndex)]))
          .watch();

  // ---- Personal records & progression ------------------------------------

  /// Updates the personal record for an exercise if [value] is a new best.
  /// Returns true when a new record was set.
  Future<bool> updatePersonalRecord({
    required int exerciseId,
    required int recordType,
    required int value,
  }) async {
    final existing =
        await (_db.select(_db.personalRecords)
              ..where(
                (t) =>
                    t.exerciseId.equals(exerciseId) &
                    t.recordType.equals(recordType),
              )
              ..orderBy([
                (t) =>
                    OrderingTerm(expression: t.value, mode: OrderingMode.desc),
              ])
              ..limit(1))
            .get();
    if (existing.isEmpty) {
      await _db
          .into(_db.personalRecords)
          .insert(
            PersonalRecordsCompanion.insert(
              exerciseId: exerciseId,
              recordType: Value(recordType),
              value: value,
            ),
          );
      return true;
    }
    if (value > existing.first.value) {
      await _db
          .into(_db.personalRecords)
          .insert(
            PersonalRecordsCompanion.insert(
              exerciseId: exerciseId,
              recordType: Value(recordType),
              value: value,
            ),
          );
      return true;
    }
    return false;
  }

  Future<PersonalRecord?> bestRecord(int exerciseId, int recordType) async {
    final rows =
        await (_db.select(_db.personalRecords)
              ..where(
                (t) =>
                    t.exerciseId.equals(exerciseId) &
                    t.recordType.equals(recordType),
              )
              ..orderBy([
                (t) =>
                    OrderingTerm(expression: t.value, mode: OrderingMode.desc),
              ])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first;
  }

  /// Simple double-progression suggestion based on logged sets.
  Future<String> progressionSuggestion(int exerciseId) async {
    final logs =
        await (_db.select(_db.workoutSetLogs)
              ..where((t) => t.exerciseId.equals(exerciseId))
              ..orderBy([
                (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
              ])
              ..limit(9))
            .get();
    if (logs.length < 9) return 'increase_weight';
    final avgReps =
        logs.map((l) => l.reps).reduce((a, b) => a + b) / logs.length;
    final avgWeight =
        logs.map((l) => l.weightGrams).reduce((a, b) => a + b) / logs.length;
    if (avgReps >= 12 && avgWeight > 0) return 'increase_weight';
    return 'increase_reps';
  }

  // ---- Water --------------------------------------------------------------

  Future<int> addWater(int amountMl) => _db
      .into(_db.waterLogs)
      .insert(
        WaterLogsCompanion.insert(amountMl: amountMl, loggedAt: DateTime.now()),
      );

  Future<void> deleteWaterLog(int id) =>
      (_db.delete(_db.waterLogs)..where((t) => t.id.equals(id))).go();

  Stream<List<WaterLog>> watchWaterToday() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return (_db.select(_db.waterLogs)
      ..where((t) => t.loggedAt.isBetweenValues(start, end))).watch();
  }

  Future<int> waterTotalToday() async {
    final rows = await watchWaterToday().first;
    return rows.fold<int>(0, (sum, r) => sum + r.amountMl);
  }

  // ---- Measurements -------------------------------------------------------

  Stream<List<BodyMeasurement>> watchMeasurements() =>
      (_db.select(_db.bodyMeasurements)..orderBy([
        (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
      ])).watch();

  Future<int> addMeasurement({
    required DateTime date,
    int weightGrams = 0,
    double bodyFatPercent = 0,
    double waistCm = 0,
    String note = '',
  }) {
    return _db
        .into(_db.bodyMeasurements)
        .insert(
          BodyMeasurementsCompanion.insert(
            date: date,
            weightGrams: Value(weightGrams),
            bodyFatPercent: Value(bodyFatPercent),
            waistCm: Value(waistCm),
            note: Value(note),
          ),
        );
  }

  // ---- Run/walk -----------------------------------------------------------

  Stream<List<WorkoutSession>> watchRuns() =>
      (_db.select(_db.workoutSessions)
            ..where((t) => t.type.equals(1) | t.type.equals(2))
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.startedAt,
                mode: OrderingMode.desc,
              ),
            ]))
          .watch();

  // ---- Plans --------------------------------------------------------------

  Stream<List<WorkoutPlan>> watchPlans() =>
      (_db.select(_db.workoutPlans)
        ..orderBy([(t) => OrderingTerm(expression: t.id)])).watch();

  Future<int> createPlan(String name, {int dayOfWeek = -1}) => _db
      .into(_db.workoutPlans)
      .insert(
        WorkoutPlansCompanion.insert(name: name, dayOfWeek: Value(dayOfWeek)),
      );

  Future<void> addPlanItem({
    required int planId,
    required int exerciseId,
    int orderIndex = 0,
    int sets = 3,
    int reps = 10,
    int durationSec = 0,
  }) {
    return _db
        .into(_db.workoutPlanItems)
        .insert(
          WorkoutPlanItemsCompanion.insert(
            planId: planId,
            exerciseId: exerciseId,
            orderIndex: Value(orderIndex),
            sets: Value(sets),
            reps: Value(reps),
            durationSec: Value(durationSec),
          ),
        );
  }

  Stream<List<WorkoutPlanItem>> watchPlanItems(int planId) =>
      (_db.select(_db.workoutPlanItems)
            ..where((t) => t.planId.equals(planId))
            ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
          .watch();
}

final fitnessRepositoryProvider = Provider<FitnessRepository>(
  (ref) => FitnessRepository(ref.watch(appDatabaseProvider)),
);

final exercisesProvider = StreamProvider<List<Exercise>>(
  (ref) => ref.watch(fitnessRepositoryProvider).watchExercises(),
);

final workoutSessionsProvider = StreamProvider<List<WorkoutSession>>(
  (ref) => ref.watch(fitnessRepositoryProvider).watchSessions(),
);

final waterTodayProvider = StreamProvider<List<WaterLog>>(
  (ref) => ref.watch(fitnessRepositoryProvider).watchWaterToday(),
);

final measurementsProvider = StreamProvider<List<BodyMeasurement>>(
  (ref) => ref.watch(fitnessRepositoryProvider).watchMeasurements(),
);
