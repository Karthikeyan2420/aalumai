/// The metric a fitness goal tracks. Stored in the database as the enum index.
enum FitnessGoalMetric { workoutsPerWeek, waterDaily, distanceWeekly }

/// How far the user has progressed toward [metric]'s [targetValue], from 0 to 1.
///
/// Pure so the arithmetic can be unit-tested without a database or widgets.
double goalProgress({
  required int metric,
  required int targetValue,
  required int workoutsThisWeek,
  required int waterTodayMl,
  required int distanceThisWeekMeters,
}) {
  if (targetValue <= 0) return 0;
  final value = goalCurrentValue(
    metric: metric,
    workoutsThisWeek: workoutsThisWeek,
    waterTodayMl: waterTodayMl,
    distanceThisWeekMeters: distanceThisWeekMeters,
  );
  return (value / targetValue).clamp(0.0, 1.0);
}

/// The raw measured value behind a goal, in the metric's own unit.
int goalCurrentValue({
  required int metric,
  required int workoutsThisWeek,
  required int waterTodayMl,
  required int distanceThisWeekMeters,
}) {
  final m =
      FitnessGoalMetric.values[metric.clamp(
        0,
        FitnessGoalMetric.values.length - 1,
      )];
  return switch (m) {
    FitnessGoalMetric.workoutsPerWeek => workoutsThisWeek,
    FitnessGoalMetric.waterDaily => waterTodayMl,
    FitnessGoalMetric.distanceWeekly => distanceThisWeekMeters,
  };
}

/// A display unit suffix for the metric's target and current value.
String goalUnit(int metric, {required String ml, required String meters}) {
  final m =
      FitnessGoalMetric.values[metric.clamp(
        0,
        FitnessGoalMetric.values.length - 1,
      )];
  return switch (m) {
    FitnessGoalMetric.workoutsPerWeek => '',
    FitnessGoalMetric.waterDaily => ml,
    FitnessGoalMetric.distanceWeekly => meters,
  };
}
