/// Pure helpers for computing alarm fire times. Kept free of plugin
/// dependencies so the logic is unit-testable.
class AlarmTime {
  /// Returns the next [DateTime] an alarm fires, given its [hour], [minute]
  /// and a repeat-days bitmask (bit 0 = Monday … bit 6 = Sunday).
  /// A zero mask means "once, daily".
  static DateTime next({
    required int hour,
    required int minute,
    required int repeatDaysMask,
    required DateTime from,
  }) {
    DateTime candidate = DateTime(
      from.year,
      from.month,
      from.day,
      hour,
      minute,
    );
    if (!candidate.isAfter(from)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    if (repeatDaysMask == 0) {
      return candidate;
    }
    var guard = 0;
    while ((repeatDaysMask & (1 << (candidate.weekday - 1))) == 0 &&
        guard < 14) {
      candidate = DateTime(
        candidate.year,
        candidate.month,
        candidate.day,
        hour,
        minute,
      ).add(const Duration(days: 1));
      guard++;
    }
    return candidate;
  }

  /// The list of ISO weekdays (1=Mon … 7=Sun) this alarm should fire on.
  /// Returns all seven when the mask is zero (daily).
  static List<int> weekdays(int repeatDaysMask) {
    if (repeatDaysMask == 0) return const [1, 2, 3, 4, 5, 6, 7];
    return [
      for (var i = 0; i < 7; i++)
        if ((repeatDaysMask & (1 << i)) != 0) i + 1,
    ];
  }

  static String format(int hour, int minute, {bool use24h = false}) {
    final mm = minute.toString().padLeft(2, '0');
    if (use24h) {
      return '${hour.toString().padLeft(2, '0')}:$mm';
    }
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour < 12 ? 'AM' : 'PM';
    return '$h:$mm $period';
  }
}
