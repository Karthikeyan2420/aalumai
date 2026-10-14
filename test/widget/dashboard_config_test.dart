import 'package:aalumai/core/localization/generated/app_localizations.dart';
import 'package:aalumai/core/preferences/app_preferences.dart';
import 'package:aalumai/core/providers/providers.dart';
import 'package:aalumai/features/home/dashboard_config_screen.dart';
import 'package:aalumai/features/home/dashboard_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: DashboardConfigScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists every dashboard section in order', (tester) async {
    await pumpScreen(tester);
    for (final section in DashboardSection.values) {
      expect(find.byKey(ValueKey(section.name)), findsOneWidget);
    }
  });

  testWidgets('toggling a switch persists the hidden section', (tester) async {
    await pumpScreen(tester);

    final summary = find.byKey(const ValueKey('summary'));
    final switchFinder = find.descendant(
      of: summary,
      matching: find.byType(Switch),
    );
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    final saved = AppPreferences(prefs).dashboardHidden;
    expect(saved, contains('summary'));
  });
}
