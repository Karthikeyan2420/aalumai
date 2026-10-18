import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/core/localization/generated/app_localizations.dart';
import 'package:aalumai/features/fitness/data/fitness_repository.dart';
import 'package:aalumai/features/fitness/domain/workout_preferences.dart';
import 'package:aalumai/features/fitness/weekly_planner_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _settle(WidgetTester tester, {int rounds = 10}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 60)),
  );
  await tester.pump();
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  // The seeded library is read from a bundled asset, so the binding must exist.
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FitnessRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FitnessRepository(db);
    await repo.seedExercises();
    await repo.savePreferences(
      const WorkoutPreferences(
        trainingDaysMask: 0x7F, // every day
        planStyle: WorkoutPlanStyle.fullBody,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpPlanner(WidgetTester tester, DateTime week) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [fitnessRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WeeklyPlannerScreen(initialWeek: week),
        ),
      ),
    );
    await _settle(tester);
  }

  testWidgets('renders the week header, days and actions', (tester) async {
    final monday = DateTime(2026, 1, 5);
    await pumpPlanner(tester, monday);

    expect(find.text('Weekly planner'), findsOneWidget);
    expect(find.text('Generate week'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.textContaining('Jan'), findsWidgets);

    await _teardown(tester);
  });

  testWidgets('generating a week creates scheduled sessions', (tester) async {
    final monday = DateTime(2026, 1, 5);
    await pumpPlanner(tester, monday);

    await tester.tap(find.text('Generate week'));

    // Poll through real-async windows until the generated rows land.
    var planned = <WorkoutSchedule>[];
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      final rows = await tester.runAsync(
        () => db.select(db.workoutSchedules).get(),
      );
      if (rows != null && rows.any((e) => e.planId != null)) {
        planned = rows.where((e) => e.planId != null).toList();
        break;
      }
    }
    expect(planned, isNotEmpty);

    await _teardown(tester);
  });
}
