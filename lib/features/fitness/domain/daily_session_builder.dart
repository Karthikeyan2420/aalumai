import '../../../core/db/database.dart';
import 'equipment_filter.dart';
import 'workout_preferences.dart';

/// Builds the fixed daily template: ~10 min stretch, then weekday muscle work
/// sized to [WorkoutPreferences.sessionMinutes] (30 / 60 / 90 / 120).
class DailySessionBuilder {
  const DailySessionBuilder._();

  static const stretchTargetSec = 600;

  static int snapSessionMinutes(int raw) {
    if (raw <= 45) return 30;
    if (raw <= 75) return 60;
    if (raw <= 105) return 90;
    return 120;
  }

  static int mainSetsFor(int minutes) => switch (minutes) {
    30 => 3,
    60 => 4,
    90 => 4,
    _ => 5,
  };

  static int restSecFor(int minutes) => switch (minutes) {
    30 => 45,
    60 => 60,
    _ => 75,
  };

  static List<MuscleGroup> muscleGroupsForWeekday(int weekday) =>
      switch (weekday) {
        DateTime.monday => const [1],
        DateTime.tuesday => const [2],
        DateTime.wednesday => const [3],
        DateTime.thursday => const [0],
        DateTime.friday => const [4],
        DateTime.saturday => const [5],
        _ => const [0, 1, 2, 3, 4, 6],
      };

  static String focusLabel(int weekday) => switch (weekday) {
    DateTime.monday => 'Shoulders',
    DateTime.tuesday => 'Chest',
    DateTime.wednesday => 'Back',
    DateTime.thursday => 'Arms',
    DateTime.friday => 'Legs',
    DateTime.saturday => 'Core',
    _ => 'Full body',
  };

  static String motivationLine(int weekday) =>
      '10 minutes to open the body — then ${focusLabel(weekday)}. You’ve got this.';

  /// Day index in a 30-day block starting at [planStart] (1-based).
  static int dayNumberInPlan(DateTime date, DateTime planStart) {
    final a = DateTime(date.year, date.month, date.day);
    final b = DateTime(planStart.year, planStart.month, planStart.day);
    return a.difference(b).inDays + 1;
  }

  static PlannedDay? buildDay({
    required DateTime date,
    required WorkoutPreferences preferences,
    required List<Exercise> exercises,
    Map<int, int> substitutions = const {},
  }) {
    if (exercises.isEmpty) return null;
    final minutes = snapSessionMinutes(preferences.sessionMinutes);
    final stretch = _buildStretchBlock(exercises, substitutions);
    if (stretch.isEmpty) return null;
    final stretchSec = WeekPlanGenerator.estimateDurationSec(stretch);
    final mainTargetSec = (minutes * 60 - stretchSec).clamp(600, 7200);
    final groups = muscleGroupsForWeekday(date.weekday);
    final main = _buildMainBlock(
      exercises: exercises,
      preferences: preferences,
      groups: groups,
      targetSec: mainTargetSec,
      minutes: minutes,
      substitutions: substitutions,
      weekday: date.weekday,
    );
    if (main.isEmpty) return null;
    return PlannedDay(
      date: date,
      title: focusLabel(date.weekday),
      muscleGroups: groups,
      items: [...stretch, ...main],
    );
  }

  static List<PlannedItem> _buildStretchBlock(
    List<Exercise> exercises,
    Map<int, int> substitutions,
  ) {
    const patterns = [
      'jumping jack',
      'push-up',
      'push up',
      'neck',
      'wrist',
      'elbow',
      'shoulder',
      'hip',
      'hamstring',
      'quad',
      'calf',
      'ankle',
    ];
    final home =
        exercises
            .where((e) => isHomeCompatible(e.equipment, WorkoutMode.bodyweight))
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));

    final picked = <Exercise>[];
    final used = <int>{};

    Exercise? pick(bool Function(Exercise e) test) {
      for (final e in home) {
        if (used.contains(e.id)) continue;
        if (test(e)) {
          used.add(e.id);
          return e;
        }
      }
      return null;
    }

    for (final pattern in patterns) {
      if (picked.length >= 8) break;
      final p = pattern.toLowerCase();
      final e = pick((x) => x.name.toLowerCase().contains(p));
      if (e != null) picked.add(e);
    }

    if (picked.length < 6) {
      for (final e in home) {
        if (picked.length >= 8) break;
        if (used.contains(e.id)) continue;
        if (e.category == 6 || e.category == 7 || e.category == 8) {
          used.add(e.id);
          picked.add(e);
        }
      }
    }

    return [
      for (final e in picked)
        PlannedItem(
          exerciseId: _sub(e.id, substitutions),
          sets: 1,
          reps: 0,
          durationSec: e.isTimed ? 45 : 40,
          restSec: 15,
        ),
    ];
  }

  static List<PlannedItem> _buildMainBlock({
    required List<Exercise> exercises,
    required WorkoutPreferences preferences,
    required List<MuscleGroup> groups,
    required int targetSec,
    required int minutes,
    required Map<int, int> substitutions,
    required int weekday,
  }) {
    final sets = mainSetsFor(minutes);
    final rest = restSecFor(minutes);
    final maxLevel = preferences.fitnessLevel.index + 1;
    final selected = _equipment(preferences);

    final pool =
        exercises.where((e) {
          if (!isHomeCompatible(e.equipment, WorkoutMode.dumbbell) &&
              !isHomeCompatible(e.equipment, WorkoutMode.bodyweight)) {
            return false;
          }
          if (e.difficulty >= 0 && e.difficulty > maxLevel) return false;
          if (!isEquipmentSelected(e.equipment, selected)) return false;
          if (weekday == DateTime.sunday) {
            return groups.contains(e.category) ||
                e.category == 6 ||
                e.sourceCategory.toLowerCase() == 'cardio';
          }
          return groups.contains(e.category);
        }).toList()..sort((a, b) => a.id.compareTo(b.id));

    if (pool.isEmpty) return const [];

    var exerciseCount = 4;
    List<PlannedItem> best = const [];
    var bestDiff = 1 << 30;

    while (exerciseCount <= 14) {
      final slice = <Exercise>[];
      final used = <int>{};
      for (var i = 0; i < pool.length && slice.length < exerciseCount; i++) {
        final e = pool[(i + weekday) % pool.length];
        if (used.add(e.id)) slice.add(e);
      }
      final items = [
        for (final e in slice)
          PlannedItem(
            exerciseId: _sub(e.id, substitutions),
            sets: sets,
            reps: e.isTimed ? 0 : (e.defaultReps > 0 ? e.defaultReps : 12),
            durationSec: e.isTimed ? (e.defaultDurationSec > 0 ? 40 : 40) : 0,
            restSec: rest,
          ),
      ];
      final est = WeekPlanGenerator.estimateDurationSec(items);
      final diff = (est - targetSec).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = items;
      }
      if (est >= targetSec * 0.9 && est <= targetSec * 1.1) break;
      exerciseCount++;
    }
    return best;
  }

  static Set<String> _equipment(WorkoutPreferences preferences) {
    if (preferences.equipment.isEmpty) {
      return defaultEquipmentSelection().toSet();
    }
    return preferences.equipment.map((e) => e.trim().toLowerCase()).toSet();
  }

  static int _sub(int id, Map<int, int> substitutions) =>
      substitutions[id] ?? id;
}
