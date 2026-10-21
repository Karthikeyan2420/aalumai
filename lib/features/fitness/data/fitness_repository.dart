import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/providers/providers.dart';
import '../domain/exercise_collections.dart';
import '../domain/exercise_format.dart';
import '../domain/weekly_planner.dart';
import '../domain/who_guidance.dart';
import '../domain/workout_preferences.dart';
import 'exercise_catalog.dart';

/// What a personal-record value measures. The index is stored as `recordType`.
enum PersonalRecordKind { weightGrams, reps, durationSec }

class FitnessRepository {
  FitnessRepository(this._db, {ExerciseCatalog? catalog})
    : _catalog = catalog ?? ExerciseCatalog();

  final AppDatabase _db;
  final ExerciseCatalog _catalog;

  // ---- Exercise library ---------------------------------------------------

  /// Imports the bundled dataset (Exercise Gym GIFs DB) into the local
  /// database. The dataset is read from an asset, so this is a one-off,
  /// offline operation: it is skipped entirely once any imported row exists,
  /// and never runs again after that.
  ///
  /// A database created by an older build still holds the previous hardcoded
  /// library. Those rows are removed here so they cannot linger beside the new
  /// catalogue; exercises the user created are preserved. Removing a row also
  /// removes the plan entries and set logs that pointed at it, so any plan
  /// left without exercises afterwards is dropped as well.
  Future<void> seedExercises() async {
    final existing = await _db.select(_db.exercises).get();
    if (existing.any((e) => e.sourceId.isNotEmpty)) return;

    final catalog = await _catalog.load();
    if (catalog.isEmpty) return;

    await _db.transaction(() async {
      if (existing.isNotEmpty) {
        await (_db.delete(_db.exercises)
          ..where((t) => t.isCustom.equals(false))).go();
        await _db.customStatement(
          'DELETE FROM workout_plans WHERE id NOT IN '
          '(SELECT DISTINCT plan_id FROM workout_plan_items)',
        );
        await _db.customStatement(
          'UPDATE workout_schedules SET plan_id = NULL '
          'WHERE plan_id NOT IN (SELECT id FROM workout_plans)',
        );
      }
      await _db.batch((b) {
        for (final exercise in catalog) {
          b.insert(_db.exercises, _companionFor(exercise));
        }
      });
    });
  }

  /// Maps one dataset record onto an exercises row.
  ///
  /// Difficulty is stored as [kUnknownDifficulty] because the dataset
  /// publishes none; sets, reps and rest are AALUMAI's own starting
  /// prescription, not dataset values.
  ExercisesCompanion _companionFor(CatalogExercise exercise) {
    final type = _exerciseTypeFor(exercise.category);
    final timed = type != 0;
    return ExercisesCompanion.insert(
      name: exercise.name,
      category: Value(_muscleGroupFor(exercise)),
      exerciseType: Value(type),
      targetMuscles: Value(
        exerciseTargetMuscles(
          muscle: exercise.muscle,
          secondaryMuscles: exercise.secondaryMuscles,
        ),
      ),
      equipment: Value(exercise.equipment),
      difficulty: const Value(kUnknownDifficulty),
      instructions: Value(exercise.instructions.join('\n')),
      isTimed: Value(timed),
      defaultSets: Value(type == 2 ? 2 : 3),
      defaultReps: Value(timed ? 0 : 10),
      defaultDurationSec: Value(switch (type) {
        1 => 40,
        2 => 30,
        _ => 0,
      }),
      restSec: Value(switch (type) {
        1 => 30,
        2 => 15,
        _ => 60,
      }),
      sourceId: Value(exercise.id),
      slug: Value(exercise.slug),
      bodyPart: Value(exercise.bodyPart),
      secondaryMuscles: Value(exercise.secondaryMuscles.join(',')),
      sourceCategory: Value(exercise.category),
      gifUrl: Value(exercise.gifUrl),
    );
  }

  /// Dataset movement category → broad app movement type
  /// (0 strength, 1 cardio, 2 mobility, 3 balance). Plyometrics behave like
  /// strength work here: they are counted in repetitions.
  static int _exerciseTypeFor(String datasetCategory) {
    return switch (datasetCategory.trim().toLowerCase()) {
      'cardio' => 1,
      'stretching' => 2,
      _ => 0,
    };
  }

