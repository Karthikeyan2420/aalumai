import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../utils/alarm_time.dart';
import '../utils/recurrence.dart';
import '../../features/habits/domain/habit_streak.dart';
import 'notification_service.dart';
import 'reminder_notifier.dart';

/// Computes and (re)schedules the local reminders for tasks, habits and
/// calendar events, delegating the actual scheduling to a [ReminderNotifier].
///
/// All reminder ids live in dedicated high ranges so they can never collide
/// with alarm ids (which are small multiples of ten).
class ReminderScheduler {
  ReminderScheduler(this._notifier);

  final ReminderNotifier _notifier;

  static const taskBase = 1000000;
  static const eventBase = 2000000;
  static const habitBase = 3000000;

  static int taskReminderId(int taskId) => taskBase + taskId;

  static int eventReminderId(int eventId) => eventBase + eventId;

  static int habitReminderId(int habitId, int weekday) =>
      habitBase + habitId * 10 + weekday;

  // ---- Tasks ---------------------------------------------------------------

  /// Schedules (or clears) the one-off reminder for [task].
  Future<void> syncTask(Task task) async {
    final id = taskReminderId(task.id);
    await _notifier.cancel(id);
    final when = task.reminderAt;
    if (when == null || task.isCompleted) return;
    if (!when.isAfter(DateTime.now())) return;
    await _notifier.scheduleReminder(
      id: id,
      title: task.title,
      body: task.notes,
      when: when,
    );
  }

  Future<void> removeTask(int taskId) =>
      _notifier.cancel(taskReminderId(taskId));

  // ---- Habits --------------------------------------------------------------

  /// Schedules (or clears) the repeating reminder(s) for [habit]. A habit with
  /// a time-of-day but no selected weekdays fires every day; a habit scheduled
  /// on selected weekdays fires on each of those weekdays.
  Future<void> syncHabit(Habit habit) async {
    await removeHabit(habit.id);
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

  // ---- Events --------------------------------------------------------------

  /// Schedules (or clears) the reminder for [event]. Recurring events schedule
  /// their next occurrence; the reminder is refreshed on app start and
  /// whenever the event changes.
  Future<void> syncEvent(Event event) async {
    final id = eventReminderId(event.id);
    await _notifier.cancel(id);
    if (event.reminderMinutes < 0) return;
    final when = nextReminderTime(event, DateTime.now());
    if (when == null) return;
    await _notifier.scheduleReminder(
      id: id,
      title: event.title,
      body: event.location.isNotEmpty ? event.location : event.description,
      when: when,
    );
  }

  Future<void> removeEvent(int eventId) =>
      _notifier.cancel(eventReminderId(eventId));

  /// The next reminder [DateTime] for [event] at or after [now], or `null` if
  /// no reminder should be scheduled.
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
  (ref) => ReminderScheduler(ref.watch(notificationServiceProvider)),
);
