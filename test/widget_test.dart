import 'package:aalumai/core/localization/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('localization delegate resolves app name for all locales', (
    tester,
  ) async {
    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Text(AppLocalizations.of(context).appName),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final expected =
          AppLocalizations.of(tester.element(find.byType(Text))).appName;
      expect(find.text(expected), findsOneWidget);
    }
  });
}