  /// Dataset body part → the muscle-group index used across the fitness
  /// module (0 arms, 1 shoulders, 2 chest, 3 back, 4 legs, 5 core, 6 cardio,
  /// 7 yoga/mobility, 8 warm-up/cool-down). Stretching and mobility work is
  /// filed under yoga/mobility so the planner can keep using it as a
  /// cool-down block.
  static int _muscleGroupFor(CatalogExercise exercise) {
    if (exercise.category.trim().toLowerCase() == 'stretching') return 7;
    return switch (exercise.bodyPart.trim().toLowerCase()) {
      'arms' => 0,
      'shoulders' => 1,
      'chest' => 2,
      'back' => 3,
      'legs' => 4,
      'cardio' => 6,
      _ => 5,
    };
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

  Future<int> startSession({
    String name = '',
    int type = 0,
    int? planId,
    int? scheduledId,
    int totalSteps = 0,
    String routeJson = '',
  }) {
    return _db
        .into(_db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            name: Value(name),
            type: Value(type),
            startedAt: DateTime.now(),
            planId: Value(planId),
            scheduledId: Value(scheduledId),
            totalSteps: Value(totalSteps),
            routeJson: Value(routeJson),
          ),
        );
  }

  /// The in-progress guided session for [planId], if the app was interrupted
  /// mid-workout. Returns null when there is nothing to resume.
  Future<WorkoutSession?> activeSessionForPlan(int planId) async {
    final rows =
        await (_db.select(_db.workoutSessions)
              ..where((t) => t.planId.equals(planId) & t.endedAt.isNull())
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.startedAt,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first;
  }

  /// Remembers how far the guided player has progressed so an interrupted
  /// workout can be restored.
  Future<void> updateSessionProgress(int sessionId, int stepIndex) {
    return (_db.update(_db.workoutSessions)..where(
      (t) => t.id.equals(sessionId),
    )).write(WorkoutSessionsCompanion(stepIndex: Value(stepIndex)));
  }

  Future<void> finishSession(
    int sessionId, {
    required int durationSec,
    int distanceMeters = 0,
    int calories = 0,
    int outcome = 0,
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
        outcome: Value(outcome),
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
    bool isSkipped = false,
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
            isSkipped: Value(isSkipped),
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

  Stream<List<PersonalRecord>> watchRecords(int exerciseId) =>
      (_db.select(_db.personalRecords)
        ..where((t) => t.exerciseId.equals(exerciseId))).watch();

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

  Future<int> createPlan(
    String name, {
    int dayOfWeek = -1,
    int kind = 0,
    List<int> muscleGroups = const [],
    String description = '',
  }) => _db
      .into(_db.workoutPlans)
      .insert(
        WorkoutPlansCompanion.insert(
          name: name,
          dayOfWeek: Value(dayOfWeek),
          kind: Value(kind),
          muscleGroups: Value(muscleGroups.join(',')),
          description: Value(description),
        ),
      );

  /// Updates a plan's editable metadata (name/description/muscle groups).
  Future<void> updatePlanMeta({
    required int planId,
    String? name,
    List<int>? muscleGroups,
    String? description,
  }) {
    return (_db.update(_db.workoutPlans)
      ..where((t) => t.id.equals(planId))).write(
      WorkoutPlansCompanion(
        name: name == null ? const Value.absent() : Value(name),
        muscleGroups:
            muscleGroups == null
                ? const Value.absent()
                : Value(muscleGroups.join(',')),
        description:
            description == null ? const Value.absent() : Value(description),
      ),
    );
  }

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

  Future<void> deletePlan(int planId) =>
      (_db.delete(_db.workoutPlans)..where((t) => t.id.equals(planId))).go();

  Future<void> deletePlanItem(int itemId) =>
      (_db.delete(_db.workoutPlanItems)
        ..where((t) => t.id.equals(itemId))).go();

  Future<void> updatePlanItem({
    required int itemId,
    required int sets,
    required int reps,
    required int durationSec,
  }) {
    return (_db.update(_db.workoutPlanItems)
      ..where((t) => t.id.equals(itemId))).write(
      WorkoutPlanItemsCompanion(
        sets: Value(sets),
        reps: Value(reps),
        durationSec: Value(durationSec),
      ),
    );
  }

  /// Persists a new ordering for a plan's items (drag-to-reorder uses this).
  Future<void> reorderPlanItems(List<WorkoutPlanItem> ordered) async {
    await _db.transaction(() async {
      for (var i = 0; i < ordered.length; i++) {
        await (_db.update(_db.workoutPlanItems)..where(
          (t) => t.id.equals(ordered[i].id),
        )).write(WorkoutPlanItemsCompanion(orderIndex: Value(i)));
      }
    });
  }

  /// Seeds three practical starter plans the first time the app runs. Does
  /// nothing once any plan exists so user edits are never overwritten.
  ///
  /// The exercises are chosen from the imported catalogue by collection and
  /// muscle group rather than by name, so the templates keep working when the
  /// dataset is refreshed.
  Future<void> seedStarterPlans() async {
    final existing = await _db.select(_db.workoutPlans).get();
    if (existing.isNotEmpty) return;

    final exercises = await _db.select(_db.exercises).get();
    if (exercises.isEmpty) return;

    List<Exercise> pick({
      required WorkoutCollection collection,
      required List<int> categories,
      int perCategory = 1,
      int skip = 0,
    }) {
      final picked = <Exercise>[];
      for (final category in categories) {
        final matches =
            exercises
                .where(
                  (e) =>
                      e.category == category &&
                      exerciseCollection(e) == collection,
                )
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));
        picked.addAll(matches.skip(skip).take(perCategory));
      }
      return picked;
    }

    Future<void> addItems(int planId, List<Exercise> picks) async {
      for (var i = 0; i < picks.length; i++) {
        final e = picks[i];
        await addPlanItem(
          planId: planId,
          exerciseId: e.id,
          orderIndex: i,
          sets: e.defaultSets,
          reps: e.defaultReps,
          durationSec: e.defaultDurationSec,
        );
      }
    }

    final beginner = await createPlan(
      'Beginner full body',
      kind: 2,
      muscleGroups: const [2, 3, 4, 5],
      description: 'Starter template: gentle full-body circuit.',
    );
    await addItems(beginner, [
      ...pick(
        collection: WorkoutCollection.bodyweight,
        categories: const [2, 3, 4, 5],
      ),
      ...pick(collection: WorkoutCollection.stretching, categories: const [7]),
    ]);

    final dumbbell = await createPlan(
      'Dumbbell strength',
      kind: 2,
      muscleGroups: const [0, 1, 2, 3, 4],
      description: 'Starter template: full-body dumbbell strength.',
    );
    await addItems(dumbbell, [
      ...pick(
        collection: WorkoutCollection.dumbbell,
        categories: const [0, 1, 2, 3, 4],
      ),
      ...pick(
        collection: WorkoutCollection.dumbbell,
        categories: const [4, 0],
        skip: 1,
      ),
    ]);

    final bodyweight = await createPlan(
      'Bodyweight HIIT',
      kind: 2,
      muscleGroups: const [4, 5, 6],
      description: 'Starter template: fast bodyweight conditioning.',
    );
    await addItems(bodyweight, [
      ...pick(
        collection: WorkoutCollection.bodyweight,
        categories: const [4, 5, 6],
        perCategory: 2,
      ),
      ...pick(collection: WorkoutCollection.stretching, categories: const [7]),
    ]);
  }

  // ---- Workout preferences -------------------------------------------------

  /// The single preferences row, creating defaults on first access.
  Future<WorkoutPref> preferencesRow() async {
    final rows =
        await (_db.select(_db.workoutPrefs)
          ..where((t) => t.id.equals(1))).get();
    if (rows.isNotEmpty) return rows.first;
    await _db
        .into(_db.workoutPrefs)
        .insert(
          WorkoutPrefsCompanion.insert(),
          mode: InsertMode.insertOrIgnore,
        );
    return (await (_db.select(_db.workoutPrefs)
      ..where((t) => t.id.equals(1))).getSingle());
  }

  Stream<WorkoutPreferences> watchPreferences() async* {
    await preferencesRow();
    yield* (_db.select(_db.workoutPrefs)..where(
      (t) => t.id.equals(1),
    )).watchSingle().map(WorkoutPreferences.fromRow);
  }

  Future<void> savePreferences(WorkoutPreferences prefs) {
    return _db
        .into(_db.workoutPrefs)
        .insertOnConflictUpdate(
          WorkoutPrefsCompanion.insert(
            id: const Value(1),
            planStyle: Value(prefs.planStyle.index),
            fitnessLevel: Value(prefs.fitnessLevel.index),
            equipment: Value(WorkoutPreferences.encodeStrings(prefs.equipment)),
            sessionMinutes: Value(prefs.sessionMinutes),
            trainingDaysMask: Value(prefs.trainingDaysMask),
            restDaysMask: Value(prefs.restDaysMask),
            goal: Value(prefs.goal.index),
            goalMuscles: Value(
              WorkoutPreferences.encodeInts(prefs.goalMuscles),
            ),
            preferredMinuteOfDay: Value(prefs.preferredMinuteOfDay),
            substitutions: Value(
              WorkoutPreferences.encodeSubstitutions(prefs.substitutions),
            ),
            safetyAcknowledged: Value(prefs.safetyAcknowledged),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  // ---- Weekly planner -------------------------------------------------------

  /// Every planner entry whose date falls in the week containing [weekStart].
  Stream<List<WorkoutSchedule>> watchWeek(DateTime weekStart) {
    final start = WeekDates.startOfWeek(weekStart);
    final end = DateTime(start.year, start.month, start.day + 7);
    return (_db.select(_db.workoutSchedules)
          ..where(
            (t) =>
                t.date.isBiggerOrEqualValue(start) &
                t.date.isSmallerThanValue(end),
          )
          ..orderBy([
            (t) => OrderingTerm(expression: t.date),
            (t) => OrderingTerm(expression: t.orderIndex),
          ]))
        .watch();
  }

  Stream<List<WorkoutSchedule>> watchScheduleForDate(DateTime date) {
    final day = WeekDates.dayKey(date);
    final next = DateTime(day.year, day.month, day.day + 1);
    return (_db.select(_db.workoutSchedules)
          ..where(
            (t) =>
                t.date.isBiggerOrEqualValue(day) &
                t.date.isSmallerThanValue(next),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
        .watch();
  }

  Future<int> addScheduleEntry({
    required DateTime date,
    int? planId,
    String title = '',
    List<int> muscleGroups = const [],
    int status = 0,
    int orderIndex = 0,
    String notes = '',
  }) {
    return _db
        .into(_db.workoutSchedules)
        .insert(
          WorkoutSchedulesCompanion.insert(
            date: WeekDates.dayKey(date),
            planId: Value(planId),
            title: Value(title),
            muscleGroups: Value(muscleGroups.join(',')),
            status: Value(status),
            orderIndex: Value(orderIndex),
            notes: Value(notes),
          ),
        );
  }

  Future<void> updateScheduleStatus(int id, int status, {int? sessionId}) {
    return (_db.update(_db.workoutSchedules)
      ..where((t) => t.id.equals(id))).write(
      WorkoutSchedulesCompanion(
        status: Value(status),
        sessionId: sessionId == null ? const Value.absent() : Value(sessionId),
      ),
    );
  }

  Future<void> updateScheduleMeta(
    int id, {
    String? title,
    List<int>? muscleGroups,
    String? notes,
  }) {
    return (_db.update(_db.workoutSchedules)
      ..where((t) => t.id.equals(id))).write(
      WorkoutSchedulesCompanion(
        title: title == null ? const Value.absent() : Value(title),
        muscleGroups:
            muscleGroups == null
                ? const Value.absent()
                : Value(muscleGroups.join(',')),
        notes: notes == null ? const Value.absent() : Value(notes),
      ),
    );
  }

  /// Moves an entry to a new calendar day, appending it to that day's order.
  Future<void> moveScheduleEntry(int id, DateTime date) async {
    final day = WeekDates.dayKey(date);
    final existing = await watchScheduleForDate(day).first;
    await (_db.update(_db.workoutSchedules)
      ..where((t) => t.id.equals(id))).write(
      WorkoutSchedulesCompanion(
        date: Value(day),
        orderIndex: Value(existing.length),
      ),
    );
  }

  Future<void> reorderScheduleEntries(List<WorkoutSchedule> ordered) async {
    await _db.transaction(() async {
      for (var i = 0; i < ordered.length; i++) {
        await (_db.update(_db.workoutSchedules)..where(
          (t) => t.id.equals(ordered[i].id),
        )).write(WorkoutSchedulesCompanion(orderIndex: Value(i)));
      }
    });
  }

  Future<void> deleteScheduleEntry(int id) =>
      (_db.delete(_db.workoutSchedules)..where((t) => t.id.equals(id))).go();

  /// Copies an entry to [toDate] (defaulting to its own day).
  Future<int> duplicateScheduleEntry(int id, {DateTime? toDate}) async {
    final source =
        await (_db.select(_db.workoutSchedules)
          ..where((t) => t.id.equals(id))).getSingle();
    final day = WeekDates.dayKey(toDate ?? source.date);
    final existing = await watchScheduleForDate(day).first;
    return addScheduleEntry(
      date: day,
      planId: source.planId,
      title: source.title,
      muscleGroups: WorkoutPreferences.decodeInts(source.muscleGroups),
      status: ScheduleStatus.planned.index,
      orderIndex: existing.length,
      notes: source.notes,
    );
  }

  /// Deletes the planner entries for a week that have not yet been completed,
  /// leaving finish history intact.
  Future<void> clearPlannedWeek(DateTime weekStart) async {
    final entries = await watchWeek(weekStart).first;
    for (final e in entries) {
      if (e.status == ScheduleStatus.planned.index ||
          e.status == ScheduleStatus.missed.index ||
          e.status == ScheduleStatus.rest.index) {
        await deleteScheduleEntry(e.id);
      }
    }
  }

  /// Generates and persists a week of sessions from the stored preferences.
  /// Existing entries for the week are replaced only when they are un-started,
  /// so completed history is preserved.
  Future<int> generateWeek(DateTime weekStart) async {
    final prefs = WorkoutPreferences.fromRow(await preferencesRow());
    final exercises = await _db.select(_db.exercises).get();
    await clearPlannedWeek(weekStart);
    final days = WeekPlanGenerator.generate(
      preferences: prefs,
      exercises: exercises,
      weekStart: WeekDates.startOfWeek(weekStart),
      substitutions: prefs.substitutions,
    );
    var created = 0;
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      if (day.isRest) {
        await addScheduleEntry(
          date: day.date,
          title: '',
          muscleGroups: const [],
          status: ScheduleStatus.rest.index,
        );
        continue;
      }
      if (day.items.isEmpty) continue;
      final planId = await _persistGeneratedPlan(day);
      await addScheduleEntry(
        date: day.date,
        planId: planId,
        muscleGroups: day.muscleGroups,
        status: ScheduleStatus.planned.index,
      );
      created++;
    }
    return created;
  }

  Future<int> _persistGeneratedPlan(PlannedDay day) async {
    final planId = await createPlan(
      'Session ${day.muscleGroups.join('-')}',
      kind: 1,
      muscleGroups: day.muscleGroups,
    );
    for (var i = 0; i < day.items.length; i++) {
      final item = day.items[i];
      await addPlanItem(
        planId: planId,
        exerciseId: item.exerciseId,
        orderIndex: i,
        sets: item.sets,
        reps: item.reps,
        durationSec: item.durationSec,
      );
    }
    return planId;
  }

  // ---- Goals --------------------------------------------------------------

  Stream<List<FitnessGoal>> watchGoals() =>
      (_db.select(_db.fitnessGoals)
        ..orderBy([(t) => OrderingTerm(expression: t.id)])).watch();

  Future<int> createGoal({
    required int metric,
    required int targetValue,
    DateTime? targetDate,
    String note = '',
  }) {
    return _db
        .into(_db.fitnessGoals)
        .insert(
          FitnessGoalsCompanion.insert(
            metric: metric,
            targetValue: targetValue,
            targetDate: Value(targetDate),
            note: Value(note),
          ),
        );
  }

  Future<void> deleteGoal(int id) =>
      (_db.delete(_db.fitnessGoals)..where((t) => t.id.equals(id))).go();
}

/// The bundled exercise dataset, loaded once and shared by the whole app.
final exerciseCatalogProvider = Provider<ExerciseCatalog>(
  (ref) => ExerciseCatalog(),
);

final fitnessRepositoryProvider = Provider<FitnessRepository>(
  (ref) => FitnessRepository(
    ref.watch(appDatabaseProvider),
    catalog: ref.watch(exerciseCatalogProvider),
  ),
);

final exercisesProvider = StreamProvider<List<Exercise>>(
  (ref) => ref.watch(fitnessRepositoryProvider).watchExercises(),
);

final workoutSessionsProvider = StreamProvider<List<WorkoutSession>>(
  (ref) => ref.watch(fitnessRepositoryProvider).watchSessions(),
);

final exerciseRecordsProvider =
    StreamProvider.family<List<PersonalRecord>, int>(
      (ref, exerciseId) =>
          ref.watch(fitnessRepositoryProvider).watchRecords(exerciseId),
    );

final runsProvider = StreamProvider<List<WorkoutSession>>(
  (ref) => ref.watch(fitnessRepositoryProvider).watchRuns(),
);

final workoutSetLogsProvider = StreamProvider.family<List<WorkoutSetLog>, int>(
  (ref, sessionId) =>
      ref.watch(fitnessRepositoryProvider).watchSetLogs(sessionId),
);

final waterTodayProvider = StreamProvider<List<WaterLog>>(
  (ref) => ref.watch(fitnessRepositoryProvider).watchWaterToday(),
);

final measurementsProvider = StreamProvider<List<BodyMeasurement>>(
  (ref) => ref.watch(fitnessRepositoryProvider).watchMeasurements(),
);

final plansProvider = StreamProvider<List<WorkoutPlan>>(
  (ref) => ref.watch(fitnessRepositoryProvider).watchPlans(),
);

final planItemsProvider = StreamProvider.family<List<WorkoutPlanItem>, int>(
  (ref, planId) => ref.watch(fitnessRepositoryProvider).watchPlanItems(planId),
);

final fitnessGoalsProvider = StreamProvider<List<FitnessGoal>>(
  (ref) => ref.watch(fitnessRepositoryProvider).watchGoals(),
);

final workoutPreferencesProvider = StreamProvider<WorkoutPreferences>(
  (ref) => ref.watch(fitnessRepositoryProvider).watchPreferences(),
);

/// Planner entries for the week starting at [weekStart] (a Monday).
final scheduleWeekProvider =
    StreamProvider.family<List<WorkoutSchedule>, DateTime>(
      (ref, weekStart) =>
          ref.watch(fitnessRepositoryProvider).watchWeek(weekStart),
    );

/// Planner entries on a single calendar day.
final scheduleDayProvider = StreamProvider.family<
  List<WorkoutSchedule>,
  DateTime
>((ref, day) => ref.watch(fitnessRepositoryProvider).watchScheduleForDate(day));

/// Workout count and total distance for the current week (Monday-based).
class WeeklyActivity {
  const WeeklyActivity({required this.workouts, required this.distanceMeters});

  final int workouts;
  final int distanceMeters;
}

final weeklyActivityProvider = Provider<WeeklyActivity>((ref) {
  final sessions = ref.watch(workoutSessionsProvider).valueOrNull ?? const [];
  final now = DateTime.now();
  final startOfWeek = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: now.weekday - 1));
  var workouts = 0;
  var distance = 0;
  for (final s in sessions) {
    if (s.endedAt == null) continue;
    if (s.startedAt.isBefore(startOfWeek)) continue;
    workouts++;
    distance += s.distanceMeters;
  }
  return WeeklyActivity(workouts: workouts, distanceMeters: distance);
});

/// This week's progress against the WHO physical-activity guidance.
final whoWeeklyProgressProvider = Provider<WhoWeeklyProgress>((ref) {
  final sessions = ref.watch(workoutSessionsProvider).valueOrNull ?? const [];
  return whoWeeklyProgress(sessions);
});
