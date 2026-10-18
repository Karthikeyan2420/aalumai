import '../../../core/db/database.dart';
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

  /// Warm-up exercises, chosen from the warm-up/cool-down category.
  static List<Exercise> selectWarmUps(
    List<Exercise> all, {
    int count = 3,
    int seed = 0,
  }) {
    final pool =
        all.where((e) => e.category == 8).toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    return _rotate(pool, count, seed);
  }

  /// Cool-down exercises, preferring mobility work then stretches.
  static List<Exercise> selectCoolDowns(
    List<Exercise> all, {
    int count = 2,
    int seed = 0,
  }) {
    final mobility =
        all.where((e) => e.category == 7).toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    final stretches =
        all.where((e) => e.category == 8).toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    return _rotate([...mobility, ...stretches], count, seed);
  }

  /// Builds the complete step list: warm-up sets, the main work, then cool-down.
  static List<WorkoutStep> buildSession({
    required List<Exercise> allExercises,
    required List<WorkoutPlanItem> items,
    int warmUpCount = 3,
    int coolDownCount = 2,
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
