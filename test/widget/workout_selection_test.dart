import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/core/localization/generated/app_localizations.dart';
import 'package:aalumai/core/providers/providers.dart';
import 'package:aalumai/core/widgets/common.dart';
import 'package:aalumai/features/fitness/data/fitness_repository.dart';
import 'package:aalumai/features/fitness/domain/exercise_collections.dart';
import 'package:aalumai/features/fitness/fitness_screen.dart';
import 'package:aalumai/features/fitness/workout_plan_screen.dart';
import 'package:aalumai/features/fitness/workout_player_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// End-to-end coverage for picking one of the three seeded starter plans and
/// actually getting into the guided workout.
///
/// Regression guard: selecting a plan could leave the UI on a spinner forever
/// instead of opening the player.
void main() {
  late AppDatabase db;
  late FitnessRepository repo;
  late SharedPreferences prefs;

  const planNames = [
    'Beginner full body',
    'Dumbbell strength',
    'Bodyweight HIIT',
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FitnessRepository(db);
  });

  tearDown(() => db.close());

  Widget host() => ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      fitnessRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: const FitnessScreen(),
    ),
  );

  /// Seeds the starter data on the real event loop, where drift's executor
  /// actually runs, then returns the seeded plan names.
  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
    await repo.seedExercises();
    await repo.seedStarterPlans();
  });

  /// Drift's executor completes on the real event loop, so flush it between
  /// frames (mirrors workout_player_test._settle).
  Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump();
  }

  /// Re-frames until [probe] holds, giving drift real-async windows to finish.
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

  bool loading() => find.byType(LoadingState).evaluate().isNotEmpty;

  /// Unmounts the tree so drift's stream providers close, then flushes the
  /// zero-duration cleanup timers they schedule (mirrors workout_player_test).
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
  }

  /// Loads each starter plan's exercises straight from the database.
  Future<Map<String, List<Exercise>>> planExercises(WidgetTester tester) async {
    final result = await tester.runAsync(() async {
      final exercises = await repo.watchExercises().first;
      final byId = {for (final e in exercises) e.id: e};
      final plans = await repo.watchPlans().first;
      return {
        for (final p in plans)
          p.name: [
            for (final item in await repo.watchPlanItems(p.id).first)
              byId[item.exerciseId]!,
          ],
      };
    });
    return result!;
  }

  testWidgets('the seeded starter plans are all present', (tester) async {
    await seed(tester);
    final names = await tester.runAsync(
      () async => (await repo.watchPlans().first).map((p) => p.name).toList(),
    );
    expect(names, planNames);

    final items = await planExercises(tester);
    for (final name in planNames) {
      expect(items[name], isNotEmpty, reason: '$name must have exercises');
    }
    // The dumbbell plan holds dumbbell work only — never a generic mix.
    expect(
      items['Dumbbell strength']!.every(
        (e) => exerciseCollection(e) == WorkoutCollection.dumbbell,
      ),
      isTrue,
    );
    expect(
      items['Bodyweight HIIT']!.every(
        (e) =>
            exerciseCollection(e) == WorkoutCollection.bodyweight ||
            exerciseCollection(e) == WorkoutCollection.stretching,
      ),
      isTrue,
    );
  });

  testWidgets('tapping a plan opens its detail screen, not a spinner', (
    tester,
  ) async {
    await seed(tester);
    await tester.pumpWidget(host());
    await settle(tester);

    await tester.tap(
      find.descendant(of: find.byType(TabBar), matching: find.text('Plans')),
    );
    await settle(tester);

    expect(find.text('Beginner full body'), findsOneWidget);

    await tester.tap(find.text('Beginner full body'));
    final opened = await waitFor(
      tester,
      () => find.byType(WorkoutPlanScreen).evaluate().isNotEmpty,
    );
    expect(opened, isTrue, reason: 'selecting a plan must push its detail');

    final loaded = await waitFor(tester, () => !loading());
    expect(loaded, isTrue, reason: 'plan exercises must finish loading');
    final firstExercise =
        (await planExercises(tester))['Beginner full body']!.first.name;
    expect(find.text(firstExercise), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('the play button reaches the guided player for all plans', (
    tester,
  ) async {
    await seed(tester);

    for (final planName in planNames) {
      await tester.pumpWidget(host());
      await settle(tester);
      await tester.tap(
        find.descendant(of: find.byType(TabBar), matching: find.text('Plans')),
      );
      await settle(tester);

      final planTile = find.ancestor(
        of: find.text(planName),
        matching: find.byType(ListTile),
      );
      await tester.ensureVisible(planTile);
      await settle(tester);
      await tester.tap(
        find.descendant(of: planTile, matching: find.byIcon(Icons.play_arrow)),
      );

      final pushed = await waitFor(
        tester,
        () => find.byType(WorkoutPlayerScreen).evaluate().isNotEmpty,
      );
      expect(pushed, isTrue, reason: '$planName must open the player');

      // The guided flow prompts for a readiness check before creating a session.
      final prompted = await waitFor(
        tester,
        () => find.text("I'm ready").evaluate().isNotEmpty,
      );
      expect(prompted, isTrue, reason: '$planName should prompt readiness');
      await tester.tap(find.text("I'm ready"));

      final ready = await waitFor(tester, () => !loading());
      expect(ready, isTrue, reason: '$planName player must leave loading');
      expect(find.byType(WorkoutPlayerScreen), findsOneWidget);
      expect(find.text("I'm ready"), findsNothing);
      expect(tester.takeException(), isNull);

      await unmount(tester);
    }
  });
}
