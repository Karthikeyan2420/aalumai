import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/core/localization/generated/app_localizations.dart';
import 'package:aalumai/features/fitness/data/fitness_repository.dart';
import 'package:aalumai/features/fitness/domain/workout_queue.dart';
import 'package:aalumai/features/fitness/workout_player_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Exercise _exercise() => const Exercise(
  id: 1,
  name: 'Push-up',
  category: 2,
  exerciseType: 0,
  targetMuscles: 'Chest',
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
  isTimed: false,
  defaultSets: 2,
  defaultReps: 10,
  defaultDurationSec: 0,
  restSec: 0,
  mediaPath: '',
  sourceId: '',
  slug: '',
  bodyPart: '',
  secondaryMuscles: '',
  sourceCategory: '',
  gifUrl: '',
);

Future<void> _settle(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  // Drift's in-memory executor completes on the real event loop, so flush it.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 60)),
  );
  await tester.pump();
}

void main() {
  late AppDatabase db;
  late FitnessRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FitnessRepository(db);
    final e = _exercise();
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            id: Value(e.id),
            name: e.name,
            category: Value(e.category),
            isTimed: Value(e.isTimed),
            defaultSets: Value(e.defaultSets),
            defaultReps: Value(e.defaultReps),
            restSec: Value(e.restSec),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('guides through every set and shows a summary', (tester) async {
    final steps = WorkoutQueue.buildFromExercises([_exercise()]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [fitnessRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WorkoutPlayerScreen(title: 'Test', steps: steps),
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('Push-up'), findsOneWidget);
    expect(find.text('Set 1 of 2'), findsOneWidget);

    // Complete the first set via the logging dialog.
    await tester.tap(find.text('Complete set'));
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Complete set'),
      ),
    );
    await _settle(tester);
    expect(find.text('Set 2 of 2'), findsOneWidget);

    // Complete the second set; the workout must finish with a summary.
    await tester.tap(find.text('Complete set'));
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Complete set'),
      ),
    );
    await _settle(tester, rounds: 16);

    expect(find.text('Workout complete'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    // Two sets and a completed session were persisted. Poll through real-async
    // windows so drift's writes are observed.
    List<WorkoutSession> sessions = const [];
    List<WorkoutSetLog> logs = const [];
    for (var i = 0; i < 20; i++) {
      final read = await tester.runAsync(() async {
        final list = await db.select(db.workoutSessions).get();
        final l = await db.select(db.workoutSetLogs).get();
        return (list, l);
      });
      if (read != null) {
        sessions = read.$1;
        logs = read.$2;
        if (sessions.isNotEmpty &&
            sessions.first.endedAt != null &&
            logs.length >= 2) {
          break;
        }
      }
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(sessions, hasLength(1));
    expect(sessions.first.endedAt, isNotNull);
    expect(logs, hasLength(2));
    expect(logs.first.reps, 10);

    // Unmount so drift's stream providers close, then flush the zero-duration
    // cleanup timers they schedule.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
  });
}
