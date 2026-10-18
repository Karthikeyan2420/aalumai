import 'dart:convert';

import '../../../core/db/database.dart';
import 'session_flow.dart';

/// The kind of step in a guided workout.
enum WorkoutStepKind { work, rest }

/// A single step of a guided workout: either a work set for an exercise or a
/// rest interval. Built only from plan items + the exercise library so the
/// queue logic stays pure and unit-testable.
class WorkoutStep {
  const WorkoutStep({
    required this.kind,
    required this.exerciseId,
    required this.exerciseName,
    required this.setIndex,
    required this.totalSets,
    this.category = 0,
    this.reps = 0,
    this.durationSec = 0,
    this.isTimed = false,
    this.phase = SessionPhase.main,
  });

  final WorkoutStepKind kind;
  final int exerciseId;
  final String exerciseName;

  /// Exercise category index, used to pick the illustration.
  final int category;

  /// 0-based index of the set within its exercise.
  final int setIndex;
  final int totalSets;
  final int reps;
  final int durationSec;
  final bool isTimed;

  /// Which part of the session this step belongs to.
  final SessionPhase phase;

  bool get isWork => kind == WorkoutStepKind.work;
  bool get isRest => kind == WorkoutStepKind.rest;

  /// A timed work step counts down [durationSec]; a rest step counts down too.
  bool get isTimedCountdown => durationSec > 0 && (isRest || isTimed);

  /// Returns a copy of this step tagged with [phase].
  WorkoutStep withPhase(SessionPhase phase) => WorkoutStep(
    kind: kind,
    exerciseId: exerciseId,
    exerciseName: exerciseName,
    setIndex: setIndex,
    totalSets: totalSets,
    category: category,
    reps: reps,
    durationSec: durationSec,
    isTimed: isTimed,
    phase: phase,
  );
}

/// Builds a flat list of [WorkoutStep]s from a plan's items. A rest step is
/// inserted after every work set except the final work set of the workout,
/// using the resting exercise's `restSec`.
class WorkoutQueue {
  static List<WorkoutStep> build({
    required List<WorkoutPlanItem> items,
    required List<Exercise> exercises,
    SessionPhase phase = SessionPhase.main,
  }) {
    final byId = {for (final e in exercises) e.id: e};
    final ordered = [...items]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    final specs = <_WorkoutSpec>[
      for (final item in ordered)
        if (byId[item.exerciseId] case final exercise?)
          _WorkoutSpec(
            exercise: exercise,
            sets: item.sets,
            reps: item.reps,
            durationSec: item.durationSec,
          ),
    ];
    return _assemble(specs, phase);
  }

  /// Builds a queue straight from chosen exercises using each exercise's own
  /// default sets/reps/duration. Used by the ad-hoc "quick workout" flow and
  /// for the warm-up / cool-down phases.
  static List<WorkoutStep> buildFromExercises(
    List<Exercise> exercises, {
    SessionPhase phase = SessionPhase.main,
  }) {
    return _assemble([
      for (final e in exercises)
        _WorkoutSpec(
          exercise: e,
          sets: e.defaultSets,
          reps: e.defaultReps,
          durationSec: e.defaultDurationSec,
        ),
    ], phase);
  }

  static List<WorkoutStep> _assemble(
    List<_WorkoutSpec> specs,
    SessionPhase phase,
  ) {
    final workSteps = <WorkoutStep>[];
    final rests = <int>[]; // rest duration to insert after each work step
    for (final spec in specs) {
      final sets = spec.sets <= 0 ? 1 : spec.sets;
      for (var s = 0; s < sets; s++) {
        workSteps.add(
          WorkoutStep(
            kind: WorkoutStepKind.work,
            exerciseId: spec.exercise.id,
            exerciseName: spec.exercise.name,
            category: spec.exercise.category,
            setIndex: s,
            totalSets: sets,
            reps: spec.reps,
            durationSec: spec.durationSec,
            isTimed: spec.exercise.isTimed,
            phase: phase,
          ),
        );
        rests.add(spec.exercise.restSec);
      }
    }

    final steps = <WorkoutStep>[];
    for (var i = 0; i < workSteps.length; i++) {
      steps.add(workSteps[i]);
      final isLast = i == workSteps.length - 1;
      if (!isLast && rests[i] > 0) {
        steps.add(
          WorkoutStep(
            kind: WorkoutStepKind.rest,
            exerciseId: workSteps[i].exerciseId,
            exerciseName: workSteps[i].exerciseName,
            category: workSteps[i].category,
            setIndex: workSteps[i].setIndex,
            totalSets: workSteps[i].totalSets,
            durationSec: rests[i],
            phase: phase,
          ),
        );
      }
    }
    return steps;
  }

  /// Total number of work (non-rest) steps.
  static int workStepCount(List<WorkoutStep> steps) =>
      steps.where((s) => s.isWork).length;

  /// Serialises a built queue so an interrupted workout can be restored exactly
  /// even if its source plan is later edited.
  static String encodeSteps(List<WorkoutStep> steps) => jsonEncode([
    for (final s in steps)
      {
        'k': s.kind.index,
        'e': s.exerciseId,
        'n': s.exerciseName,
        'c': s.category,
        'i': s.setIndex,
        't': s.totalSets,
        'r': s.reps,
        'd': s.durationSec,
        'x': s.isTimed,
        'p': s.phase.index,
      },
  ]);

  /// Inverse of [encodeSteps]. Returns an empty list for blank/invalid input.
  static List<WorkoutStep> decodeSteps(String json) {
    if (json.trim().isEmpty) return const [];
    try {
      final raw = jsonDecode(json) as List<dynamic>;
      return [
        for (final e in raw.cast<Map<String, dynamic>>())
          WorkoutStep(
            kind: WorkoutStepKind.values[(e['k'] as int).clamp(0, 1)],
            exerciseId: e['e'] as int,
            exerciseName: (e['n'] as String?) ?? '',
            category: (e['c'] as int?) ?? 0,
            setIndex: (e['i'] as int?) ?? 0,
            totalSets: (e['t'] as int?) ?? 1,
            reps: (e['r'] as int?) ?? 0,
            durationSec: (e['d'] as int?) ?? 0,
            isTimed: (e['x'] as bool?) ?? false,
            phase:
                SessionPhase.values[(e['p'] as int? ?? 1).clamp(
                  0,
                  SessionPhase.values.length - 1,
                )],
          ),
      ];
    } catch (_) {
      return const [];
    }
  }
}

/// Internal helper describing one exercise's contribution to a queue.
class _WorkoutSpec {
  const _WorkoutSpec({
    required this.exercise,
    required this.sets,
    required this.reps,
    required this.durationSec,
  });

  final Exercise exercise;
  final int sets;
  final int reps;
  final int durationSec;
}
