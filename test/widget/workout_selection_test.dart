import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/core/localization/generated/app_localizations.dart';
import 'package:aalumai/core/providers/providers.dart';
import 'package:aalumai/features/fitness/data/fitness_repository.dart';
import 'package:aalumai/features/fitness/domain/equipment_filter.dart';
import 'package:aalumai/features/fitness/domain/gym_focus.dart';
import 'package:aalumai/features/fitness/domain/workout_preferences.dart';
import 'package:aalumai/features/fitness/fitness_screen.dart';
import 'package:aalumai/features/fitness/gym/day_workout_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/gif_test_helper.dart';

void main() {
  setupGifTestEnvironment();

  late AppDatabase db;
  late FitnessRepository repo;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FitnessRepository(db);
    await repo.savePreferences(
      const WorkoutPreferences(onboardingDone: true, safetyAcknowledged: true),
    );
  });

  tearDown(() => db.close());

  Widget host() => ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appDatabaseProvider.overrideWithValue(db),
      fitnessRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: const FitnessScreen(),
    ),
  );

  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
    await repo.seedExercises();
    await repo.seedStarterPlans();
  });

  Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump();
  }

  Future<bool> waitFor(
    WidgetTester tester,
    bool Function() probe, {
    int rounds = 30,
  }) async {
    for (var i = 0; i < rounds; i++) {
      if (probe()) return true;
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
    return probe();
  }

  testWidgets('Workout tab opens category grid after onboarding', (
    tester,
  ) async {
    await seed(tester);
    await tester.pumpWidget(host());
    await settle(tester, rounds: 12);

    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<int>),
        matching: find.text('Workout'),
      ),
    );
    await settle(tester);

    expect(find.text('ARM & SHOULDER'), findsOneWidget);
    expect(find.text('Dumbbell'), findsWidgets);
    expect(find.text('Bodyweight'), findsOneWidget);
    expect(find.text('Adjust the order'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('DayWorkoutScreen shows Start for picked exercises', (
    tester,
  ) async {
    await seed(tester);
    late List<Exercise> all;
    await tester.runAsync(() async {
      all = await repo.watchExercises().first;
    });
    final picked = pickFocusExercises(
      all: all,
      focus: GymFocusKey.armShoulder,
      mode: WorkoutMode.dumbbell,
      levelIndex: 0,
      count: 8,
    );
    expect(picked, isNotEmpty);
    final rows = [
      for (final e in picked)
        (
          exercise: e,
          sets: 3,
          reps: e.defaultReps,
          durationSec: e.isTimed ? e.defaultDurationSec : 0,
          restSec: 60,
        ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          fitnessRepositoryProvider.overrideWithValue(repo),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: DayWorkoutScreen(title: 'DAY 1', exercises: rows),
        ),
      ),
    );
    expect(find.text('Start'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
