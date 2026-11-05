import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../preferences/app_preferences.dart';
import '../providers/providers.dart';
import '../utils/alarm_time.dart';
import '../utils/recurrence.dart';
import '../../features/habits/domain/habit_streak.dart';
import 'notification_service.dart';
import 'reminder_notifier.dart';

/// Payload prefix for reminder notifications (distinct from numeric alarm ids).
class ReminderPayload {
  const ReminderPayload._();

  static String event(int eventId) => 'event:$eventId';

  static String task(int taskId) => 'task:$taskId';

  static int? parseEventId(String? payload) {
    if (payload == null || !payload.startsWith('event:')) return null;
    return int.tryParse(payload.substring(6));
  }

  static int? parseTaskId(String? payload) {
    if (payload == null || !payload.startsWith('task:')) return null;
    return int.tryParse(payload.substring(5));
  }
}

/// Computes and (re)schedules the local reminders for tasks, habits and
/// calendar events, delegating the actual scheduling to a [ReminderNotifier].
class ReminderScheduler {
  ReminderScheduler(this._notifier, this._prefs);

  final ReminderNotifier _notifier;
  final AppPreferences _prefs;

  static const taskBase = 1000000;
  static const eventBase = 2000000;
  static const habitBase = 3000000;

  static int taskReminderId(int taskId) => taskBase + taskId;

  static int eventReminderId(int eventId) => eventBase + eventId;

  static int habitReminderId(int habitId, int weekday) =>
      habitBase + habitId * 10 + weekday;

  /// When a task should notify, from explicit [Task.reminderAt] or due date +
  /// time-of-day.
  static DateTime? reminderTimeFor(Task task) {
    if (task.reminderAt != null) return task.reminderAt;
    if (task.dueDate == null || task.dueMinuteOfDay < 0) return null;
    final d = task.dueDate!;
    return DateTime(
      d.year,
      d.month,
      d.day,
      task.dueMinuteOfDay ~/ 60,
      task.dueMinuteOfDay % 60,
    );
  }

  /// Preserves offset between due date and reminder when rolling recurring tasks.
  static DateTime? nextReminderFor(Task task, DateTime nextDueDate) {
    if (task.reminderAt != null && task.dueDate != null) {
      final offset = task.reminderAt!.difference(task.dueDate!);
      return nextDueDate.add(offset);
    }
    if (task.dueMinuteOfDay >= 0) {
      return DateTime(
        nextDueDate.year,
        nextDueDate.month,
        nextDueDate.day,
        task.dueMinuteOfDay ~/ 60,
        task.dueMinuteOfDay % 60,
      );
    }
    return null;
  }

  Future<void> cancelAll(AppDatabase db) async {
    final tasks = await db.select(db.tasks).get();
    for (final t in tasks) {
      await removeTask(t.id);
    }
    final habits = await db.select(db.habits).get();
    for (final h in habits) {
      await removeHabit(h.id);
    }
    final events = await db.select(db.events).get();
    for (final e in events) {
      await removeEvent(e.id);
    }
  }

  Future<void> syncTask(Task task) async {
    final id = taskReminderId(task.id);
    await _notifier.cancel(id);
    if (!_prefs.notificationsEnabled) return;
    final when = reminderTimeFor(task);
    if (when == null || task.isCompleted) return;
    if (!when.isAfter(DateTime.now())) return;
    await _notifier.scheduleReminder(
      id: id,
      title: task.title,
      body: task.notes,
      when: when,
      payload: ReminderPayload.task(task.id),
    );
  }

  Future<void> removeTask(int taskId) =>
      _notifier.cancel(taskReminderId(taskId));

  Future<void> syncHabit(Habit habit) async {
    await removeHabit(habit.id);
    if (!_prefs.notificationsEnabled) return;
    if (habit.isArchived || habit.reminderMinuteOfDay < 0) return;
    final hour = habit.reminderMinuteOfDay ~/ 60;
    final minute = habit.reminderMinuteOfDay % 60;
    final schedule = HabitSchedule.fromIndex(habit.scheduleType);
    if (schedule == HabitSchedule.selectedWeekdays && habit.weekdaysMask != 0) {
      for (final weekday in AlarmTime.weekdays(habit.weekdaysMask)) {
        await _notifier.scheduleDailyReminder(
          id: habitReminderId(habit.id, weekday),
          title: habit.name,
          body: habit.note,
          hour: hour,
          minute: minute,
          weekday: weekday,
        );
      }
    } else {
      await _notifier.scheduleDailyReminder(
        id: habitReminderId(habit.id, 0),
        title: habit.name,
        body: habit.note,
        hour: hour,
        minute: minute,
      );
    }
  }

  Future<void> removeHabit(int habitId) async {
    for (var weekday = 0; weekday <= 7; weekday++) {
      await _notifier.cancel(habitReminderId(habitId, weekday));
    }
  }

  Future<void> syncEvent(Event event) async {
    final id = eventReminderId(event.id);
    await _notifier.cancel(id);
    if (!_prefs.notificationsEnabled) return;
    if (event.reminderMinutes < 0) return;
    final when = nextReminderTime(event, DateTime.now());
    if (when == null) return;
    await _notifier.scheduleReminder(
      id: id,
      title: event.title,
      body: event.location.isNotEmpty ? event.location : event.description,
      when: when,
      payload: ReminderPayload.event(event.id),
    );
  }

  Future<void> removeEvent(int eventId) =>
      _notifier.cancel(eventReminderId(eventId));

  static DateTime? nextReminderTime(Event event, DateTime now) {
    if (event.reminderMinutes < 0) return null;
    final rule = Recurrence.parse(event.recurrenceRule);
    var occurrence = event.startAt;
    if (rule.repeats) {
      var guard = 0;
      while (occurrence.isBefore(now) && guard < 5000) {
        occurrence = rule.next(occurrence);
        guard++;
      }
    }
    final reminder = occurrence.subtract(
      Duration(minutes: event.reminderMinutes),
    );
    return reminder.isAfter(now) ? reminder : null;
  }
}

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => ReminderScheduler(
    ref.watch(notificationServiceProvider),
    ref.watch(appPreferencesProvider),
  ),
);
