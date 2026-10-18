import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/alarms/data/alarm_repository.dart';
import '../../features/habits/data/habit_repository.dart';
import '../../features/schedule/data/event_repository.dart';
import '../../features/tasks/data/task_repository.dart';
import '../db/database.dart';
import '../providers/providers.dart';
import 'alarm_scheduler.dart';
import 'notification_service.dart';
import 'reminder_notifier.dart';
import 'reminder_scheduler.dart';

/// The ids of every schedule that existed the moment *before* a backup restore.
///
/// Captured from the live database so that, once the database file has been
/// replaced by the restored one, OS schedules belonging to records that no
/// longer exist can still be cancelled. Without this, a restore could leave
/// orphaned alarms and reminders ringing forever.
@immutable
class ScheduleSnapshot {
  const ScheduleSnapshot({
    required this.alarmIds,
    required this.taskIds,
    required this.habitIds,
    required this.eventIds,
  });

  final Set<int> alarmIds;
  final Set<int> taskIds;
  final Set<int> habitIds;
  final Set<int> eventIds;

  /// Reads the current schedule-owning rows from [db].
  static Future<ScheduleSnapshot> capture(AppDatabase db) async {
    final alarms = await db.select(db.alarms).get();
    final tasks = await db.select(db.tasks).get();
    final habits = await db.select(db.habits).get();
    final events = await db.select(db.events).get();
    return ScheduleSnapshot(
      alarmIds: {for (final a in alarms) a.id},
      taskIds: {for (final t in tasks) t.id},
      habitIds: {for (final h in habits) h.id},
      eventIds: {for (final e in events) e.id},
    );
  }
}

/// The truthful outcome of a post-restore reconciliation. The UI must only
/// announce a fully successful restore when [isComplete] is true.
@immutable
class RestoreOutcome {
  const RestoreOutcome({
    required this.obsoleteCancelled,
    required this.alarmsReconciled,
    required this.remindersReconciled,
    required this.errors,
  });

  /// Whether every obsolete (pre-restore) OS schedule was cancelled.
  final bool obsoleteCancelled;

  /// Whether the restored alarm set was re-armed without error.
  final bool alarmsReconciled;

  /// Whether restored task/habit/event reminders were re-armed without error.
  final bool remindersReconciled;

  /// Human-readable descriptions of every step that failed. Never empty when
  /// the restore is only partial.
  final List<String> errors;

  bool get isComplete =>
      obsoleteCancelled && alarmsReconciled && remindersReconciled;

  @override
  String toString() =>
      'RestoreOutcome(complete: $isComplete, obsolete: $obsoleteCancelled, '
      'alarms: $alarmsReconciled, reminders: $remindersReconciled, '
      'errors: $errors)';
}

/// Rebuilds the OS schedule set to match the database after a restore.
///
/// It reuses the existing repository and scheduler APIs rather than talking to
/// the notification plugin directly, so the exact-alarm fallback, time-zone
/// conversion and recurrence rules stay in one place:
///
///  * obsolete schedules from the *previous* database are cancelled;
///  * restored alarms are re-armed through [AlarmRepository.reconcile] (which
///    re-arms only enabled alarms and never duplicates slots);
///  * restored task, habit and event reminders are re-armed through each
///    repository's `reconcileReminders`.
///
/// Every step is wrapped so a partial failure is reported in [RestoreOutcome]
/// instead of corrupting the restored data or stopping the remaining steps.
class RestoreReconciler {
  RestoreReconciler({
    required AppDatabase database,
    required AlarmScheduler alarmScheduler,
    required ReminderNotifier reminderNotifier,
    required AlarmRepository alarmRepository,
    required TaskRepository taskRepository,
    required HabitRepository habitRepository,
    required EventRepository eventRepository,
  }) : _database = database,
       _alarmScheduler = alarmScheduler,
       _reminderNotifier = reminderNotifier,
       _alarmRepository = alarmRepository,
       _taskRepository = taskRepository,
       _habitRepository = habitRepository,
       _eventRepository = eventRepository;

  final AppDatabase _database;
  final AlarmScheduler _alarmScheduler;
  final ReminderNotifier _reminderNotifier;
  final AlarmRepository _alarmRepository;
  final TaskRepository _taskRepository;
  final HabitRepository _habitRepository;
  final EventRepository _eventRepository;

