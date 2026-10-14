import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/providers/providers.dart';
import '../domain/habit_streak.dart';

class HabitRepository {
  HabitRepository(this._db);

  final AppDatabase _db;

  Stream<List<Habit>> watchActive() {
    return (_db.select(_db.habits)
          ..where((t) => t.isArchived.equals(false))
          ..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.createdAt),
          ]))
        .watch();
  }

  Stream<List<Habit>> watchAll() =>
      (_db.select(_db.habits)
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt)])).watch();

  Future<int> create({
    required String name,
    String note = '',
    HabitSchedule schedule = HabitSchedule.daily,
    int weekdaysMask = 0,
    int targetPerWeek = 7,
    bool isMeasurable = false,
    double goalValue = 0,
    String unit = '',
    int reminderMinuteOfDay = -1,
  }) {
    return _db
        .into(_db.habits)
        .insert(
          HabitsCompanion.insert(
            name: name,
            note: Value(note),
            scheduleType: Value(schedule.index),
            weekdaysMask: Value(weekdaysMask),
            targetPerWeek: Value(targetPerWeek),
            isMeasurable: Value(isMeasurable),
            goalValue: Value(goalValue),
            unit: Value(unit),
            reminderMinuteOfDay: Value(reminderMinuteOfDay),
          ),
        );
  }

  Future<void> updateHabit(Habit habit) =>
      _db.update(_db.habits).replace(habit);

  Future<void> setArchived(int id, bool archived) => (_db.update(_db.habits)
    ..where(
      (t) => t.id.equals(id),
    )).write(HabitsCompanion(isArchived: Value(archived)));

  Future<void> deleteHabit(int id) =>
      (_db.delete(_db.habits)..where((t) => t.id.equals(id))).go();

  Stream<List<HabitCompletion>> watchCompletionsBetween(
    DateTime from,
    DateTime to,
  ) {
    final f = DateTime(from.year, from.month, from.day);
    final t = DateTime(to.year, to.month, to.day, 23, 59, 59);
    return (_db.select(_db.habitCompletions)
          ..where((c) => c.day.isBetweenValues(f, t))
          ..orderBy([(c) => OrderingTerm(expression: c.day)]))
        .watch();
  }

  Future<List<HabitCompletion>> completionsForHabit(int habitId) =>
      (_db.select(_db.habitCompletions)
        ..where((c) => c.habitId.equals(habitId))).get();

  Future<bool> isCompleted(int habitId, DateTime day) async {
    final d = HabitStreak.normalize(day);
    final rows =
        await (_db.select(_db.habitCompletions)
          ..where((c) => c.habitId.equals(habitId) & c.day.equals(d))).get();
    return rows.isNotEmpty;
  }

  Future<void> setCompleted(
    int habitId,
    DateTime day, {
    required bool completed,
    double value = 0,
    String note = '',
  }) async {
    final d = HabitStreak.normalize(day);
    await _db.transaction(() async {
      await (_db.delete(_db.habitCompletions)
        ..where((c) => c.habitId.equals(habitId) & c.day.equals(d))).go();
      if (completed) {
        await _db
            .into(_db.habitCompletions)
            .insert(
              HabitCompletionsCompanion.insert(
                habitId: habitId,
                day: d,
                value: Value(value),
                note: Value(note),
              ),
            );
      }
    });
  }

  Future<Set<DateTime>> completedDays(int habitId) async {
    final rows = await completionsForHabit(habitId);
    return rows.map((r) => HabitStreak.normalize(r.day)).toSet();
  }
}

final habitRepositoryProvider = Provider<HabitRepository>(
  (ref) => HabitRepository(ref.watch(appDatabaseProvider)),
);

final activeHabitsProvider = StreamProvider<List<Habit>>(
  (ref) => ref.watch(habitRepositoryProvider).watchActive(),
);

/// Completions for the current week (Monday..Sunday).
final weekHabitCompletionsProvider = StreamProvider<List<HabitCompletion>>((
  ref,
) {
  final now = DateTime.now();
  final start = HabitStreak.startOfWeek(now);
  final end = start.add(const Duration(days: 6));
  return ref.watch(habitRepositoryProvider).watchCompletionsBetween(start, end);
});
