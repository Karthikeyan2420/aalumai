import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/providers/providers.dart';
import '../../../core/services/reminder_scheduler.dart';
import '../../../core/utils/recurrence.dart';

enum TaskPriority {
  low,
  medium,
  high;

  static TaskPriority fromIndex(int v) =>
      TaskPriority.values[v.clamp(0, TaskPriority.values.length - 1)];
}

class TaskWithSubtasks {
  const TaskWithSubtasks({required this.task, required this.subtasks});
  final Task task;
  final List<Task> subtasks;

  int get completedSubtasks => subtasks.where((s) => s.isCompleted).length;
}

class TaskRepository {
  TaskRepository(this._db, [this._reminders]);

  final AppDatabase _db;
  final ReminderScheduler? _reminders;

  Stream<List<TaskWithSubtasks>> _watchTopLevel() {
    final query =
        _db.select(_db.tasks)
          ..where((t) => t.parentId.isNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.isCompleted),
            (t) => OrderingTerm(expression: t.dueDate, mode: OrderingMode.asc),
            (t) =>
                OrderingTerm(expression: t.priority, mode: OrderingMode.desc),
          ]);
    return query.watch().asyncMap(_withSubtasks);
  }

  Future<List<TaskWithSubtasks>> _withSubtasks(List<Task> tasks) async {
    final result = <TaskWithSubtasks>[];
    for (final task in tasks) {
      final subs =
          await (_db.select(_db.tasks)
                ..where((t) => t.parentId.equals(task.id))
                ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
              .get();
      result.add(TaskWithSubtasks(task: task, subtasks: subs));
    }
    return result;
  }

  Stream<List<TaskWithSubtasks>> watchAll() => _watchTopLevel();

  Stream<List<TaskWithSubtasks>> watchToday() => _watchTopLevel().map((list) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return list
        .where(
          (e) =>
              !e.task.isCompleted &&
              (e.task.dueDate == null || !e.task.dueDate!.isAfter(end)),
        )
        .toList();
  });

  Future<List<Task>> watchOverdueList() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return (_db.select(_db.tasks)..where(
      (t) =>
          t.isCompleted.equals(false) &
          t.dueDate.isSmallerThanValue(start) &
          t.parentId.isNull(),
    )).get();
  }

  Future<Task?> getById(int id) =>
      (_db.select(_db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Task>> subtasksOf(int parentId) =>
      (_db.select(_db.tasks)
            ..where((t) => t.parentId.equals(parentId))
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .get();

  Future<int> create({
    required String title,
    String notes = '',
    DateTime? dueDate,
    int dueMinuteOfDay = -1,
    TaskPriority priority = TaskPriority.medium,
    int? parentId,
    Recurrence recurrence = Recurrence.none,
    DateTime? reminderAt,
    String tagIds = '',
  }) async {
    final id = await _db
        .into(_db.tasks)
        .insert(
          TasksCompanion.insert(
            title: title,
            notes: Value(notes),
            dueDate: Value(dueDate),
            dueMinuteOfDay: Value(dueMinuteOfDay),
            priority: Value(priority.index),
            parentId: Value(parentId),
            recurrenceRule: Value(recurrence.encode()),
            reminderAt: Value(reminderAt),
            tagIds: Value(tagIds),
          ),
        );
    final task = await getById(id);
    if (task != null) await _reminders?.syncTask(task);
    return id;
  }

  Future<void> updateTask(Task task) async {
    await _db.update(_db.tasks).replace(task);
    await _reminders?.syncTask(task);
  }

  Future<void> delete(int id) async {
    await (_db.delete(_db.tasks)..where((t) => t.id.equals(id))).go();
    await _reminders?.removeTask(id);
  }

  /// Marks a task complete. For recurring tasks a new, future occurrence is
  /// created so occurrences are generated predictably without duplication.
  Future<void> setCompleted(Task task, bool completed) async {
    await _db.transaction(() async {
      await (_db.update(_db.tasks)..where((t) => t.id.equals(task.id))).write(
        TasksCompanion(
          isCompleted: Value(completed),
          completedAt: Value(completed ? DateTime.now() : null),
        ),
      );
      if (completed) {
        final rule = Recurrence.parse(task.recurrenceRule);
        if (rule.repeats && task.dueDate != null) {
          final nextDate = rule.next(task.dueDate!);
          final exists =
              await (_db.select(_db.tasks)..where(
                (t) =>
                    t.title.equals(task.title) &
                    t.dueDate.equals(nextDate) &
                    t.isCompleted.equals(false),
              )).get();
          if (exists.isEmpty) {
            await create(
              title: task.title,
              notes: task.notes,
              dueDate: nextDate,
              dueMinuteOfDay: task.dueMinuteOfDay,
              priority: TaskPriority.fromIndex(task.priority),
              recurrence: rule,
              tagIds: task.tagIds,
            );
          }
        }
      }
    });
    final updated = await getById(task.id);
    if (updated != null) await _reminders?.syncTask(updated);
  }

  /// Re-schedules reminders for every stored task. Called on app start.
  Future<void> reconcileReminders() async {
    if (_reminders == null) return;
    final tasks = await _db.select(_db.tasks).get();
    for (final task in tasks) {
      await _reminders.syncTask(task);
    }
  }

  Future<void> reschedule(Task task, DateTime newDate) async {
    await (_db.update(_db.tasks)..where(
      (t) => t.id.equals(task.id),
    )).write(TasksCompanion(dueDate: Value(newDate)));
  }

  Future<void> skipOccurrence(Task task) async {
    final rule = Recurrence.parse(task.recurrenceRule);
    if (!rule.repeats || task.dueDate == null) {
      await delete(task.id);
      return;
    }
    await reschedule(task, rule.next(task.dueDate!));
  }
}

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(reminderSchedulerProvider),
  ),
);

final allTasksProvider = StreamProvider<List<TaskWithSubtasks>>(
  (ref) => ref.watch(taskRepositoryProvider).watchAll(),
);

final todayTasksProvider = StreamProvider<List<TaskWithSubtasks>>(
  (ref) => ref.watch(taskRepositoryProvider).watchToday(),
);
