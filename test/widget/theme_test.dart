import 'package:aalumai/core/backgrounds/background_presets.dart';
import 'package:aalumai/core/preferences/app_preferences.dart';
import 'package:aalumai/core/providers/providers.dart';
import 'package:aalumai/core/theme/app_theme.dart';
import 'package:aalumai/core/theme/module_theme.dart';
import 'package:aalumai/core/widgets/background_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guards the dark-theme fixes: accent tints and the dashboard backdrop must
/// follow the active theme instead of always washing toward white.
void main() {
  group('softTint', () {
    testWidgets('light and dark tints differ and dark stays dark', (
      tester,
    ) async {
      Future<Color> tintUnder(ThemeData theme) async {
        late Color result;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) {
                result = softTint(context, ModuleAccents.blue);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        // MaterialApp animates between themes; let it settle before sampling.
        await tester.pumpAndSettle();
        return result;
      }

      final light = await tintUnder(AppTheme.light());
      final dark = await tintUnder(AppTheme.dark());

      expect(light, isNot(dark));
      expect(
        dark.computeLuminance(),
        lessThan(light.computeLuminance()),
        reason: 'the dark tint must not be a pale white wash',
      );
      expect(dark.computeLuminance(), lessThan(0.5));
    });
  });

  group('home background default', () {
    test('adapts to brightness', () {
      final light = BackgroundPresets.defaultFor(BackgroundSlot.home);
      final dark = BackgroundPresets.defaultFor(
        BackgroundSlot.home,
        brightness: Brightness.dark,
      );
      expect(light, BackgroundPresets.homeDefault);
      expect(dark, isNot(light));
      expect(
        Color(dark.gradientColors.first).computeLuminance(),
        lessThan(0.3),
        reason: 'the dark dashboard backdrop must be dark',
      );
    });

    testWidgets('CustomBackground renders a dark wash in dark mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const Scaffold(
              body: CustomBackground(
                slot: BackgroundSlot.home,
                child: SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final decorated = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(CustomBackground),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final gradient =
          (decorated.decoration as BoxDecoration).gradient as LinearGradient;
      expect(gradient.colors.first.computeLuminance(), lessThan(0.3));
    });
  });

  group('theme mode', () {
    test('switching updates state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), AppThemeMode.system);
      await container
          .read(themeModeProvider.notifier)
          .setMode(AppThemeMode.dark);
      expect(container.read(themeModeProvider), AppThemeMode.dark);
      expect(AppPreferences(prefs).themeMode, AppThemeMode.dark.index);
    });
  });
}
