import '../../../core/db/database.dart';
import 'equipment_filter.dart';
import 'workout_queue.dart';

/// The part of a guided session a step belongs to.
///
/// Kept first so the default (index 1) is [main], matching queues built before
/// phases existed.
enum SessionPhase { warmUp, main, coolDown }

/// How a session ended, stored on the session row.
enum SessionOutcome { completed, partial, skipped, cancelled }

/// Self-reported readiness captured before a session. Values are 1–5.
class ReadinessReport {
  const ReadinessReport({
    this.energy = 3,
    this.soreness = 3,
    this.sleep = 3,
    this.note = '',
  });

  /// Perceived energy, 1 (exhausted) … 5 (fresh).
  final int energy;

  /// Muscle soreness, 1 (none) … 5 (very sore).
  final int soreness;

  /// Sleep quality last night, 1 (poor) … 5 (great).
  final int sleep;

  final String note;

  /// A single 1–5 readiness score. Soreness is inverted because high soreness
  /// lowers readiness.
  int get score => ((energy + sleep + (6 - soreness)) / 3).round().clamp(1, 5);

  /// Suggests easing off when readiness is low, per the gradual-progression
  /// guidance. Advisory only.
  bool get shouldReduceIntensity => score <= 2;
}

/// Assembles a full session (warm-up → main → cool-down) from the exercise
/// library and a plan's items. Pure, so the composition is unit-testable.
class SessionBuilder {
  const SessionBuilder._();

  /// Warm-up exercises. The warm-up is built around a fixed core so every
  /// session opens the same way: a push-up, bodyweight-only stretches, and a
  /// plank, then any remaining slots are filled from the bodyweight mobility
  /// pool. A non-zero [seed] offsets the filler so the warm-up and cool-down do
  /// not repeat the same movements.
  static List<Exercise> selectWarmUps(
    List<Exercise> all, {
    int count = 6,
    int seed = 0,
  }) {
    final home =
        all
            .where((e) => isHomeCompatible(e.equipment, WorkoutMode.bodyweight))
            .toList();

    // Ordered core: push-up, plank, then stretches. Placed first so the fixed
    // content survives the [count] clamp even on a tiny library.
    final core = <Exercise?>[
      _firstByName(home, _isPushUp),
      _firstByName(home, _isPlank),
      ..._stretches(home).take(2),
    ].whereType<Exercise>().toList();

    final chosen = <Exercise>[];
    final usedIds = <int>{};
    for (final e in core) {
      if (chosen.length >= count) break;
      if (usedIds.add(e.id)) chosen.add(e);
    }

    // Fill remaining slots with bodyweight mobility (category 7/8) and any
    // other bodyweight movement, never repeating a core pick.
    final filler =
        home
            .where(
              (e) =>
                  (e.category == 7 || e.category == 8) &&
                  !usedIds.contains(e.id),
            )
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    for (final e in _rotate(filler, count, seed)) {
      if (chosen.length >= count) break;
      if (usedIds.add(e.id)) chosen.add(e);
    }

    if (chosen.length < count) {
      final rest = home.where((e) => !usedIds.contains(e.id)).toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      for (final e in _rotate(rest, count, seed)) {
        if (chosen.length >= count) break;
        if (usedIds.add(e.id)) chosen.add(e);
      }
    }
    return chosen;
  }

  static bool _isPushUp(Exercise e) {
    final name = e.name.toLowerCase();
    return name.contains('push up') || name.contains('push-up') ||
        name.contains('pushup');
  }

  static bool _isPlank(Exercise e) => e.name.toLowerCase().contains('plank');

  static List<Exercise> _stretches(List<Exercise> home) =>
      home
          .where((e) => e.category == 8)
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));

  static Exercise? _firstByName(
    List<Exercise> pool,
    bool Function(Exercise) test,
  ) {
    final matches = pool.where(test).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return matches.isEmpty ? null : matches.first;
  }

  /// Cool-down exercises, preferring mobility work then stretches.
  static List<Exercise> selectCoolDowns(
    List<Exercise> all, {
    int count = 3,
    int seed = 0,
  }) {
    final mobility =
        all
            .where(
              (e) =>
                  e.category == 7 &&
                  isHomeCompatible(e.equipment, WorkoutMode.bodyweight),
            )
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    final stretches =
        all
            .where(
              (e) =>
                  e.category == 8 &&
                  isHomeCompatible(e.equipment, WorkoutMode.bodyweight),
            )
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    return _rotate([...mobility, ...stretches], count, seed);
  }

  /// Builds the complete step list: warm-up sets, the main work, then cool-down.
  static List<WorkoutStep> buildSession({
    required List<Exercise> allExercises,
    required List<WorkoutPlanItem> items,
    int warmUpCount = 6,
    int coolDownCount = 3,
    int seed = 0,
  }) {
    final warmUps = selectWarmUps(allExercises, count: warmUpCount, seed: seed);
    final coolDowns = selectCoolDowns(
      allExercises,
      count: coolDownCount,
      seed: seed,
    );
    return compose(
      warmUp: WorkoutQueue.buildFromExercises(
        warmUps,
        phase: SessionPhase.warmUp,
      ),
      main: WorkoutQueue.build(items: items, exercises: allExercises),
      coolDown: WorkoutQueue.buildFromExercises(
        coolDowns,
        phase: SessionPhase.coolDown,
      ),
    );
  }

  /// Concatenates the three phases into one flat step list.
  static List<WorkoutStep> compose({
    required List<WorkoutStep> warmUp,
    required List<WorkoutStep> main,
    required List<WorkoutStep> coolDown,
  }) => [...warmUp, ...main, ...coolDown];

  /// The work steps belonging to a single [phase].
  static List<WorkoutStep> workStepsIn(
    List<WorkoutStep> steps,
    SessionPhase phase,
  ) => steps.where((s) => s.isWork && s.phase == phase).toList();

  static List<Exercise> _rotate(List<Exercise> pool, int count, int seed) {
    if (pool.isEmpty || count <= 0) return const [];
    final take = count.clamp(1, pool.length);
    final start = pool.isEmpty ? 0 : seed % pool.length;
    final out = <Exercise>[];
    for (var i = 0; i < take; i++) {
      out.add(pool[(start + i) % pool.length]);
    }
    return out;
  }
}
