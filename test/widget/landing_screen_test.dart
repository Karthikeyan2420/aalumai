import 'package:aalumai/core/localization/generated/app_localizations.dart';
import 'package:aalumai/core/providers/providers.dart';
import 'package:aalumai/core/router/app_router.dart';
import 'package:aalumai/features/landing/landing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const delegates = <LocalizationsDelegate<dynamic>>[
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  List<Override> overrides() => [
    sharedPreferencesProvider.overrideWithValue(prefs),
  ];

  Future<void> pumpLanding(WidgetTester tester, GoRouter router) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp.router(
          localizationsDelegates: delegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
  }

  GoRouter buildRouter() => GoRouter(
    initialLocation: AppRoutes.landing,
    routes: [
      GoRoute(
        path: AppRoutes.landing,
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const Scaffold(body: Text('HOME_STUB')),
      ),
    ],
  );

  testWidgets('shows branding, all six features and Get Started', (
    tester,
  ) async {
    await pumpLanding(tester, buildRouter());

    expect(find.text('ஆளுமை'), findsOneWidget);
    expect(find.text('AALUMAI'), findsOneWidget);
    expect(find.text('உங்கள் வாழ்க்கை. உங்கள் கட்டுப்பாடு.'), findsOneWidget);
    expect(find.text('Your life. Your control.'), findsOneWidget);

    expect(find.text('Smart Alarms'), findsOneWidget);
    expect(find.text('Wake up with purpose'), findsOneWidget);
    expect(find.text('Fitness & Workouts'), findsOneWidget);
    expect(find.text('Be healthy and strong'), findsOneWidget);
    expect(find.text('Music Player'), findsOneWidget);
    expect(find.text('Your songs, your mood'), findsOneWidget);
    expect(find.text('Habits & Tasks'), findsOneWidget);
    expect(find.text('Build a better routine'), findsOneWidget);
    expect(find.text('Expenses & Savings'), findsOneWidget);
    expect(find.text('Track and grow'), findsOneWidget);
    expect(find.text('Calendar & Notes'), findsOneWidget);
    expect(find.text('Stay organized'), findsOneWidget);

    expect(find.byKey(const ValueKey('landing_get_started')), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('shows all five language options', (tester) async {
    await pumpLanding(tester, buildRouter());

    for (final code in ['en', 'ta', 'te', 'ml', 'kn']) {
      expect(find.byKey(ValueKey('landing_lang_$code')), findsOneWidget);
    }
  });

  testWidgets('selecting a language persists it and marks the chip selected', (
    tester,
  ) async {
    await pumpLanding(tester, buildRouter());

    final chip = find.byKey(const ValueKey('landing_lang_ta'));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(prefs.getString('locale_code'), 'ta');
    expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
  });

  testWidgets('Get Started marks onboarding complete and navigates home', (
    tester,
  ) async {
    await pumpLanding(tester, buildRouter());

    expect(find.text('HOME_STUB'), findsNothing);

    final button = find.byKey(const ValueKey('landing_get_started'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(prefs.getBool('first_run_complete'), isTrue);
    expect(find.text('HOME_STUB'), findsOneWidget);
    expect(find.byType(LandingScreen), findsNothing);
  });

  testWidgets('localised Get Started label follows the locale', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          locale: const Locale('ta'),
          localizationsDelegates: delegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LandingScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('தொடங்குங்கள்'), findsOneWidget);
    expect(find.text('ஸ்மார்ட் அலாரங்கள்'), findsOneWidget);
  });
}
