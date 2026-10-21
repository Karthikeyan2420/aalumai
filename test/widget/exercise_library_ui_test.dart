import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/core/localization/generated/app_localizations.dart';
import 'package:aalumai/features/fitness/data/fitness_repository.dart';
import 'package:aalumai/features/fitness/domain/exercise_collections.dart';
import 'package:aalumai/features/fitness/domain/exercise_format.dart';
import 'package:aalumai/features/fitness/exercise_category_screen.dart';
import 'package:aalumai/features/fitness/widgets/exercise_art.dart';
import 'package:aalumai/features/fitness/widgets/exercise_gif.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/gif_test_helper.dart';

/// Exercises filed by metadata, so each collection's list can be checked
/// without ever downloading a demonstration.
Future<void> _seed(AppDatabase db) async {
  Future<void> add({
    required int id,
    required String name,
    required String muscle,
    required String equipment,
    required String sourceCategory,
    required int category,
    String instructions = '',
  }) => db
      .into(db.exercises)
      .insert(
        ExercisesCompanion.insert(
          id: Value(id),
          name: name,
          category: Value(category),
          targetMuscles: Value(muscle),
          equipment: Value(equipment),
          sourceCategory: Value(sourceCategory),
          gifUrl: Value('https://cdn.example/$id.gif'),
          instructions: Value(instructions),
          // The dataset publishes no difficulty; the seeder stores this marker.
          difficulty: const Value(kUnknownDifficulty),
        ),
      );

  await add(
    id: 1,
    name: 'Dumbbell Bicep Curl',
    muscle: 'Biceps',
    equipment: 'dumbbell',
    sourceCategory: 'strength',
    category: 0,
    instructions: 'Curl the weight.\nLower it slowly.',
  );
  await add(
    id: 2,
    name: 'Dumbbell Lateral Raise',
    muscle: 'Shoulders',
    equipment: 'dumbbell',
    sourceCategory: 'strength',
    category: 1,
  );
  await add(
    id: 3,
    name: 'Push-up',
    muscle: 'Chest',
    equipment: 'bodyweight',
    sourceCategory: 'strength',
    category: 2,
  );
}

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

/// Unmounts the tree so drift's stream providers close, then flushes the
/// zero-duration cleanup timers they schedule.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 20));
}

/// Gives the detail page enough room that its whole column is laid out.
void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(FitnessRepository repo, {WorkoutCollection? collection}) {
  return ProviderScope(
    overrides: [fitnessRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: ExerciseCategoryScreen(collection: collection),
    ),
  );
}

void main() {
  setupGifTestEnvironment();

  late AppDatabase db;
  late FitnessRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FitnessRepository(db);
    await _seed(db);
  });

  tearDown(() => db.close());

  testWidgets('a collection lists only its own equipment', (tester) async {
    await tester.pumpWidget(_app(repo, collection: WorkoutCollection.dumbbell));
    await _settle(tester);

    expect(find.text('Dumbbell Bicep Curl'), findsOneWidget);
    expect(find.text('Dumbbell Lateral Raise'), findsOneWidget);
    // Bodyweight work must never leak into the dumbbell list.
    expect(find.text('Push-up'), findsNothing);
    // Muscle, equipment and count come from the stored metadata.
    expect(find.text('Biceps · Dumbbell'), findsOneWidget);
    expect(find.text('2 Exercises'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('search narrows the list by name', (tester) async {
    await tester.pumpWidget(_app(repo, collection: WorkoutCollection.dumbbell));
    await _settle(tester);

    await tester.enterText(find.byType(TextField), 'lateral');
    await _settle(tester);

    expect(find.text('Dumbbell Lateral Raise'), findsOneWidget);
    expect(find.text('Dumbbell Bicep Curl'), findsNothing);
    expect(find.text('1 Exercises'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('an unmatched search shows the empty state', (tester) async {
    await tester.pumpWidget(_app(repo, collection: WorkoutCollection.dumbbell));
    await _settle(tester);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await _settle(tester);

    expect(find.text('No exercises match your filters.'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('tapping a row opens the detail screen', (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(_app(repo, collection: WorkoutCollection.dumbbell));
    await _settle(tester);

    await tester.tap(find.text('Dumbbell Bicep Curl'));
    await _settle(tester);

    expect(find.text('How to do it'), findsOneWidget);
    expect(find.text('Curl the weight.'), findsOneWidget);
    expect(find.text('Lower it slowly.'), findsOneWidget);
    expect(find.text('Target muscles'), findsOneWidget);
    // The dataset publishes no difficulty, so no level may be claimed.
    expect(find.text('Beginner'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('every tile streams its demonstration GIF', (tester) async {
    await tester.pumpWidget(_app(repo, collection: WorkoutCollection.dumbbell));
    await _settle(tester);

    // One remote image per visible tile: the GIF is streamed and cached, not
    // bundled. The mock HTTP overrides return a tiny valid image so the load
    // succeeds without network access.
    expect(find.byType(CachedNetworkImage), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('an exercise with no media uses the illustration', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(
          body: ExerciseGif(gifUrl: '', category: 2, timed: false),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ExerciseArt), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('the whole library is browsable without a collection', (
    tester,
  ) async {
    await tester.pumpWidget(_app(repo));
    await _settle(tester);

    expect(find.text('3 Exercises'), findsOneWidget);
    expect(find.text('Push-up'), findsOneWidget);
    await _unmount(tester);
  });
}
