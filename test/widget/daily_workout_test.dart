import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/core/localization/generated/app_localizations.dart';
import 'package:aalumai/features/fitness/data/fitness_repository.dart';
import 'package:aalumai/features/fitness/domain/geo.dart';
import 'package:aalumai/features/fitness/domain/workout_preferences.dart';
import 'package:aalumai/features/fitness/widgets/daily_workout_card.dart';
import 'package:aalumai/features/fitness/widgets/route_map.dart';
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

  group('DailyWorkoutCard', () {
    late AppDatabase db;
    late FitnessRepository repo;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = FitnessRepository(db);
      await repo.seedExercises();
      // Every day is a training day so today always has a session.
      await repo.savePreferences(
        const WorkoutPreferences(trainingDaysMask: 0x7F),
      );
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('shows today\'s WHO session with cardio and yoga', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [fitnessRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: DailyWorkoutCard()),
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('Daily workout'), findsOneWidget);
      expect(
        find.text('Informed by WHO physical-activity guidance'),
        findsOneWidget,
      );
      expect(find.text('Cardio every day'), findsOneWidget);
      expect(find.text('Yoga cool-down'), findsOneWidget);
      expect(find.text('Start today\'s workout'), findsOneWidget);
      // The weekday heading is always present, whatever day the test runs on.
      expect(find.textContaining(' · '), findsOneWidget);

      await _teardown(tester);
    });
  });

  group('RouteMapView', () {
    Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets('shows a hint while there are no fixes', (tester) async {
      await tester.pumpWidget(wrap(const RouteMapView(points: [])));

      expect(find.byIcon(Icons.map_outlined), findsOneWidget);
      expect(find.text('Waiting for GPS…'), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('paints the recorded track once fixes arrive', (tester) async {
      await tester.pumpWidget(
        wrap(
          const RouteMapView(
            points: [
              GeoPoint(latitude: 12.9716, longitude: 77.5946, timestampMs: 0),
              GeoPoint(
                latitude: 12.9726,
                longitude: 77.5956,
                timestampMs: 1000,
              ),
            ],
            active: true,
          ),
        ),
      );

      expect(find.byIcon(Icons.map_outlined), findsNothing);
      expect(find.byType(CustomPaint), findsWidgets);

      await _teardown(tester);
    });
  });
}
