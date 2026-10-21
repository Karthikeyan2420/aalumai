import '../../../core/db/database.dart';
import 'equipment_filter.dart';

/// Overall structure the planner uses when generating a week.
enum WorkoutPlanStyle { balanced, muscleSplit, fullBody, cardioFocus }

/// The user's main reason for training; guides exercise selection.
enum WorkoutGoal {
  generalHealth,
  strength,
  endurance,
  flexibility,
  weightManagement,
}

/// Training experience, aligned with exercise difficulty (0..2).
enum FitnessLevel { beginner, intermediate, advanced }

/// How a generated day turned out, shown in the planner history.
enum ScheduleStatus { planned, completed, skipped, rest, missed }

/// A muscle-group category index used across the fitness module.
typedef MuscleGroup = int;

/// Immutable snapshot of the user's workout preferences.
class WorkoutPreferences {
  const WorkoutPreferences({
    this.planStyle = WorkoutPlanStyle.balanced,
    this.fitnessLevel = FitnessLevel.beginner,
    this.equipment = const [],
    this.sessionMinutes = 75,
    this.trainingDaysMask = 0x1F,
    this.restDaysMask = 0,
    this.goal = WorkoutGoal.generalHealth,
    this.goalMuscles = const [],
    this.preferredMinuteOfDay = -1,
    this.substitutions = const {},
    this.safetyAcknowledged = false,
  });

  final WorkoutPlanStyle planStyle;
  final FitnessLevel fitnessLevel;
  final List<String> equipment;
  final int sessionMinutes;

  /// Days the user trains, bits 0..6 = Monday..Sunday.
  final int trainingDaysMask;
  final int restDaysMask;
  final WorkoutGoal goal;
  final List<MuscleGroup> goalMuscles;
  final int preferredMinuteOfDay;

  /// Preferred replacements: exerciseId -> substitute exerciseId.
  final Map<int, int> substitutions;

  final bool safetyAcknowledged;

  bool trainsOn(int weekday) => TrainingDays.has(trainingDaysMask, weekday);

  bool restsOn(int weekday) => TrainingDays.has(restDaysMask, weekday);

  WorkoutPreferences copyWith({
    WorkoutPlanStyle? planStyle,
    FitnessLevel? fitnessLevel,
    List<String>? equipment,
    int? sessionMinutes,
    int? trainingDaysMask,
    int? restDaysMask,
    WorkoutGoal? goal,
    List<MuscleGroup>? goalMuscles,
    int? preferredMinuteOfDay,
    Map<int, int>? substitutions,
    bool? safetyAcknowledged,
  }) {
    return WorkoutPreferences(
      planStyle: planStyle ?? this.planStyle,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      equipment: equipment ?? this.equipment,
      sessionMinutes: sessionMinutes ?? this.sessionMinutes,
      trainingDaysMask: trainingDaysMask ?? this.trainingDaysMask,
      restDaysMask: restDaysMask ?? this.restDaysMask,
      goal: goal ?? this.goal,
      goalMuscles: goalMuscles ?? this.goalMuscles,
      preferredMinuteOfDay: preferredMinuteOfDay ?? this.preferredMinuteOfDay,
      substitutions: substitutions ?? this.substitutions,
      safetyAcknowledged: safetyAcknowledged ?? this.safetyAcknowledged,
    );
  }

  static List<int> decodeInts(String csv) {
    if (csv.trim().isEmpty) return const [];
    return csv
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList();
  }

  static String encodeInts(Iterable<int> values) => values.join(',');

