import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/features/fitness/domain/workout_queue.dart';
import 'package:flutter_test/flutter_test.dart';

Exercise _exercise({
  int id = 1,
  String name = 'Push-up',
  int category = 0,
  bool isTimed = false,
  int restSec = 60,
  int defaultSets = 3,
  int defaultReps = 10,
  int defaultDurationSec = 0,
}) => Exercise(
  id: id,
  name: name,
  category: category,
  exerciseType: 0,
  targetMuscles: '',
  equipment: '',
  difficulty: 0,
  instructions: '',
  safetyNotes: '',
  formTips: '',
  commonMistakes: '',
  contraindications: '',
  easierAltId: null,
  harderAltId: null,
  demoAsset: '',
  nameKey: '',
  instructionsKey: '',
  safetyNotesKey: '',
  isCustom: false,
  isTimed: isTimed,
  defaultSets: defaultSets,
  defaultReps: defaultReps,
  defaultDurationSec: defaultDurationSec,
  restSec: restSec,
  mediaPath: '',
  sourceId: '',
  slug: '',
  bodyPart: '',
  secondaryMuscles: '',
  sourceCategory: '',
  gifUrl: '',
);

WorkoutPlanItem _item({
  int id = 1,
  int exerciseId = 1,
  int orderIndex = 0,
  int sets = 3,
  int reps = 10,
  int durationSec = 0,
}) => WorkoutPlanItem(
  id: id,
  planId: 1,
  exerciseId: exerciseId,
  orderIndex: orderIndex,
  sets: sets,
  reps: reps,
  durationSec: durationSec,
);

void main() {
  group('WorkoutQueue.build', () {
    test('produces one work step per set and rest between sets', () {
      final steps = WorkoutQueue.build(
        items: [_item(sets: 3)],
        exercises: [_exercise(restSec: 60)],
      );
      // 3 work + 2 rest (no rest after the final set).
      expect(steps, hasLength(5));
      expect(steps.where((s) => s.isWork), hasLength(3));
      expect(steps.where((s) => s.isRest), hasLength(2));
      expect(steps.first.isWork, isTrue);
      expect(steps.last.isWork, isTrue);
    });

    test('carries the exercise name and set progress', () {
      final steps = WorkoutQueue.build(
        items: [_item(sets: 2, reps: 12)],
        exercises: [_exercise(name: 'Squat')],
      );
      final work = steps.where((s) => s.isWork).toList();
      expect(work.first.exerciseName, 'Squat');
      expect(work.first.reps, 12);
      expect(work.first.setIndex, 0);
      expect(work.last.setIndex, 1);
      expect(work.first.totalSets, 2);
    });

    test('marks timed exercises as countdown steps', () {
      final steps = WorkoutQueue.build(
        items: [_item(sets: 1, durationSec: 30)],
        exercises: [_exercise(isTimed: true)],
      );
      final work = steps.single;
      expect(work.isTimed, isTrue);
      expect(work.durationSec, 30);
      expect(work.isTimedCountdown, isTrue);
    });

    test('skips rests when the exercise defines none', () {
      final steps = WorkoutQueue.build(
        items: [_item(sets: 3)],
        exercises: [_exercise(restSec: 0)],
      );
      expect(steps, hasLength(3));
      expect(steps.every((s) => s.isWork), isTrue);
    });

    test('orders multiple items by orderIndex', () {
      final steps = WorkoutQueue.build(
        items: [
          _item(id: 2, exerciseId: 2, orderIndex: 1, sets: 1),
          _item(id: 1, exerciseId: 1, orderIndex: 0, sets: 1),
        ],
        exercises: [
          _exercise(id: 1, name: 'First', restSec: 0),
          _exercise(id: 2, name: 'Second', restSec: 0),
        ],
      );
      expect(steps.first.exerciseName, 'First');
      expect(steps.last.exerciseName, 'Second');
    });

    test('treats a non-positive set count as a single set', () {
      final steps = WorkoutQueue.build(
        items: [_item(sets: 0)],
        exercises: [_exercise(restSec: 0)],
      );
      expect(steps, hasLength(1));
    });

    test('workStepCount counts only work steps', () {
      final steps = WorkoutQueue.build(
        items: [_item(sets: 3)],
        exercises: [_exercise(restSec: 30)],
      );
      expect(WorkoutQueue.workStepCount(steps), 3);
    });

    test('propagates the exercise category onto its steps', () {
      final steps = WorkoutQueue.build(
        items: [_item(sets: 2)],
        exercises: [_exercise(category: 5, restSec: 30)],
      );
      expect(steps.every((s) => s.category == 5), isTrue);
    });
  });

  group('WorkoutQueue.buildFromExercises', () {
    test('uses each exercise default sets and prescription', () {
      final steps = WorkoutQueue.buildFromExercises([
        _exercise(
          id: 1,
          name: 'Plank',
          isTimed: true,
          defaultSets: 3,
          defaultDurationSec: 30,
          restSec: 20,
        ),
        _exercise(
          id: 2,
          name: 'Squat',
          defaultSets: 2,
          defaultReps: 12,
          restSec: 0,
        ),
      ]);
      // Plank: 3 work with a rest after each; Squat: 2 work, no rest, and the
      // final set of the workout never gets a trailing rest.
      expect(steps.where((s) => s.isWork), hasLength(5));
      expect(steps.where((s) => s.isRest), hasLength(3));
      final plank = steps.first;
      expect(plank.exerciseName, 'Plank');
      expect(plank.isTimed, isTrue);
      expect(plank.durationSec, 30);
    });

    test('returns an empty queue for no exercises', () {
      expect(WorkoutQueue.buildFromExercises(const []), isEmpty);
    });
  });

  group('WorkoutQueue step serialisation', () {
    test('round-trips a built queue through encode/decode', () {
      final original = WorkoutQueue.build(
        items: [_item(sets: 2, reps: 8)],
        exercises: [_exercise(name: 'Row', category: 3, restSec: 45)],
      );
      final restored = WorkoutQueue.decodeSteps(
        WorkoutQueue.encodeSteps(original),
      );
      expect(restored, hasLength(original.length));
      for (var i = 0; i < original.length; i++) {
        expect(restored[i].kind, original[i].kind);
        expect(restored[i].exerciseId, original[i].exerciseId);
        expect(restored[i].exerciseName, original[i].exerciseName);
        expect(restored[i].category, original[i].category);
        expect(restored[i].setIndex, original[i].setIndex);
        expect(restored[i].totalSets, original[i].totalSets);
        expect(restored[i].reps, original[i].reps);
        expect(restored[i].durationSec, original[i].durationSec);
        expect(restored[i].isTimed, original[i].isTimed);
      }
    });

    test('decodes blank or malformed payloads to an empty list', () {
      expect(WorkoutQueue.decodeSteps(''), isEmpty);
      expect(WorkoutQueue.decodeSteps('  '), isEmpty);
      expect(WorkoutQueue.decodeSteps('not json'), isEmpty);
    });
  });
}
