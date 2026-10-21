import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/core/localization/generated/app_localizations.dart';
import 'package:aalumai/features/fitness/data/fitness_repository.dart';
import 'package:aalumai/features/fitness/workout_preferences_screen.dart';
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

  Future<void> pumpPrefs(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [fitnessRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const WorkoutPreferencesScreen(),
        ),
      ),
    );
    await _settle(tester);
  }

  testWidgets('shows every preference section', (tester) async {
    await pumpPrefs(tester);

    expect(find.text('Customize workout'), findsOneWidget);
    // Sections are laid out in a scrollable body.
    expect(find.byType(ListView), findsOneWidget);
    final saveBtn = find.text('Save preferences');
    await tester.scrollUntilVisible(
      saveBtn,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(saveBtn, findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('acknowledging safety guidance persists', (tester) async {
    await pumpPrefs(tester);

    // Scroll to the safety card and tick the acknowledgement.
    final checkbox = find.text('I understand and will stay within my limits');
    await tester.scrollUntilVisible(
      checkbox,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await _settle(tester, rounds: 6);
    await tester.tap(checkbox);
    await _settle(tester, rounds: 6);

    // Persist via the Save button at the end of the form.
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
    expect(row!.safetyAcknowledged, isTrue);

    await _teardown(tester);
  });
}