  static List<String> decodeStrings(String csv) {
    if (csv.trim().isEmpty) return const [];
    return csv
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static String encodeStrings(Iterable<String> values) => values.join(',');

  static Map<int, int> decodeSubstitutions(String raw) {
    final map = <int, int>{};
    for (final pair in raw.split(',')) {
      final parts = pair.split('>');
      if (parts.length != 2) continue;
      final from = int.tryParse(parts[0].trim());
      final to = int.tryParse(parts[1].trim());
      if (from != null && to != null) map[from] = to;
    }
    return map;
  }

  static String encodeSubstitutions(Map<int, int> subs) =>
      subs.entries.map((e) => '${e.key}>${e.value}').join(',');

  /// Builds preferences from a database row.
  factory WorkoutPreferences.fromRow(WorkoutPref row) {
    return WorkoutPreferences(
      planStyle:
          WorkoutPlanStyle.values[row.planStyle.clamp(
            0,
            WorkoutPlanStyle.values.length - 1,
          )],
      fitnessLevel:
          FitnessLevel.values[row.fitnessLevel.clamp(
            0,
            FitnessLevel.values.length - 1,
          )],
      equipment: decodeStrings(row.equipment),
      sessionMinutes: row.sessionMinutes,
      trainingDaysMask: row.trainingDaysMask,
      restDaysMask: row.restDaysMask,
      goal:
          WorkoutGoal.values[row.goal.clamp(0, WorkoutGoal.values.length - 1)],
      goalMuscles: decodeInts(row.goalMuscles),
      preferredMinuteOfDay: row.preferredMinuteOfDay,
      substitutions: decodeSubstitutions(row.substitutions),
      safetyAcknowledged: row.safetyAcknowledged,
    );
  }
}

/// Bit helpers for the Monday-first training/rest day masks.
class TrainingDays {
  const TrainingDays._();

  static bool has(int mask, int weekday) {
    if (weekday < 1 || weekday > 7) return false;
    return (mask & (1 << (weekday - 1))) != 0;
  }

  static int toggle(int mask, int weekday) {
    if (weekday < 1 || weekday > 7) return mask;
    return mask ^ (1 << (weekday - 1));
  }

  static int fromWeekdays(Iterable<int> weekdays) {
    var mask = 0;
    for (final d in weekdays) {
      if (d >= 1 && d <= 7) mask |= 1 << (d - 1);
    }
    return mask;
  }

  static List<int> toWeekdays(int mask) => [
    for (var d = 1; d <= 7; d++)
      if ((mask & (1 << (d - 1))) != 0) d,
  ];
}

/// One planned exercise inside a generated day.
class PlannedItem {
  const PlannedItem({
    required this.exerciseId,
    required this.sets,
    required this.reps,
    required this.durationSec,
    required this.restSec,
  });

  final int exerciseId;
  final int sets;
  final int reps;
  final int durationSec;
  final int restSec;

  /// Rough time this item takes, including rests between sets.
  int get estimatedSec {
    final perSet = durationSec > 0 ? durationSec : (reps * 4).clamp(15, 90);
    final rest = restSec * (sets > 1 ? sets - 1 : 0);
    return perSet * sets + rest;
  }
}

/// A single day produced by the planner generator (may be a rest day).
class PlannedDay {
  const PlannedDay({
    required this.date,
    required this.title,
    required this.muscleGroups,
    required this.items,
    this.isRest = false,
  });

  final DateTime date;
  final String title;
  final List<MuscleGroup> muscleGroups;
  final List<PlannedItem> items;
  final bool isRest;
}

/// Reasons the planner may warn about a generated week. Warnings are advisory
/// and never block the user, per the product requirements.
enum PlanWarningKind {
  duplicateExercise,
  consecutiveSameMuscle,
  tooManyConsecutiveDays,
  heavyVolume,
}

class PlanWarning {
  const PlanWarning(this.kind, this.detail);
  final PlanWarningKind kind;
  final String detail;
}

/// The WHO-informed Mon–Sun split used by the "Daily workout" card.
///
/// WHO physical-activity guidance asks adults to do moderate aerobic activity
/// most days and muscle-strengthening work on at least two days a week, so
/// every day here pairs a strength focus with a cardio block. Yoga & mobility
/// closes each session rather than opening it: static stretching before loaded
/// work can lower power output, so mobility work belongs in the cool-down,
/// while the warm-up phase already supplies short dynamic movement. Sunday is
/// an active-recovery day built from cardio plus yoga.
class WhoDailyPlan {
  const WhoDailyPlan._();

