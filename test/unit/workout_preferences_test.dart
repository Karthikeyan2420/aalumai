import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/features/fitness/domain/workout_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fitness_fixtures.dart';

void main() {
  group('TrainingDays', () {
    test('sets and reads Monday-first bits', () {
      final mask = TrainingDays.fromWeekdays([1, 3, 5]);
      expect(TrainingDays.has(mask, 1), isTrue);
      expect(TrainingDays.has(mask, 2), isFalse);
      expect(TrainingDays.has(mask, 3), isTrue);
      expect(TrainingDays.has(mask, 5), isTrue);
      expect(TrainingDays.toWeekdays(mask), [1, 3, 5]);
    });

    test('toggles a weekday on and off', () {
      var mask = 0;
      mask = TrainingDays.toggle(mask, 2);
      expect(TrainingDays.has(mask, 2), isTrue);
      mask = TrainingDays.toggle(mask, 2);
      expect(TrainingDays.has(mask, 2), isFalse);
    });

    test('ignores out-of-range weekdays', () {
      expect(TrainingDays.has(0x7F, 0), isFalse);
      expect(TrainingDays.has(0x7F, 8), isFalse);
      expect(TrainingDays.toggle(0, 9), 0);
    });
  });

  group('WorkoutPreferences encoding', () {
    test('round-trips integer and string lists', () {
      expect(WorkoutPreferences.decodeInts('2,3,5'), [2, 3, 5]);
      expect(WorkoutPreferences.decodeInts(''), isEmpty);
      expect(WorkoutPreferences.decodeInts('2, x, 3'), [2, 3]);
      expect(WorkoutPreferences.encodeInts([1, 4]), '1,4');

      expect(WorkoutPreferences.decodeStrings('Mat, Dumbbells'), [
        'Mat',
        'Dumbbells',
      ]);
      expect(WorkoutPreferences.encodeStrings(['Mat']), 'Mat');
    });

    test('round-trips substitutions', () {
      final subs = {10: 12, 5: 7};
      final encoded = WorkoutPreferences.encodeSubstitutions(subs);
      expect(WorkoutPreferences.decodeSubstitutions(encoded), subs);
      expect(WorkoutPreferences.decodeSubstitutions('garbage'), isEmpty);
    });

    test('fromRow maps persisted indexes back to enums', () {
      final row = WorkoutPref(
        id: 1,
        planStyle: WorkoutPlanStyle.muscleSplit.index,
        fitnessLevel: FitnessLevel.intermediate.index,
        equipment: 'Mat,Dumbbells',
        sessionMinutes: 45,
        trainingDaysMask: TrainingDays.fromWeekdays([1, 2, 4]),
        restDaysMask: TrainingDays.fromWeekdays([7]),
        goal: WorkoutGoal.strength.index,
        goalMuscles: '2,3',
        preferredMinuteOfDay: 420,
        substitutions: '1>2',
        safetyAcknowledged: true,
        updatedAt: DateTime(2026, 1, 1),
      );
      final prefs = WorkoutPreferences.fromRow(row);
      expect(prefs.planStyle, WorkoutPlanStyle.muscleSplit);
      expect(prefs.fitnessLevel, FitnessLevel.intermediate);
      expect(prefs.equipment, ['Mat', 'Dumbbells']);
      expect(prefs.sessionMinutes, 45);
      expect(prefs.trainingDaysMask, TrainingDays.fromWeekdays([1, 2, 4]));
      expect(prefs.goal, WorkoutGoal.strength);
      expect(prefs.goalMuscles, [2, 3]);
      expect(prefs.preferredMinuteOfDay, 420);
      expect(prefs.substitutions, {1: 2});
      expect(prefs.safetyAcknowledged, isTrue);
    });
  });

  group('WeekPlanGenerator.generate', () {
    final monday = DateTime(2026, 1, 5);
    final library = [
      testExercise(id: 1, name: 'Push-ups', category: 2),
      testExercise(id: 2, name: 'Row', category: 3),
      testExercise(id: 3, name: 'Squat', category: 4),
      testExercise(id: 4, name: 'Plank', category: 5, isTimed: true),
      testExercise(id: 5, name: 'Jacks', category: 6, isTimed: true),
      testExercise(id: 6, name: 'Curls', category: 0),
      testExercise(
        id: 7,
        name: 'Goblet squat',
        category: 4,
        equipment: 'Two dumbbells',
      ),
    ];

    test('produces seven days and marks non-training days as rest', () {
      final prefs = WorkoutPreferences(
        trainingDaysMask: TrainingDays.fromWeekdays([1, 3, 5]),
      );
      final days = WeekPlanGenerator.generate(
        preferences: prefs,
        exercises: library,
        weekStart: monday,
      );
      expect(days, hasLength(7));
      expect(days[0].isRest, isFalse); // Monday
      expect(days[1].isRest, isTrue); // Tuesday
      expect(days[2].isRest, isFalse); // Wednesday
      expect(days[4].isRest, isFalse); // Friday
      expect(days[6].isRest, isTrue); // Sunday
    });

    test('never repeats an exercise within a day', () {
      final prefs = WorkoutPreferences(sessionMinutes: 60);
      final days = WeekPlanGenerator.generate(
        preferences: prefs,
        exercises: library,
        weekStart: monday,
      );
      for (final day in days.where((d) => !d.isRest)) {
        final ids = day.items.map((i) => i.exerciseId).toList();
        expect(ids.length, ids.toSet().length);
      }
    });

    test('excludes exercises whose equipment is unavailable', () {
      final prefs = WorkoutPreferences(
        fitnessLevel: FitnessLevel.advanced,
        equipment: ['Mat'],
        planStyle: WorkoutPlanStyle.fullBody,
      );
      final days = WeekPlanGenerator.generate(
        preferences: prefs,
        exercises: library,
        weekStart: monday,
      );
      final usedIds = [
        for (final d in days)
          for (final i in d.items) i.exerciseId,
      ];
      expect(usedIds, isNot(contains(7))); // dumbbell-only exercise
    });

    test('applies substitutions to chosen items', () {
      final prefs = WorkoutPreferences(
        planStyle: WorkoutPlanStyle.fullBody,
        fitnessLevel: FitnessLevel.advanced,
      );
      final days = WeekPlanGenerator.generate(
        preferences: prefs,
        exercises: library,
        weekStart: monday,
        substitutions: {1: 6},
      );
      final used = [
        for (final d in days)
          for (final i in d.items) i.exerciseId,
      ];
      expect(used, contains(6));
      expect(used, isNot(contains(1)));
    });

    test('respects the fitness level ceiling', () {
      final libraryWithAdvanced = [
        ...library,
        testExercise(id: 9, name: 'Hard', category: 2, difficulty: 2),
      ];
      final prefs = WorkoutPreferences(
        fitnessLevel: FitnessLevel.beginner,
        planStyle: WorkoutPlanStyle.fullBody,
      );
      final days = WeekPlanGenerator.generate(
        preferences: prefs,
        exercises: libraryWithAdvanced,
        weekStart: monday,
      );
      final used = [
        for (final d in days)
          for (final i in d.items) i.exerciseId,
      ];
      expect(used, isNot(contains(9)));
    });
  });

  group('WhoDailyPlan', () {
    final library = [
      testExercise(id: 1, name: 'Push-ups', category: 2),
      testExercise(id: 2, name: 'Curls', category: 0),
      testExercise(id: 3, name: 'Row', category: 3),
      testExercise(id: 4, name: 'Press', category: 1),
      testExercise(id: 5, name: 'Squat', category: 4),
      testExercise(id: 6, name: 'Plank', category: 5, isTimed: true),
      testExercise(id: 7, name: 'Jacks', category: 6, isTimed: true),
      testExercise(id: 8, name: 'Downward dog', category: 7),
    ];

    test('every day pairs strength with cardio and closes with yoga', () {
      for (var weekday = 1; weekday <= 7; weekday++) {
        final groups = WhoDailyPlan.groupsFor(weekday);
        expect(groups, contains(WhoDailyPlan.cardio));
        expect(groups.last, WhoDailyPlan.yoga);
      }
    });

    test('Monday focuses on chest and biceps, cardio before yoga', () {
      expect(WhoDailyPlan.groupsFor(DateTime.monday), [2, 0, 6, 7]);
    });

    test('Sunday is an active-recovery day without a strength focus', () {
      expect(WhoDailyPlan.isRecovery(DateTime.sunday), isTrue);
      expect(WhoDailyPlan.focusFor(DateTime.sunday), isEmpty);
      expect(WhoDailyPlan.groupsFor(DateTime.sunday), [6, 7]);
    });

    test('generateWhoDay builds a Monday session in focus order', () {
      final day = WeekPlanGenerator.generateWhoDay(
        date: DateTime(2026, 1, 5), // Monday
        preferences: const WorkoutPreferences(
          fitnessLevel: FitnessLevel.advanced,
        ),
        exercises: library,
      );
      expect(day, isNotNull);
      expect(day!.items, isNotEmpty);
      expect(day.muscleGroups, [2, 0, 6, 7]);
    });

    test('generateWhoDay returns null when nothing matches', () {
      final day = WeekPlanGenerator.generateWhoDay(
        date: DateTime(2026, 1, 5),
        preferences: const WorkoutPreferences(),
        exercises: const [],
      );
      expect(day, isNull);
    });
  });

  group('WeekPlanGenerator.validate', () {
    PlannedItem item(int id) => PlannedItem(
      exerciseId: id,
      sets: 3,
      reps: 10,
      durationSec: 0,
      restSec: 30,
    );

    test('flags a duplicate exercise within a day', () {
      final days = [
        PlannedDay(
          date: DateTime(2026, 1, 5),
          title: '',
          muscleGroups: const [2],
          items: [item(1), item(1)],
        ),
      ];
      final warnings = WeekPlanGenerator.validate(
        days: days,
        preferences: const WorkoutPreferences(),
      );
      expect(
        warnings.map((w) => w.kind),
        contains(PlanWarningKind.duplicateExercise),
      );
    });

    test('flags the same muscle group on consecutive days', () {
      final days = [
        PlannedDay(
          date: DateTime(2026, 1, 5),
          title: '',
          muscleGroups: const [2],
          items: [item(1)],
        ),
        PlannedDay(
          date: DateTime(2026, 1, 6),
          title: '',
          muscleGroups: const [2],
          items: [item(2)],
        ),
      ];
      final warnings = WeekPlanGenerator.validate(
        days: days,
        preferences: const WorkoutPreferences(),
      );
      expect(
        warnings.map((w) => w.kind),
        contains(PlanWarningKind.consecutiveSameMuscle),
      );
    });

    test('flags four consecutive training days without rest', () {
      final days = [
        for (var i = 0; i < 5; i++)
          PlannedDay(
            date: DateTime(2026, 1, 5 + i),
            title: '',
            muscleGroups: [i],
            items: [item(i + 1)],
          ),
      ];
      final warnings = WeekPlanGenerator.validate(
        days: days,
        preferences: const WorkoutPreferences(),
      );
      expect(
        warnings.map((w) => w.kind),
        contains(PlanWarningKind.tooManyConsecutiveDays),
      );
    });

    test('flags excessive volume relative to the session target', () {
      final heavy = PlannedItem(
        exerciseId: 1,
        sets: 20,
        reps: 50,
        durationSec: 120,
        restSec: 120,
      );
      final days = [
        PlannedDay(
          date: DateTime(2026, 1, 5),
          title: '',
          muscleGroups: const [2],
          items: [heavy],
        ),
      ];
      final warnings = WeekPlanGenerator.validate(
        days: days,
        preferences: const WorkoutPreferences(sessionMinutes: 20),
      );
      expect(
        warnings.map((w) => w.kind),
        contains(PlanWarningKind.heavyVolume),
      );
    });
  });
}
