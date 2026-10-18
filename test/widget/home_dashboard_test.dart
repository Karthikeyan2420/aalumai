import 'package:aalumai/core/localization/generated/app_localizations.dart';
import 'package:aalumai/core/providers/providers.dart';
import 'package:aalumai/features/alarms/data/alarm_repository.dart';
import 'package:aalumai/features/expenses/data/finance_repository.dart';
import 'package:aalumai/features/fitness/data/fitness_repository.dart';
import 'package:aalumai/features/habits/data/habit_repository.dart';
import 'package:aalumai/features/home/home_screen.dart';
import 'package:aalumai/features/learning/data/learning_repository.dart';
import 'package:aalumai/features/meals/data/meal_repository.dart';
import 'package:aalumai/features/music/data/music_providers.dart';
import 'package:aalumai/features/notes/data/note_repository.dart';
import 'package:aalumai/features/savings/data/savings_repository.dart';
import 'package:aalumai/features/schedule/data/event_repository.dart';
import 'package:aalumai/features/tasks/data/task_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Empty-data overrides so the dashboard renders its empty states without a
/// database or any real repository.
List<Override> _emptyOverrides(SharedPreferences prefs) => [
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

Widget _host(ProviderContainer container, {GoRouter? router}) {
  if (router != null) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        routerConfig: router,
      ),
    );
  }
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: HomeScreen(),
    ),
  );
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(overrides: _emptyOverrides(prefs));
    addTearDown(container.dispose);
    return container;
  }

  /// A tall surface so the whole (lazily built) dashboard renders at once.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(420 * 3, 2600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('renders friendly empty states from real (empty) data', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(_host(makeContainer()));
    await tester.pumpAndSettle();

    expect(find.text('Due today'), findsWidgets);
    expect(find.text('No tasks yet. Add your first task.'), findsOneWidget);
    expect(find.text('No habits yet. Build a routine.'), findsOneWidget);
  });

  testWidgets('shows every module card', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(_host(makeContainer()));
    await tester.pumpAndSettle();

    expect(find.text('Alarms'), findsOneWidget);
    expect(find.text('Fitness'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Learn English'), findsOneWidget);
    expect(find.text('Recipes'), findsOneWidget);
  });

  testWidgets('lays out without overflow on a small phone', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(makeContainer()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a quick add-alarm action on the dashboard', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(_host(makeContainer()));
    await tester.pumpAndSettle();

    final quickAdd = find.byKey(const ValueKey('home_quick_add_alarm'));
    await tester.ensureVisible(quickAdd);
    expect(quickAdd, findsOneWidget);
    expect(
      find.descendant(of: quickAdd, matching: find.byIcon(Icons.add_alarm)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: quickAdd, matching: find.text('New alarm')),
      findsOneWidget,
    );
  });

  testWidgets('a module card navigates to its route', (tester) async {
    useTallSurface(tester);
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(
          path: '/alarms',
          builder: (_, __) => const Scaffold(body: Text('ALARMS_STUB')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_host(makeContainer(), router: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alarms'));
    await tester.pumpAndSettle();
    expect(find.text('ALARMS_STUB'), findsOneWidget);
  });
}
