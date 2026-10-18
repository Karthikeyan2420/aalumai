import 'package:aalumai/core/backgrounds/background_config.dart';
import 'package:aalumai/core/backgrounds/background_presets.dart';
import 'package:aalumai/core/widgets/background_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('missing custom image falls back without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BackgroundView(
          config: BackgroundConfig(
            kind: BackgroundKind.file,
            filePath: 'Z:/definitely/missing/background.jpg',
          ),
          fallback: BackgroundPresets.homeDefault,
          child: Text('content'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(BackgroundView.fallbackKey), findsOneWidget);
    expect(find.text('content'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a solid config without a colour still renders content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BackgroundView(
          config: BackgroundConfig(kind: BackgroundKind.solid),
          child: Text('content'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('a valid solid background does not use the fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BackgroundView(
          config: BackgroundConfig.solid(0xFF102030),
          child: Text('content'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(BackgroundView.fallbackKey), findsNothing);
    expect(find.text('content'), findsOneWidget);
  });
}
