import 'dart:math';

/// Habit schedule kinds.
enum HabitSchedule {
  daily,
  selectedWeekdays,
  weeklyTarget;

  static HabitSchedule fromIndex(int value) =>
      HabitSchedule.values[value.clamp(0, HabitSchedule.values.length - 1)];
}

/// Pure streak calculations. Streaks are computed from *eligible scheduled
/// dates*, never from rolling 24-hour windows.
class HabitStreak {
  /// Returns true when [date] (a calendar day) is an eligible day for a habit.
  static bool isEligibleDay({
    required HabitSchedule schedule,
    required int weekdaysMask,
    required DateTime date,
  }) {
    switch (schedule) {
      case HabitSchedule.daily:
        return true;
      case HabitSchedule.selectedWeekdays:
        return (weekdaysMask & (1 << (date.weekday - 1))) != 0;
      case HabitSchedule.weeklyTarget:
        return true;
    }
  }

  /// Current streak length in eligible days for daily / selected-weekday
  /// schedules. [completedDays] must contain normalised (date-only) days.
  static int currentDayStreak({
    required HabitSchedule schedule,
    required int weekdaysMask,
    required Set<DateTime> completedDays,
    required DateTime today,
  }) {
    if (schedule == HabitSchedule.weeklyTarget) return 0;
    var streak = 0;
    var cursor = DateTime(today.year, today.month, today.day);
    // Allow a grace period for "today" so an unfinished day does not reset.
    var graceUsed = false;
    for (var i = 0; i < 3660; i++) {
      if (isEligibleDay(
        schedule: schedule,
        weekdaysMask: weekdaysMask,
        date: cursor,
      )) {
        final done = completedDays.contains(cursor);
        if (done) {
          streak++;
        } else if (!graceUsed && _isSameDay(cursor, today)) {
          graceUsed = true;
        } else if (!graceUsed) {
          break;
        } else {
          break;
        }
      }
      cursor = cursor.subtract(const Duration(days: 1));
      if (streak > 5000) break;
    }
    return streak;
  }

  /// The correct current streak for [schedule].
  ///
  /// Weekly-target habits are measured in qualifying *weeks* against
  /// [targetPerWeek]; every other schedule is measured in eligible *days*.
  /// This is the single entry point the UI should use so a weekly habit is
  /// never shown a meaningless day streak.
  static int currentStreak({
    required HabitSchedule schedule,
    required int weekdaysMask,
    required int targetPerWeek,
    required Set<DateTime> completedDays,
    required DateTime today,
  }) {
    if (schedule == HabitSchedule.weeklyTarget) {
      return currentWeeklyStreak(
        targetPerWeek: targetPerWeek,
        completionsByWeekStart: completionsByWeek(completedDays),
        today: today,
      );
    }
    return currentDayStreak(
      schedule: schedule,
      weekdaysMask: weekdaysMask,
      completedDays: completedDays,
      today: today,
    );
  }

  /// Groups normalised [completedDays] into a count per ISO week start
  /// (Monday), matching [startOfWeek].
  static Map<DateTime, int> completionsByWeek(
    Iterable<DateTime> completedDays,
  ) {
    final byWeek = <DateTime, int>{};
    for (final day in completedDays) {
      final week = startOfWeek(day);
      byWeek[week] = (byWeek[week] ?? 0) + 1;
    }
    return byWeek;
  }

  /// Current streak in eligible weeks for weekly-target habits.
  static int currentWeeklyStreak({
    required int targetPerWeek,
    required Map<DateTime, int> completionsByWeekStart,
    required DateTime today,
  }) {
    if (targetPerWeek <= 0) return 0;
    final thisWeek = startOfWeek(today);
    var streak = 0;
    var week = thisWeek;
    var graceUsed = false;
    for (var i = 0; i < 520; i++) {
      final count = completionsByWeekStart[week] ?? 0;
      if (count >= targetPerWeek) {
        streak++;
      } else if (!graceUsed && week == thisWeek) {
        graceUsed = true;
      } else {
        break;
      }
      week = week.subtract(const Duration(days: 7));
    }
    return streak;
  }

  static int bestWeeklyStreak({
    required int targetPerWeek,
    required Iterable<DateTime> completedDays,
  }) {
    if (targetPerWeek <= 0) return 0;
    final byWeek = <DateTime, int>{};
    for (final day in completedDays) {
      final wk = startOfWeek(day);
      byWeek[wk] = (byWeek[wk] ?? 0) + 1;
    }
    final weeks = byWeek.keys.toList()..sort();
    var best = 0;
    var run = 0;
    DateTime? prev;
    for (final wk in weeks) {
      if (byWeek[wk]! >= targetPerWeek) {
        if (prev != null && wk.difference(prev).inDays == 7) {
          run++;
        } else {
          run = 1;
        }
        best = max(best, run);
      } else {
        run = 0;
      }
      prev = wk;
    }
    return best;
  }

  static DateTime startOfWeek(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  static DateTime normalize(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
