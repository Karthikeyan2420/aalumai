import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/core/localization/generated/app_localizations.dart';
import 'package:aalumai/features/fitness/data/fitness_repository.dart';
import 'package:aalumai/features/fitness/domain/geo.dart';
import 'package:aalumai/features/fitness/domain/workout_preferences.dart';
import 'package:aalumai/features/fitness/widgets/daily_workout_card.dart';
import 'package:aalumai/features/fitness/widgets/route_map.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/gif_test_helper.dart';

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
  // The card and route map stream remote images (exercise GIFs + OSM tiles), so
  // the test HTTP client and cache channels must be mocked.
  setupGifTestEnvironment();

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
            // The card lives inside the Home tab's scroll view, so give it a
            // scrollable parent — its growing preview must never overflow.
            home: const Scaffold(
              body: SingleChildScrollView(child: DailyWorkoutCard()),
            ),
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('Daily workout'), findsOneWidget);
      expect(
        find.text('Informed by WHO physical-activity guidance'),
        findsOneWidget,
      );
      // The three phases of the session are all previewed with real exercises.
      expect(find.text('Warm-up'), findsOneWidget);
      expect(find.text('Main work'), findsOneWidget);
      expect(find.text('Cool-down'), findsOneWidget);
      expect(find.text('Start today\'s workout'), findsOneWidget);
      // The weekday heading is always present, whatever day the test runs on.
      expect(find.textContaining(' · '), findsOneWidget);

      await _teardown(tester);
    });
  });

  group('RouteMapView', () {
    Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets('shows satellite map at initial center before fixes', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const RouteMapView(
            points: [],
            initialCenter: LatLng(12.9716, 77.5946),
            emptyHint: 'Waiting for GPS…',
          ),
        ),
      );
      await _settle(tester);

      expect(find.byType(FlutterMap), findsOneWidget);
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
      await _settle(tester);

      expect(find.byIcon(Icons.map_outlined), findsNothing);
      // The real map widget is rendered, not the empty-hint placeholder.
      expect(find.byType(FlutterMap), findsOneWidget);

      await _teardown(tester);
    });
  });
}
