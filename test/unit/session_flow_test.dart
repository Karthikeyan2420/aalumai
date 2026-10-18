import 'package:aalumai/features/fitness/domain/session_flow.dart';
import 'package:aalumai/features/fitness/domain/workout_queue.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fitness_fixtures.dart';

void main() {
  group('ReadinessReport', () {
    test('a fresh, pain-free day scores high', () {
      const report = ReadinessReport(energy: 5, soreness: 1, sleep: 5);
      expect(report.score, 5);
      expect(report.shouldReduceIntensity, isFalse);
    });

    test('a tired, sore day scores low and suggests easing off', () {
      const report = ReadinessReport(energy: 1, soreness: 5, sleep: 1);
      expect(report.score, 1);
      expect(report.shouldReduceIntensity, isTrue);
    });

    test('score stays within 1..5', () {
      const report = ReadinessReport(energy: 3, soreness: 3, sleep: 3);
      expect(report.score, inInclusiveRange(1, 5));
    });
  });

  group('SessionBuilder selection', () {
    final library = [
      testExercise(id: 1, name: 'March', category: 8, isTimed: true),
      testExercise(id: 2, name: 'Arm circles', category: 8, isTimed: true),
      testExercise(id: 3, name: 'Cat-cow', category: 8),
      testExercise(id: 4, name: 'Downward dog', category: 7, isTimed: true),
      testExercise(id: 5, name: 'Squat', category: 4),
    ];

    test('selectWarmUps draws only from the warm-up category', () {
      final warmUps = SessionBuilder.selectWarmUps(library, count: 3);
      expect(warmUps, isNotEmpty);
      expect(warmUps.every((e) => e.category == 8), isTrue);
    });

    test('selectWarmUps never exceeds the available pool', () {
      final warmUps = SessionBuilder.selectWarmUps(library, count: 99);
      expect(warmUps, hasLength(3));
    });

    test('selectCoolDowns prefers mobility then stretches', () {
      final coolDowns = SessionBuilder.selectCoolDowns(library, count: 2);
      expect(coolDowns, isNotEmpty);
      expect(coolDowns.first.category, 7);
    });

    test('a seed rotates the selection deterministically', () {
      final a = SessionBuilder.selectWarmUps(library, count: 1, seed: 0);
      final b = SessionBuilder.selectWarmUps(library, count: 1, seed: 1);
      expect(a.first.id, isNot(b.first.id));
    });
  });

  group('SessionBuilder.buildSession', () {
    final library = [
      testExercise(
        id: 1,
        name: 'March',
        category: 8,
        isTimed: true,
        defaultSets: 1,
        defaultDurationSec: 30,
        restSec: 0,
      ),
      testExercise(
        id: 2,
        name: 'Squat',
        category: 4,
        defaultSets: 2,
        defaultReps: 12,
        restSec: 30,
      ),
      testExercise(
        id: 3,
        name: 'Plank',
        category: 5,
        isTimed: true,
        defaultSets: 2,
        defaultDurationSec: 20,
        restSec: 30,
      ),
    ];

    test('orders warm-up, main then cool-down phases', () {
      final steps = SessionBuilder.buildSession(
        allExercises: library,
        items: [testPlanItem(exerciseId: 2, sets: 2, reps: 12)],
        warmUpCount: 1,
        coolDownCount: 1,
      );
      final phases = steps.map((s) => s.phase).toList();
      // warm-up steps come first, cool-down steps last.
      expect(phases.first, SessionPhase.warmUp);
      expect(phases.last, SessionPhase.coolDown);
      expect(phases.contains(SessionPhase.main), isTrue);
    });

    test('workStepsIn returns only the requested phase', () {
      final steps = SessionBuilder.buildSession(
        allExercises: library,
        items: [testPlanItem(exerciseId: 2, sets: 2, reps: 12)],
        warmUpCount: 1,
        coolDownCount: 1,
      );
      final main = SessionBuilder.workStepsIn(steps, SessionPhase.main);
      expect(main.every((s) => s.phase == SessionPhase.main), isTrue);
      expect(main, hasLength(2));
    });

    test('compose concatenates phases in order', () {
      final warm = WorkoutQueue.buildFromExercises([
        testExercise(id: 1, category: 8),
      ], phase: SessionPhase.warmUp);
      final main = WorkoutQueue.buildFromExercises([
        testExercise(id: 2, category: 4),
      ]);
      final cool = WorkoutQueue.buildFromExercises([
        testExercise(id: 3, category: 7),
      ], phase: SessionPhase.coolDown);
      final all = SessionBuilder.compose(
        warmUp: warm,
        main: main,
        coolDown: cool,
      );
      expect(all.first.phase, SessionPhase.warmUp);
      expect(all.last.phase, SessionPhase.coolDown);
    });
  });
}