  /// Captures the schedules that exist before a restore.
  Future<ScheduleSnapshot> snapshot() => ScheduleSnapshot.capture(_database);

  /// Cancels obsolete schedules and re-arms everything present in the restored
  /// database. Call this after the database file has been replaced and the
  /// providers rebuilt against it.
  Future<RestoreOutcome> reconcile(ScheduleSnapshot before) async {
    final errors = <String>[];
    var obsoleteCancelled = true;

    try {
      obsoleteCancelled = await _cancelObsolete(before, errors);
    } catch (e) {
      obsoleteCancelled = false;
      errors.add('obsolete schedules: $e');
    }

    var alarmsReconciled = true;
    try {
      await _alarmRepository.reconcile();
      final error = _alarmRepository.schedulingStatus.lastError;
      if (error != null) {
        alarmsReconciled = false;
        errors.add('alarms: $error');
      }
    } catch (e) {
      alarmsReconciled = false;
      errors.add('alarms: $e');
    }

    var remindersReconciled = true;
    for (final reconcile in <Future<void> Function()>[
      _taskRepository.reconcileReminders,
      _habitRepository.reconcileReminders,
      _eventRepository.reconcileReminders,
    ]) {
      try {
        await reconcile();
      } catch (e) {
        remindersReconciled = false;
        errors.add('reminders: $e');
      }
    }

    return RestoreOutcome(
      obsoleteCancelled: obsoleteCancelled,
      alarmsReconciled: alarmsReconciled,
      remindersReconciled: remindersReconciled,
      errors: errors,
    );
  }

  /// Cancels every schedule that belonged to the pre-restore database but whose
  /// record is absent from the restored database. Cancelling is best-effort per
  /// id so one failure cannot block the rest. Returns `false` when any obsolete
  /// schedule could not be cancelled, so the caller can report a partial result.
  Future<bool> _cancelObsolete(
    ScheduleSnapshot before,
    List<String> errors,
  ) async {
    var succeeded = true;
    final restoredAlarmIds =
        (await _database.select(_database.alarms).get())
            .map((a) => a.id)
            .toSet();
    final restoredTaskIds =
        (await _database.select(_database.tasks).get())
            .map((t) => t.id)
            .toSet();
    final restoredHabitIds =
        (await _database.select(_database.habits).get())
            .map((h) => h.id)
            .toSet();
    final restoredEventIds =
        (await _database.select(_database.events).get())
            .map((e) => e.id)
            .toSet();

    for (final id in before.alarmIds.difference(restoredAlarmIds)) {
      try {
        await _alarmScheduler.cancelAlarm(id);
        await _alarmScheduler.cancelAlarmSnooze(id);
      } catch (e) {
        succeeded = false;
        errors.add('obsolete alarm $id: $e');
      }
    }

    for (final id in before.taskIds.difference(restoredTaskIds)) {
      try {
        await _reminderNotifier.cancel(ReminderScheduler.taskReminderId(id));
      } catch (e) {
        succeeded = false;
        errors.add('obsolete task reminder $id: $e');
      }
    }

    for (final id in before.habitIds.difference(restoredHabitIds)) {
      for (var weekday = 0; weekday <= 7; weekday++) {
        try {
          await _reminderNotifier.cancel(
            ReminderScheduler.habitReminderId(id, weekday),
          );
        } catch (e) {
          succeeded = false;
          errors.add('obsolete habit reminder $id: $e');
        }
      }
    }

    for (final id in before.eventIds.difference(restoredEventIds)) {
      try {
        await _reminderNotifier.cancel(ReminderScheduler.eventReminderId(id));
      } catch (e) {
        succeeded = false;
        errors.add('obsolete event reminder $id: $e');
      }
    }

    return succeeded;
  }
}

final restoreReconcilerProvider = Provider<RestoreReconciler>((ref) {
  final notifications = ref.watch(notificationServiceProvider);
  return RestoreReconciler(
    database: ref.watch(appDatabaseProvider),
    alarmScheduler: notifications,
    reminderNotifier: notifications,
    alarmRepository: ref.watch(alarmRepositoryProvider),
    taskRepository: ref.watch(taskRepositoryProvider),
    habitRepository: ref.watch(habitRepositoryProvider),
    eventRepository: ref.watch(eventRepositoryProvider),
  );
});
