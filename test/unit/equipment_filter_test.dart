import 'package:aalumai/core/db/database.dart' show Exercise;
import 'package:aalumai/features/fitness/domain/equipment_filter.dart';
import 'package:aalumai/features/fitness/domain/exercise_collections.dart';
import 'package:aalumai/features/fitness/domain/session_flow.dart';
import 'package:aalumai/features/fitness/domain/workout_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fitness_fixtures.dart';

void main() {
  group('isHomeCompatible', () {
    test('bodyweight is always allowed', () {
      expect(isHomeCompatible('bodyweight', WorkoutMode.bodyweight), isTrue);
      expect(isHomeCompatible('bodyweight', WorkoutMode.dumbbell), isTrue);
    });

    test('empty and none equipment are always allowed', () {
      expect(isHomeCompatible('', WorkoutMode.bodyweight), isTrue);
      expect(isHomeCompatible('none', WorkoutMode.bodyweight), isTrue);
    });

    test('dumbbell is only allowed in dumbbell mode', () {
      expect(isHomeCompatible('dumbbell', WorkoutMode.bodyweight), isFalse);
      expect(isHomeCompatible('dumbbell', WorkoutMode.dumbbell), isTrue);
    });

    test('barbell and ez-bar are home weights, not gym-only', () {
      expect(isHomeCompatible('barbell', WorkoutMode.bodyweight), isFalse);
      expect(isHomeCompatible('barbell', WorkoutMode.dumbbell), isTrue);
      expect(isHomeCompatible('ez-bar', WorkoutMode.bodyweight), isFalse);
      expect(isHomeCompatible('ez-bar', WorkoutMode.dumbbell), isTrue);
    });

    test('gym equipment is never allowed', () {
      for (final equipment in [
        'cable',
        'machine',
        'lever',
        'smith',
        'kettlebell',
        'sled',
        'band',
        'other',
      ]) {
        expect(
          isHomeCompatible(equipment, WorkoutMode.bodyweight),
          isFalse,
          reason: '$equipment must be excluded in bodyweight mode',
        );
        expect(
          isHomeCompatible(equipment, WorkoutMode.dumbbell),
          isFalse,
          reason: '$equipment must be excluded in dumbbell mode',
        );
      }
    });
  });

  group('isGymEquipment', () {
    test('identifies all gym equipment values', () {
      for (final equipment in kGymEquipment) {
        expect(isGymEquipment(equipment), isTrue, reason: equipment);
      }
    });

    test('home equipment is not gym equipment', () {
      for (final equipment in [
        'bodyweight',
        'dumbbell',
        'barbell',
        'ez-bar',
        'band',
        'kettlebell',
        '',
      ]) {
        expect(isGymEquipment(equipment), isFalse, reason: equipment);
      }
    });
  });

  group('isEquipmentSelected', () {
    test('bodyweight is gated on the No-equipment toggle', () {
      expect(isEquipmentSelected('bodyweight', {'bodyweight'}), isTrue);
      expect(isEquipmentSelected('bodyweight', {'dumbbell'}), isFalse);
      expect(isEquipmentSelected('', {'bodyweight'}), isTrue);
    });

    test('weights require their own key to be selected', () {
      expect(isEquipmentSelected('dumbbell', {'bodyweight', 'dumbbell'}), isTrue);
      expect(isEquipmentSelected('barbell', {'bodyweight', 'dumbbell'}), isFalse);
      expect(
        isEquipmentSelected('band', {'bodyweight', 'band'}),
        isTrue,
      );
      expect(
        isEquipmentSelected('kettlebell', {'bodyweight', 'kettlebell'}),
        isTrue,
      );
    });
  });

  group('filterHomeExercises', () {
    test('bodyweight mode excludes dumbbell and gym exercises', () {
      final exercises = <Exercise>[
        testExercise(id: 1, name: 'Push-up', equipment: 'bodyweight'),
        testExercise(id: 2, name: 'Curl', equipment: 'dumbbell'),
        testExercise(id: 3, name: 'Bench Press', equipment: 'barbell'),
        testExercise(id: 4, name: 'Cable Fly', equipment: 'cable'),
        testExercise(id: 5, name: 'Plank', equipment: ''),
      ];
      final result = filterHomeExercises(exercises, WorkoutMode.bodyweight);
      expect(result.map((e) => e.id), [1, 5]);
    });

    test('dumbbell mode includes bodyweight, dumbbell and barbell exercises', () {
      final exercises = <Exercise>[
        testExercise(id: 1, name: 'Push-up', equipment: 'bodyweight'),
        testExercise(id: 2, name: 'Curl', equipment: 'dumbbell'),
        testExercise(id: 3, name: 'Bench Press', equipment: 'barbell'),
        testExercise(id: 4, name: 'Cable Fly', equipment: 'cable'),
      ];
      final result = filterHomeExercises(exercises, WorkoutMode.dumbbell);
      expect(result.map((e) => e.id), [1, 2, 3]);
    });
  });

  group('workoutModeFromEquipment', () {
    test('detects dumbbell in the list', () {
      expect(
        workoutModeFromEquipment(['bodyweight', 'dumbbell']),
        WorkoutMode.dumbbell,
      );
      expect(workoutModeFromEquipment(['bodyweight']), WorkoutMode.bodyweight);
      expect(workoutModeFromEquipment([]), WorkoutMode.bodyweight);
      expect(
        workoutModeFromEquipment(['Two dumbbells']),
        WorkoutMode.dumbbell,
      );
    });
  });

  group('equipmentForMode', () {
    test('bodyweight mode uses only bodyweight', () {
      expect(equipmentForMode(WorkoutMode.bodyweight), ['bodyweight']);
    });
    test('dumbbell mode includes both weights', () {
      expect(equipmentForMode(WorkoutMode.dumbbell), [
        'bodyweight',
        'dumbbell',
        'barbell',
      ]);
    });
  });

  group('homeCollections', () {
    test('excludes gym machines but keeps home collections', () {
      final collections = homeCollections();
      expect(collections, isNot(contains(WorkoutCollection.gym)));
      expect(collections, contains(WorkoutCollection.bodyweight));
      expect(collections, contains(WorkoutCollection.dumbbell));
      expect(collections, contains(WorkoutCollection.stretching));
      expect(collections, contains(WorkoutCollection.band));
    });
  });

  group('WeekPlanGenerator equipment filtering', () {
    test('defaults to home weights and never selects gym machines', () {
      final exercises = <Exercise>[
        testExercise(id: 1, name: 'Push-up', category: 2),
        testExercise(id: 2, name: 'Floor Press', category: 2, equipment: 'barbell'),
        testExercise(id: 3, name: 'Cable Fly', category: 2, equipment: 'cable'),
        testExercise(id: 4, name: 'Dumbbell Press', category: 2, equipment: 'dumbbell'),
      ];
      final prefs = WorkoutPreferences(
        fitnessLevel: FitnessLevel.advanced,
        planStyle: WorkoutPlanStyle.fullBody,
      );
      final days = WeekPlanGenerator.generate(
        preferences: prefs,
        exercises: exercises,
        weekStart: DateTime(2026, 1, 5),
      );
      final usedIds = [for (final d in days) for (final i in d.items) i.exerciseId];
      expect(usedIds, contains(2), reason: 'barbell is home weights by default');
      expect(usedIds, isNot(contains(3)), reason: 'cable must be excluded');
    });

    test('dumbbell mode includes dumbbell and barbell exercises', () {
      final exercises = <Exercise>[
        testExercise(id: 1, name: 'Push-up', category: 2),
        testExercise(id: 4, name: 'Dumbbell Press', category: 2, equipment: 'dumbbell'),
        testExercise(id: 5, name: 'Barbell Row', category: 3, equipment: 'barbell'),
      ];
      final prefs = WorkoutPreferences(
        fitnessLevel: FitnessLevel.advanced,
        planStyle: WorkoutPlanStyle.fullBody,
        equipment: ['bodyweight', 'dumbbell', 'barbell'],
      );
      final days = WeekPlanGenerator.generate(
        preferences: prefs,
        exercises: exercises,
        weekStart: DateTime(2026, 1, 5),
      );
      final usedIds = [for (final d in days) for (final i in d.items) i.exerciseId];
      expect(usedIds, contains(4), reason: 'dumbbell must be included');
      expect(usedIds, contains(5), reason: 'barbell must be included');
    });
  });

  group('SessionBuilder gym filtering', () {
    test('warm-ups exclude non-home equipment', () {
      final exercises = <Exercise>[
        testExercise(id: 1, name: 'Arm Circles', category: 7),
        testExercise(id: 2, name: 'Band Pull-Apart', category: 7, equipment: 'band'),
        testExercise(id: 3, name: 'Cable Pull', category: 7, equipment: 'cable'),
      ];
      final warmUps = SessionBuilder.selectWarmUps(exercises, count: 3);
      expect(warmUps.map((e) => e.id), isNot(contains(2)));
      expect(warmUps.map((e) => e.id), isNot(contains(3)));
    });

    test('cool-downs exclude non-home equipment', () {
      final exercises = <Exercise>[
        testExercise(id: 1, name: 'Chest Stretch', category: 8),
        testExercise(id: 2, name: 'Band Stretch', category: 8, equipment: 'band'),
      ];
      final coolDowns = SessionBuilder.selectCoolDowns(exercises, count: 2);
      expect(coolDowns.map((e) => e.id), isNot(contains(2)));
    });
  });

  group('warm-up contents', () {
    List<Exercise> library() => <Exercise>[
      testExercise(id: 1, name: 'Push Up', category: 2),
      testExercise(id: 2, name: 'Front Plank With Twist', category: 5),
      testExercise(id: 3, name: 'Calf Stretch', category: 8),
      testExercise(id: 4, name: 'Chest Stretch', category: 8),
      testExercise(id: 5, name: 'Arm Circles', category: 7),
      testExercise(id: 6, name: 'Band Pull-Apart', category: 7, equipment: 'band'),
    ];

    test('always opens with a push-up, a plank and stretches', () {
      final warmUps = SessionBuilder.selectWarmUps(library(), count: 6);
      final names = warmUps.map((e) => e.name.toLowerCase()).toList();
      expect(names.any((n) => n.contains('push')), isTrue);
      expect(names.any((n) => n.contains('plank')), isTrue);
      expect(warmUps.where((e) => e.category == 8).length, greaterThanOrEqualTo(2));
    });

    test('never picks non-home equipment into the warm-up', () {
      final warmUps = SessionBuilder.selectWarmUps(library(), count: 6);
      expect(warmUps.map((e) => e.id), isNot(contains(6)));
    });

    test('respects the requested count', () {
      final warmUps = SessionBuilder.selectWarmUps(library(), count: 3);
      expect(warmUps, hasLength(3));
    });
  });

  group('home day volume', () {
    List<Exercise> library() => <Exercise>[
      for (var id = 1; id <= 6; id++)
        testExercise(id: id, name: 'Chest $id', category: 2),
      for (var id = 20; id <= 25; id++)
        testExercise(id: id, name: 'Biceps $id', category: 0),
      testExercise(id: 40, name: 'Jacks', category: 6, isTimed: true),
      testExercise(id: 50, name: 'Stretch', category: 7),
    ];

    test('fills a long main block for a 75-minute target', () {
      final day = WeekPlanGenerator.generateHomeDay(
        date: DateTime(2026, 1, 5), // Monday: chest + biceps
        preferences: const WorkoutPreferences(
          fitnessLevel: FitnessLevel.advanced,
          sessionMinutes: 75,
          equipment: ['bodyweight', 'dumbbell', 'barbell'],
        ),
        exercises: library(),
      );
      expect(day, isNotNull);
      final minutes = WeekPlanGenerator.estimateDurationSec(day!.items) / 60;
      expect(minutes, greaterThanOrEqualTo(45));
      expect(minutes, lessThanOrEqualTo(95));
    });

    test('raises working sets to four for a 75-minute target', () {
      final day = WeekPlanGenerator.generateHomeDay(
        date: DateTime(2026, 1, 5),
        preferences: const WorkoutPreferences(
          fitnessLevel: FitnessLevel.advanced,
          sessionMinutes: 75,
        ),
        exercises: library(),
      );
      expect(day, isNotNull);
      expect(day!.items.any((i) => i.sets >= 4), isTrue);
    });
  });

  group('daily workout honours the Settings selection', () {
    List<Exercise> library() => <Exercise>[
      testExercise(id: 1, name: 'Push-up', category: 2), // chest, bodyweight
      testExercise(
        id: 2,
        name: 'Dumbbell Bench',
        category: 2,
        equipment: 'dumbbell',
      ),
      testExercise(
        id: 3,
        name: 'Band Chest Press',
        category: 2,
        equipment: 'band',
      ),
      testExercise(id: 10, name: 'Crunch', category: 5), // core
      testExercise(id: 40, name: 'Jacks', category: 6, isTimed: true),
      testExercise(id: 50, name: 'Stretch', category: 7),
    ];

    test('equipment selection limits the exercises picked', () {
      final day = WeekPlanGenerator.generateHomeDay(
        date: DateTime(2026, 1, 5), // Monday: chest + biceps
        preferences: const WorkoutPreferences(
          fitnessLevel: FitnessLevel.advanced,
          sessionMinutes: 75,
          equipment: ['bodyweight'], // dumbbell and band excluded
        ),
        exercises: library(),
      );
      expect(day, isNotNull);
      final ids = day!.items.map((i) => i.exerciseId).toSet();
      expect(ids, contains(1));
      expect(ids, isNot(contains(2)), reason: 'dumbbell not selected');
      expect(ids, isNot(contains(3)), reason: 'band not selected');
    });

    test('selecting a band includes its exercises', () {
      final day = WeekPlanGenerator.generateHomeDay(
        date: DateTime(2026, 1, 5),
        preferences: const WorkoutPreferences(
          fitnessLevel: FitnessLevel.advanced,
          sessionMinutes: 75,
          equipment: ['bodyweight', 'band'],
        ),
        exercises: library(),
      );
      expect(day, isNotNull);
      expect(day!.items.map((i) => i.exerciseId), contains(3));
    });

    test('muscle-group selection limits the groups built', () {
      final day = WeekPlanGenerator.generateHomeDay(
        date: DateTime(2026, 1, 5),
        preferences: const WorkoutPreferences(
          fitnessLevel: FitnessLevel.advanced,
          sessionMinutes: 75,
          equipment: ['bodyweight'],
          goalMuscles: [2], // chest only
        ),
        exercises: library(),
      );
      expect(day, isNotNull);
      // Only chest exercises: no core block, no cardio block.
      expect(day!.muscleGroups, [2]);
      final ids = day.items.map((i) => i.exerciseId).toSet();
      expect(ids, contains(1));
      expect(ids, isNot(contains(10)), reason: 'core not enabled');
      expect(ids, isNot(contains(40)), reason: 'cardio not enabled');
    });

    test('allowedGroups returns everything when nothing is selected', () {
      const prefs = WorkoutPreferences();
      expect(
        WeekPlanGenerator.allowedGroups(prefs, const [2, 0, 6, 7]),
        [2, 0, 6, 7],
      );
    });
  });
}
