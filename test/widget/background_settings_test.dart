import 'package:aalumai/core/backgrounds/background_presets.dart';
import 'package:aalumai/core/backgrounds/background_store.dart';
import 'package:aalumai/core/providers/providers.dart';
import 'package:aalumai/features/settings/background_settings_screen.dart';
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

  // A tall viewport keeps every section of the (lazy) list built, so finders
  // don't depend on scrolling behaviour.
  Future<void> pumpScreen(WidgetTester tester, BackgroundSlot slot) async {
    await tester.binding.setSurfaceSize(const Size(800, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(home: BackgroundSettingsScreen(slot: slot)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows image, colour and gradient sections', (tester) async {
    await pumpScreen(tester, BackgroundSlot.home);

    expect(find.text('Images'), findsOneWidget);
    expect(find.text('Solid colours'), findsOneWidget);
    expect(find.text('Gradients'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('bg_image_home_lake_matheson')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('bg_reset')), findsOneWidget);
    expect(find.byKey(const ValueKey('bg_custom_image')), findsOneWidget);
  });

  testWidgets('selecting a solid swatch persists it', (tester) async {
    await pumpScreen(tester, BackgroundSlot.home);

    await tester.tap(find.byKey(const ValueKey('bg_swatch_Cream')));
    await tester.pumpAndSettle();

    final saved = BackgroundStore(
      prefs,
    ).read(BackgroundSlot.home, BackgroundPresets.homeDefault);
    expect(saved.color, 0xFFFFF3E0);
  });

  testWidgets('selecting an alarm image preset persists it', (tester) async {
    await pumpScreen(tester, BackgroundSlot.alarm);

    await tester.tap(find.byKey(const ValueKey('bg_image_alarm_moon_01')));
    await tester.pumpAndSettle();

    final saved = BackgroundStore(
      prefs,
    ).read(BackgroundSlot.alarm, BackgroundPresets.alarmDefault);
    expect(saved.assetPath, BackgroundAssets.alarmFullMoonNight01);
  });

  testWidgets('reset clears the stored value and restores the default', (
    tester,
  ) async {
    await pumpScreen(tester, BackgroundSlot.alarm);

    await tester.tap(find.byKey(const ValueKey('bg_swatch_Near black')));
    await tester.pumpAndSettle();
    expect(
      BackgroundStore(
        prefs,
      ).read(BackgroundSlot.alarm, BackgroundPresets.alarmDefault).color,
      0xFF05070D,
    );

    await tester.tap(find.byKey(const ValueKey('bg_reset')));
    await tester.pumpAndSettle();

    expect(
      prefs.getString(BackgroundStore.keyFor(BackgroundSlot.alarm)),
      isNull,
    );
    expect(
      BackgroundStore(
        prefs,
      ).read(BackgroundSlot.alarm, BackgroundPresets.alarmDefault),
      BackgroundPresets.alarmDefault,
    );
  });
}
