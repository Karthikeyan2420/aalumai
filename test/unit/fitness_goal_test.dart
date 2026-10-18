import 'package:aalumai/features/fitness/domain/fitness_goal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('goalProgress', () {
    test('workouts made so far over the weekly target', () {
      final p = goalProgress(
        metric: FitnessGoalMetric.workoutsPerWeek.index,
        targetValue: 4,
        workoutsThisWeek: 2,
        waterTodayMl: 0,
        distanceThisWeekMeters: 0,
      );
      expect(p, 0.5);
    });

    test('clamps at 1 when the target is exceeded', () {
      final p = goalProgress(
        metric: FitnessGoalMetric.waterDaily.index,
        targetValue: 2000,
        workoutsThisWeek: 0,
        waterTodayMl: 3500,
        distanceThisWeekMeters: 0,
      );
      expect(p, 1.0);
    });

    test('is zero for a non-positive target', () {
      final p = goalProgress(
        metric: FitnessGoalMetric.distanceWeekly.index,
        targetValue: 0,
        workoutsThisWeek: 0,
        waterTodayMl: 0,
        distanceThisWeekMeters: 5000,
      );
      expect(p, 0);
    });

    test('current value reads the metric-specific source', () {
      expect(
        goalCurrentValue(
          metric: FitnessGoalMetric.distanceWeekly.index,
          workoutsThisWeek: 3,
          waterTodayMl: 800,
          distanceThisWeekMeters: 7200,
        ),
        7200,
      );
    });

    test('an out-of-range metric index does not throw', () {
      expect(
        goalCurrentValue(
          metric: 99,
          workoutsThisWeek: 1,
          waterTodayMl: 0,
          distanceThisWeekMeters: 0,
        ),
        0,
      );
    });
  });
}
