import 'package:aalumai/features/habits/domain/habit_streak.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _d(int y, int m, int day) => DateTime(y, m, day);

void main() {
  group('HabitStreak.isEligibleDay', () {
    test('daily is always eligible', () {
      for (var i = 0; i < 7; i++) {
        expect(
          HabitStreak.isEligibleDay(
            schedule: HabitSchedule.daily,
            weekdaysMask: 0,
            date: _d(2024, 1, 1 + i),
          ),
          isTrue,
        );
      }
    });

    test('selected weekdays respects the mask', () {
      // Monday (bit 0) and Wednesday (bit 2).
      const mask = 0x05;
      expect(
        HabitStreak.isEligibleDay(
          schedule: HabitSchedule.selectedWeekdays,
          weekdaysMask: mask,
          date: _d(2024, 1, 1), // Monday
        ),
        isTrue,
      );
      expect(
        HabitStreak.isEligibleDay(
          schedule: HabitSchedule.selectedWeekdays,
          weekdaysMask: mask,
          date: _d(2024, 1, 2), // Tuesday
        ),
        isFalse,
      );
      expect(
        HabitStreak.isEligibleDay(
          schedule: HabitSchedule.selectedWeekdays,
          weekdaysMask: mask,
          date: _d(2024, 1, 3), // Wednesday
        ),
        isTrue,
      );
    });
  });

  group('HabitStreak.currentDayStreak', () {
    test('counts consecutive completed days', () {
      final today = _d(2024, 1, 10);
      final completed = {_d(2024, 1, 10), _d(2024, 1, 9), _d(2024, 1, 8)};
      expect(
        HabitStreak.currentDayStreak(
          schedule: HabitSchedule.daily,
          weekdaysMask: 0,
          completedDays: completed,
          today: today,
        ),
        3,
      );
    });

    test('grants grace when today is not yet completed', () {
      final today = _d(2024, 1, 10);
      final completed = {_d(2024, 1, 9), _d(2024, 1, 8)};
      expect(
        HabitStreak.currentDayStreak(
          schedule: HabitSchedule.daily,
          weekdaysMask: 0,
          completedDays: completed,
          today: today,
        ),
        2,
      );
    });

    test('breaks on a missed eligible day', () {
      final today = _d(2024, 1, 10);
      final completed = {_d(2024, 1, 10), _d(2024, 1, 8)};
      expect(
        HabitStreak.currentDayStreak(
          schedule: HabitSchedule.daily,
          weekdaysMask: 0,
          completedDays: completed,
          today: today,
        ),
        1,
      );
    });

    test('weekly-target habits have no day streak', () {
      expect(
        HabitStreak.currentDayStreak(
          schedule: HabitSchedule.weeklyTarget,
          weekdaysMask: 0,
          completedDays: {_d(2024, 1, 10)},
          today: _d(2024, 1, 10),
        ),
        0,
      );
    });
  });

  group('HabitStreak.currentWeeklyStreak', () {
    test('counts consecutive qualifying weeks with grace for current week', () {
      final today = _d(2024, 1, 10); // Wednesday
      final map = {
        HabitStreak.startOfWeek(today): 1, // current week, below target
        _d(2024, 1, 1): 3,
        _d(2023, 12, 25): 3,
      };
      expect(
        HabitStreak.currentWeeklyStreak(
          targetPerWeek: 3,
          completionsByWeekStart: map,
          today: today,
        ),
        2,
      );
    });
  });

  group('HabitStreak.bestWeeklyStreak', () {
    test('finds the longest run of qualifying weeks', () {
      final days = <DateTime>[
        _d(2024, 1, 1),
        _d(2024, 1, 2),
        _d(2024, 1, 3),
        _d(2024, 1, 8),
        _d(2024, 1, 9),
        _d(2024, 1, 10),
      ];
      expect(
        HabitStreak.bestWeeklyStreak(targetPerWeek: 3, completedDays: days),
        2,
      );
    });
  });

  group('HabitStreak.completionsByWeek', () {
    test('groups normalised days by their Monday week start', () {
      final byWeek = HabitStreak.completionsByWeek([
        _d(2024, 1, 1), // Mon
        _d(2024, 1, 3), // Wed (same week)
        _d(2024, 1, 7), // Sun (same week)
        _d(2024, 1, 8), // Mon next week
      ]);
      expect(byWeek[_d(2024, 1, 1)], 3);
      expect(byWeek[_d(2024, 1, 8)], 1);
    });
  });

  group('HabitStreak.currentStreak', () {
    test('delegates daily habits to the day streak', () {
      final today = _d(2024, 1, 10);
      expect(
        HabitStreak.currentStreak(
          schedule: HabitSchedule.daily,
          weekdaysMask: 0,
          targetPerWeek: 7,
          completedDays: {_d(2024, 1, 10), _d(2024, 1, 9)},
          today: today,
        ),
        HabitStreak.currentDayStreak(
          schedule: HabitSchedule.daily,
          weekdaysMask: 0,
          completedDays: {_d(2024, 1, 10), _d(2024, 1, 9)},
          today: today,
        ),
      );
    });

    test('delegates selected-weekday habits to the day streak', () {
      final today = _d(2024, 1, 10); // Wednesday
      const mask = 0x05; // Mon + Wed
      final completed = {_d(2024, 1, 10), _d(2024, 1, 8), _d(2024, 1, 3)};
      expect(
        HabitStreak.currentStreak(
          schedule: HabitSchedule.selectedWeekdays,
          weekdaysMask: mask,
          targetPerWeek: 7,
          completedDays: completed,
          today: today,
        ),
        HabitStreak.currentDayStreak(
          schedule: HabitSchedule.selectedWeekdays,
          weekdaysMask: mask,
          completedDays: completed,
          today: today,
        ),
      );
    });

    test('measures weekly-target habits in weeks, not days', () {
      final today = _d(2024, 1, 10); // Wednesday
      // Two full prior weeks (Mon 1st, Mon 8th-current) plus the current week.
      final completed = {
        // week of 2023-12-25
        _d(2023, 12, 25),
        _d(2023, 12, 26),
        _d(2023, 12, 27),
        // week of 2024-01-01
        _d(2024, 1, 1),
        _d(2024, 1, 2),
        _d(2024, 1, 3),
        // current week of 2024-01-08 (only 1 so far)
        _d(2024, 1, 8),
      };
      expect(
        HabitStreak.currentStreak(
          schedule: HabitSchedule.weeklyTarget,
          weekdaysMask: 0,
          targetPerWeek: 3,
          completedDays: completed,
          today: today,
        ),
        2,
        reason: 'weekly habit must report week streak, never a day streak',
      );
    });
  });

  test('startOfWeek returns Monday', () {
    expect(HabitStreak.startOfWeek(_d(2024, 1, 10)), _d(2024, 1, 8));
    expect(HabitStreak.startOfWeek(_d(2024, 1, 7)), _d(2024, 1, 1));
  });

  test('HabitSchedule.fromIndex clamps out-of-range values', () {
    expect(HabitSchedule.fromIndex(99), HabitSchedule.weeklyTarget);
    expect(HabitSchedule.fromIndex(-1), HabitSchedule.daily);
  });
}