  /// Strength focus per weekday (`DateTime.monday` … `DateTime.sunday`).
  static const Map<int, List<MuscleGroup>> strengthFocus = {
    DateTime.monday: [2, 0], // chest + biceps
    DateTime.tuesday: [3, 0], // back + triceps
    DateTime.wednesday: [4, 1], // legs + shoulders
    DateTime.thursday: [2, 0], // chest + biceps
    DateTime.friday: [3, 0], // back + triceps
    DateTime.saturday: [4, 5], // legs + core
    DateTime.sunday: [], // active recovery
  };

  /// Aerobic block, present on every day.
  static const MuscleGroup cardio = 6;

  /// Mobility block, present on every day as the finish.
  static const MuscleGroup yoga = 7;

  static bool isRecovery(int weekday) =>
      (strengthFocus[weekday] ?? const []).isEmpty;

  static List<MuscleGroup> focusFor(int weekday) =>
      strengthFocus[weekday] ?? const [];

  /// Strength focus first, then one cardio block, then yoga as the cool-down.
  static List<MuscleGroup> groupsFor(int weekday) {
    final focus =
        focusFor(weekday).where((g) => g != cardio && g != yoga).toList();
    return [...focus, cardio, yoga];
  }
}

/// Builds a week of sessions from [preferences] and the bundled exercise
/// library. Pure so it can be unit-tested without a database or widgets.
class WeekPlanGenerator {
  const WeekPlanGenerator._();

  static const _balancedCombos = <List<MuscleGroup>>[
    [2, 3, 1],
    [4, 5],
    [0, 5],
    [6, 5],
    [2, 0],
    [3, 4],
    [7],
  ];

  static const _splitCombos = <List<MuscleGroup>>[
    [2, 0],
    [3, 1],
    [4],
    [5],
    [6],
    [7],
    [4, 5],
  ];

  static const _fullBody = <MuscleGroup>[2, 3, 4, 5];
  static const _cardioFocus = <MuscleGroup>[6, 5];

  /// Generates one [PlannedDay] per calendar day of the week starting at
  /// [weekStart] (a Monday). Non-training days are returned as rest days so the
  /// planner can render the full Mon–Sun grid.
  static List<PlannedDay> generate({
    required WorkoutPreferences preferences,
    required List<Exercise> exercises,
    required DateTime weekStart,
    Map<int, int> substitutions = const {},
  }) {
    final days = <PlannedDay>[];
    var comboIndex = 0;
    for (var offset = 0; offset < 7; offset++) {
      final date = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day + offset,
      );
      final weekday = date.weekday;
      final trains =
          preferences.trainsOn(weekday) && !preferences.restsOn(weekday);
      if (!trains) {
        days.add(
          PlannedDay(
            date: date,
            title: '',
            muscleGroups: const [],
            items: const [],
            isRest: true,
          ),
        );
        continue;
      }
      final combo = _comboFor(preferences, comboIndex++);
      final items = _selectItems(
        preferences: preferences,
        exercises: exercises,
        groups: combo,
        substitutions: substitutions,
      );
      days.add(
        PlannedDay(date: date, title: '', muscleGroups: combo, items: items),
      );
    }
    return days;
  }

  /// Builds the WHO-informed daily session for [date]. Every day combines the
  /// strength focus for that weekday with a cardio block and a yoga cool-down.
  /// Returns `null` when the library has no usable exercises for the day.
  static PlannedDay? generateWhoDay({
    required DateTime date,
    required WorkoutPreferences preferences,
    required List<Exercise> exercises,
    Map<int, int> substitutions = const {},
  }) {
    final groups = WhoDailyPlan.groupsFor(date.weekday);
    final chosen = _selectExercises(
      preferences: preferences,
      exercises: exercises,
      groups: groups,
      perGroupOverride: 2,
    );
    if (chosen.isEmpty) return null;
    return PlannedDay(
      date: date,
      title: '',
      muscleGroups: groups,
      items: [
        for (final e in chosen)
          PlannedItem(
            exerciseId: _substituteFor(e.id, substitutions),
            sets: e.defaultSets,
            reps: e.defaultReps,
            durationSec: e.defaultDurationSec,
            restSec: e.restSec,
          ),
      ],
    );
  }

