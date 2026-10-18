import 'package:aalumai/core/localization/generated/app_localizations.dart';
import 'package:aalumai/core/providers/providers.dart';
import 'package:aalumai/core/router/app_router.dart';
import 'package:aalumai/features/about/about_screen.dart';
import 'package:aalumai/features/alarms/data/alarm_repository.dart';
import 'package:aalumai/features/expenses/data/finance_repository.dart';
import 'package:aalumai/features/fitness/data/fitness_repository.dart';
import 'package:aalumai/features/habits/data/habit_repository.dart';
import 'package:aalumai/features/home/home_screen.dart';
import 'package:aalumai/features/learning/data/learning_repository.dart';
import 'package:aalumai/features/meals/data/meal_repository.dart';
import 'package:aalumai/features/more/more_screen.dart';
import 'package:aalumai/features/music/data/music_providers.dart';
import 'package:aalumai/features/notes/data/note_repository.dart';
import 'package:aalumai/features/savings/data/savings_repository.dart';
import 'package:aalumai/features/schedule/data/event_repository.dart';
import 'package:aalumai/features/settings/settings_screen.dart';
import 'package:aalumai/features/tasks/data/task_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Empty-data overrides so the real route graph renders without a database.
List<Override> _overrides(SharedPreferences prefs) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  totalBalanceProvider.overrideWith((ref) => Stream.value(0)),
  waterTodayProvider.overrideWith((ref) => Stream.value(const [])),
  nextAlarmProvider.overrideWith((ref) async => null),
  activeHabitsProvider.overrideWith((ref) => Stream.value(const [])),
  weekHabitCompletionsProvider.overrideWith((ref) => Stream.value(const [])),
  todayTasksProvider.overrideWith((ref) => Stream.value(const [])),
  allEventsProvider.overrideWith((ref) => Stream.value(const [])),
  workoutSessionsProvider.overrideWith((ref) => Stream.value(const [])),
  allNotesProvider.overrideWith((ref) => Stream.value(const [])),
  savingsGoalsProvider.overrideWith((ref) => Stream.value(const [])),
  recipesProvider.overrideWith((ref) => Stream.value(const [])),
  musicTracksProvider.overrideWith((ref) => Stream.value(const [])),
  coursesProvider.overrideWith((ref) => Stream.value(const [])),
];

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<GoRouter> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420 * 3, 2600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = createRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(prefs),
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  /// Simulates the Android system Back button/gesture.
  /// Returns whether the framework handled it (false would mean app exit).
  Future<bool> systemBack(WidgetTester tester) async {
    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    return handled;
  }

  testWidgets('cold launch starts on the dashboard', (tester) async {
    await pumpApp(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.byType(AboutScreen), findsNothing);
  });

  testWidgets('Settings opened from Home returns to Home on system Back', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    final handled = await systemBack(tester);
    expect(handled, isTrue, reason: 'Back must be handled, not close the app');
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('About opened from Settings returns to Settings on Back', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutScreen), findsOneWidget);

    var handled = await systemBack(tester);
    expect(handled, isTrue, reason: 'Back must return to Settings');
    expect(find.byType(AboutScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsOneWidget);

    handled = await systemBack(tester);
    expect(handled, isTrue, reason: 'Back must return to Home');
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('About opened from the More tab returns to More on Back', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('More'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MoreScreen), findsOneWidget);

    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutScreen), findsOneWidget);

    final handled = await systemBack(tester);
    expect(handled, isTrue, reason: 'Back must return to the More tab');
    expect(find.byType(AboutScreen), findsNothing);
    expect(find.byType(MoreScreen), findsOneWidget);
  });
}
