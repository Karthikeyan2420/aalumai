import 'workout_preferences.dart';

/// Date helpers for the Monday-first weekly planner. Kept pure so date maths
/// can be unit-tested independently of the database or UI.
class WeekDates {
  const WeekDates._();

  /// Midnight on the Monday of [date]'s week.
  static DateTime startOfWeek(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  /// The seven day-dates of the week containing [date].
  static List<DateTime> weekOf(DateTime date) {
    final start = startOfWeek(date);
    return [
      for (var i = 0; i < 7; i++)
        DateTime(start.year, start.month, start.day + i),
    ];
  }

  /// Shifts a week-start by [weeks] (negative goes back).
  static DateTime shiftWeeks(DateTime weekStart, int weeks) {
    final s = startOfWeek(weekStart);
    return DateTime(s.year, s.month, s.day + weeks * 7);
  }

  /// True when [a] and [b] fall on the same calendar day.
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Normalises any timestamp to midnight of its own day.
  static DateTime dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  /// True when the given day is strictly before today.
  static bool isPast(DateTime date, {DateTime? now}) {
    final today = dayKey(now ?? DateTime.now());
    return dayKey(date).isBefore(today);
  }
}

/// Maps a persisted schedule status integer onto [ScheduleStatus].
ScheduleStatus scheduleStatusFromIndex(int value) =>
    ScheduleStatus.values[value.clamp(0, ScheduleStatus.values.length - 1)];