  static List<MuscleGroup> _comboFor(WorkoutPreferences prefs, int index) {
    switch (prefs.planStyle) {
      case WorkoutPlanStyle.fullBody:
        return _fullBody;
      case WorkoutPlanStyle.cardioFocus:
        return _cardioFocus;
      case WorkoutPlanStyle.muscleSplit:
        return _splitCombos[index % _splitCombos.length];
      case WorkoutPlanStyle.balanced:
        return _balancedCombos[index % _balancedCombos.length];
    }
  }

  /// Categories that are never stacked: a single aerobic block (cardio) and a
  /// single mobility block (yoga & mobility) per session are enough, so the
  /// per-group limit is capped at one for them.
  static const _singleBlockGroups = <MuscleGroup>[6, 7];

  static List<Exercise> _selectExercises({
    required WorkoutPreferences preferences,
    required List<Exercise> exercises,
    required List<MuscleGroup> groups,
    int? perGroupOverride,
    Set<String>? equipmentOverride,
  }) {
    final maxLevel = preferences.fitnessLevel.index + 1;
    final selected = equipmentOverride ?? _selectedEquipment(preferences);
    final perGroup =
        perGroupOverride ??
        ((preferences.sessionMinutes / 8).ceil()).clamp(1, 3);
    final chosen = <Exercise>[];
    final usedIds = <int>{};

    for (final group in groups) {
      final limit = _singleBlockGroups.contains(group) ? 1 : perGroup;
      final candidates =
          exercises
              .where(
                (e) =>
                    e.category == group &&
                    e.difficulty <= maxLevel &&
                    isEquipmentSelected(e.equipment, selected),
              )
              .toList()
            ..sort((a, b) => a.id.compareTo(b.id));

      var added = 0;
      for (final e in candidates) {
        if (added >= limit) break;
        if (usedIds.contains(e.id)) continue;
        usedIds.add(e.id);
        chosen.add(e);
        added++;
      }
    }
    return chosen;
  }

  /// The equipment the user has selected in Settings → Workout. Falls back to
  /// the default home selection when preferences hold none.
  static Set<String> _selectedEquipment(WorkoutPreferences preferences) {
    if (preferences.equipment.isEmpty) {
      return defaultEquipmentSelection().toSet();
    }
    return preferences.equipment.map((e) => e.trim().toLowerCase()).toSet();
  }

  /// The muscle-group categories the daily workout may draw from. When the user
  /// has selected none, every group in [groups] is allowed.
  static List<MuscleGroup> allowedGroups(
    WorkoutPreferences preferences,
    List<MuscleGroup> groups,
  ) {
    final selected = preferences.goalMuscles;
    if (selected.isEmpty) return groups;
    return groups.where(selected.contains).toList();
  }

  static List<PlannedItem> _selectItems({
    required WorkoutPreferences preferences,
    required List<Exercise> exercises,
    required List<MuscleGroup> groups,
    required Map<int, int> substitutions,
  }) {
    final chosen = _selectExercises(
      preferences: preferences,
      exercises: exercises,
      groups: groups,
    );
    return [
      for (final e in chosen)
        PlannedItem(
          exerciseId: _substituteFor(e.id, substitutions),
          sets: e.defaultSets,
          reps: e.defaultReps,
          durationSec: e.defaultDurationSec,
          restSec: e.restSec,
        ),
    ];
  }

  static int _substituteFor(int exerciseId, Map<int, int> substitutions) =>
      substitutions[exerciseId] ?? exerciseId;

