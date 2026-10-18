import 'package:aalumai/features/fitness/domain/weekly_planner.dart';
import 'package:aalumai/features/fitness/domain/workout_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WeekDates', () {
    test('startOfWeek returns the Monday of the week', () {
      // 2026-01-08 is a Thursday.
      final start = WeekDates.startOfWeek(DateTime(2026, 1, 8, 15, 30));
      expect(start, DateTime(2026, 1, 5));
      expect(start.weekday, DateTime.monday);
    });

    test('startOfWeek is idempotent for a Monday', () {
      expect(WeekDates.startOfWeek(DateTime(2026, 1, 5)), DateTime(2026, 1, 5));
    });

    test('weekOf returns seven consecutive days from Monday', () {
      final days = WeekDates.weekOf(DateTime(2026, 1, 5));
      expect(days, hasLength(7));
      expect(days.first, DateTime(2026, 1, 5));
      expect(days.last, DateTime(2026, 1, 11));
    });

    test('shiftWeeks moves forward and backward by whole weeks', () {
      expect(
        WeekDates.shiftWeeks(DateTime(2026, 1, 5), 1),
        DateTime(2026, 1, 12),
      );
      expect(
        WeekDates.shiftWeeks(DateTime(2026, 1, 5), -1),
        DateTime(2025, 12, 29),
      );
    });

    test('isSameDay ignores the time component', () {
      expect(
        WeekDates.isSameDay(DateTime(2026, 2, 3, 8), DateTime(2026, 2, 3, 22)),
        isTrue,
      );
      expect(
        WeekDates.isSameDay(DateTime(2026, 2, 3), DateTime(2026, 2, 4)),
        isFalse,
      );
    });

    test('isPast compares against a supplied now', () {
      final now = DateTime(2026, 3, 10, 12);
      expect(WeekDates.isPast(DateTime(2026, 3, 9), now: now), isTrue);
      expect(WeekDates.isPast(DateTime(2026, 3, 10, 1), now: now), isFalse);
      expect(WeekDates.isPast(DateTime(2026, 3, 11), now: now), isFalse);
    });
  });

  test('scheduleStatusFromIndex clamps out-of-range values', () {
    expect(scheduleStatusFromIndex(0), ScheduleStatus.planned);
    expect(scheduleStatusFromIndex(3), ScheduleStatus.rest);
    expect(scheduleStatusFromIndex(99), ScheduleStatus.missed);
    expect(scheduleStatusFromIndex(-5), ScheduleStatus.planned);
  });
}
