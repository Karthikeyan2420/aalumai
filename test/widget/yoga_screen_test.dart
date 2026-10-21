import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/core/localization/generated/app_localizations.dart';
import 'package:aalumai/features/fitness/data/fitness_repository.dart';
import 'package:aalumai/features/fitness/data/yoga_catalog.dart';
import 'package:aalumai/features/fitness/data/yoga_repository.dart';
import 'package:aalumai/features/fitness/domain/indian_yoga.dart';
import 'package:aalumai/features/fitness/domain/workout_preferences.dart';
import 'package:aalumai/features/fitness/domain/yoga.dart';
import 'package:aalumai/features/fitness/yoga_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A catalogue that never touches the asset bundle.
class _FakeCatalog extends YogaCatalog {
  @override
  Future<List<YogaPose>> load() async => kIndianYogaPoses;
}

/// Poses without images, so the test never reaches for the network and the
/// written placeholder is exercised instead.
const _noImagePoses = [
  YogaPose(
    key: 'tadasana',
    englishName: 'Mountain Pose',
    sanskritName: 'Tadasana',
    category: 'Standing',
    instructions: ['Stand tall.'],
  ),
  YogaPose(
    key: 'shavasana',
    englishName: 'Corpse Pose',
    sanskritName: 'Shavasana',
    category: 'Restorative',
    instructions: ['Lie down.'],
  ),
];

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Widget host() {
    final repo = YogaRepository(db, catalog: _FakeCatalog());
    return ProviderScope(
      overrides: [
        yogaRepositoryProvider.overrideWithValue(repo),
        yogaPosesProvider.overrideWith((ref) async => _noImagePoses),
        yogaFavoritesProvider.overrideWith((ref) => Stream.value(<String>{})),
        workoutPreferencesProvider.overrideWith(
          (ref) => Stream.value(const WorkoutPreferences()),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const YogaScreen(),
      ),
    );
  }

  Future<void> pumpYoga(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
  }

  testWidgets('shows today\'s recommendation and the routine list', (
    tester,
  ) async {
    await pumpYoga(tester);

    expect(find.text('Yoga'), findsOneWidget);
    expect(find.text("Today's yoga"), findsOneWidget);
    // The recommended kind is also a card in the routine list below.
    expect(find.text('Morning yoga'), findsWidgets);
    expect(find.text('Mountain Pose'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening a pose shows its instructions', (tester) async {
    await pumpYoga(tester);

    await tester.tap(find.text('Mountain Pose'));
    await tester.pumpAndSettle();

    expect(find.text('How to practise'), findsOneWidget);
    expect(find.text('Stand tall.'), findsOneWidget);
  });

  testWidgets('the favourites filter shows an empty state', (tester) async {
    await pumpYoga(tester);

    await tester.tap(find.widgetWithText(FilterChip, 'Favourites'));
    await tester.pumpAndSettle();

    expect(find.text('No favourite poses yet.'), findsOneWidget);
    expect(find.text('Mountain Pose'), findsNothing);
  });
}
