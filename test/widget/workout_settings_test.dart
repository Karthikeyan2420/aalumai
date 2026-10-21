import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/core/localization/generated/app_localizations.dart';
import 'package:aalumai/features/fitness/data/fitness_repository.dart';
import 'package:aalumai/features/settings/workout_settings_screen.dart';
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
  late AppDatabase db;
  late FitnessRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FitnessRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [fitnessRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const WorkoutSettingsScreen(),
        ),
      ),
    );
    await _settle(tester);
  }

  testWidgets('shows equipment and muscle-group sections', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Equipment'), findsOneWidget);
    expect(find.text('Focus muscles'), findsOneWidget);
    expect(find.text('No equipment (bodyweight)'), findsOneWidget);
    expect(find.text('Dumbbell'), findsOneWidget);
    expect(find.text('Resistance band'), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('ticked options are saved to preferences', (tester) async {
    await pumpScreen(tester);

    // Tick resistance bands in addition to the defaults.
    await tester.tap(find.text('Resistance band'));
    await _settle(tester, rounds: 4);

    final saveBtn = find.text('Save preferences');
    await tester.scrollUntilVisible(
      saveBtn,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await _settle(tester, rounds: 4);
    await tester.tap(saveBtn);
    await _settle(tester, rounds: 12);

    final row = await tester.runAsync(() => repo.preferencesRow());
    expect(row, isNotNull);
    expect(row!.equipment.split(','), contains('band'));
    expect(row.equipment.split(','), contains('bodyweight'));

    await _teardown(tester);
  });

  testWidgets('cannot clear the last equipment option', (tester) async {
    await pumpScreen(tester);

    // Untick the three defaults; the last remaining tick is ignored.
    for (final label in ['No equipment (bodyweight)', 'Dumbbell', 'Barbell']) {
      await tester.tap(find.text(label));
      await _settle(tester, rounds: 3);
    }

    final saveBtn = find.text('Save preferences');
    await tester.scrollUntilVisible(
      saveBtn,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await _settle(tester, rounds: 4);
    await tester.tap(saveBtn);
    await _settle(tester, rounds: 12);

    final row = await tester.runAsync(() => repo.preferencesRow());
    expect(row, isNotNull);
    expect(row!.equipment.trim(), isNotEmpty);

    await _teardown(tester);
  });
}