  /// Generates today's home workout: a warm-up, a long main set targeting the
  /// day's muscle groups, and a cool-down. The main work is scaled to fill
  /// roughly [WorkoutPreferences.sessionMinutes] (the app targets a 60–90
  /// minute home session) by widening the per-group exercise count and raising
  /// the working sets. Returns null when the library has no usable exercises.
  static PlannedDay? generateHomeDay({
    required DateTime date,
    required WorkoutPreferences preferences,
    required List<Exercise> exercises,
    Map<int, int> substitutions = const {},
  }) {
    final allGroups = WhoDailyPlan.groupsFor(date.weekday);
    // Restrict the main work to the muscle groups the user enabled in
    // Settings → Workout. Mobility (cool-down) and cardio blocks are only
    // dropped when the user explicitly unchecked them.
    final groups = allowedGroups(preferences, allGroups);
    // Aim the main block at ~75 minutes of home work. The default preference
    // length drives the per-group breadth; sets are raised on top of it.
    final targetMinutes = preferences.sessionMinutes.clamp(45, 90);
    final perGroup = ((targetMinutes - 20) / 6).round().clamp(2, 4);
    final mainSets = targetMinutes >= 60 ? 4 : 3;

    final chosen = _selectExercises(
      preferences: preferences,
      exercises: exercises,
      groups: groups,
      perGroupOverride: perGroup,
    );
    if (chosen.isEmpty) return null;

    return PlannedDay(
      date: date,
      title: '',
      muscleGroups: groups,
      items: [
        for (final e in chosen)
          if (e.category == WhoDailyPlan.yoga)
            PlannedItem(
              exerciseId: _substituteFor(e.id, substitutions),
              sets: e.defaultSets,
              reps: e.defaultReps,
              durationSec: e.defaultDurationSec,
              restSec: e.restSec,
            )
          else
            PlannedItem(
              exerciseId: _substituteFor(e.id, substitutions),
              sets: mainSets,
              reps: e.defaultReps,
              durationSec: e.defaultDurationSec,
              restSec: e.restSec,
            ),
      ],
    );
  }

  /// Sums the estimated seconds across [items].
  static int estimateDurationSec(Iterable<PlannedItem> items) =>
      items.fold<int>(0, (sum, i) => sum + i.estimatedSec);

  /// Advisory checks over a generated week. Never blocks; only informs.
  static List<PlanWarning> validate({
    required List<PlannedDay> days,
    required WorkoutPreferences preferences,
  }) {
    final warnings = <PlanWarning>[];
    var consecutive = 0;
    Map<int, int>? previousCounts;

    for (final day in days) {
      if (day.isRest) {
        consecutive = 0;
        previousCounts = null;
        continue;
      }
      consecutive++;

      final ids = day.items.map((i) => i.exerciseId).toList();
      if (ids.length != ids.toSet().length) {
        warnings.add(
          const PlanWarning(
            PlanWarningKind.duplicateExercise,
            'duplicate_exercise',
          ),
        );
      }

      final counts = <int, int>{};
      for (final g in day.muscleGroups) {
        counts[g] = (counts[g] ?? 0) + 1;
      }
      if (previousCounts != null &&
          counts.keys.any((g) => previousCounts!.containsKey(g))) {
        warnings.add(
          const PlanWarning(
            PlanWarningKind.consecutiveSameMuscle,
            'consecutive_same_muscle',
          ),
        );
      }
      previousCounts = counts;

      if (consecutive >= 4) {
        warnings.add(
          const PlanWarning(
            PlanWarningKind.tooManyConsecutiveDays,
            'too_many_consecutive_days',
          ),
        );
      }

      final estimate = estimateDurationSec(day.items);
      if (estimate > preferences.sessionMinutes * 60 * 3 / 2) {
        warnings.add(
          const PlanWarning(PlanWarningKind.heavyVolume, 'heavy_volume'),
        );
      }
    }
    return warnings;
  }
}
