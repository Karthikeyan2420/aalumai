import 'package:aalumai/core/backgrounds/background_config.dart';
import 'package:aalumai/core/backgrounds/background_presets.dart';
import 'package:aalumai/core/backgrounds/background_providers.dart';
import 'package:aalumai/core/backgrounds/background_store.dart';
import 'package:aalumai/core/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late BackgroundStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = BackgroundStore(prefs);
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('BackgroundStore', () {
    test('returns the fallback when nothing is stored', () {
      expect(
        store.read(BackgroundSlot.home, BackgroundPresets.homeDefault),
        BackgroundPresets.homeDefault,
      );
    });

    test('round-trips a written configuration', () async {
      const config = BackgroundConfig.solid(0xFF102030, label: 'Test');
      await store.write(BackgroundSlot.home, config);
      expect(
        store.read(BackgroundSlot.home, BackgroundPresets.homeDefault),
        config,
      );
    });

    test('clear falls back to the default', () async {
      await store.write(
        BackgroundSlot.alarm,
        const BackgroundConfig.solid(0xFF102030),
      );
      await store.clear(BackgroundSlot.alarm);
      expect(
        store.read(BackgroundSlot.alarm, BackgroundPresets.alarmDefault),
        BackgroundPresets.alarmDefault,
      );
    });

    test('corrupt stored values fall back safely', () async {
      await prefs.setString(
        BackgroundStore.keyFor(BackgroundSlot.home),
        '{not json',
      );
      expect(
        store.read(BackgroundSlot.home, BackgroundPresets.homeDefault),
        BackgroundPresets.homeDefault,
      );
    });
  });

  group('BackgroundController', () {
    test('starts from the slot default', () {
      final container = makeContainer();
      expect(
        container.read(homeBackgroundProvider),
        BackgroundPresets.homeDefault,
      );
      expect(
        container.read(alarmBackgroundProvider),
        BackgroundPresets.alarmDefault,
      );
    });

    test('apply persists and updates the state', () async {
      final container = makeContainer();
      const config = BackgroundConfig.asset(
        BackgroundAssets.homeSunriseLakeMatheson,
        dim: 0.2,
      );
      await container.read(homeBackgroundProvider.notifier).apply(config);
      expect(container.read(homeBackgroundProvider), config);
      expect(
        store.read(BackgroundSlot.home, BackgroundPresets.homeDefault),
        config,
      );
    });

    test('reset restores and clears the default', () async {
      final container = makeContainer();
      final notifier = container.read(homeBackgroundProvider.notifier);
      await notifier.apply(const BackgroundConfig.solid(0xFF102030));

      await notifier.reset();

      expect(
        container.read(homeBackgroundProvider),
        BackgroundPresets.homeDefault,
      );
      expect(
        prefs.getString(BackgroundStore.keyFor(BackgroundSlot.home)),
        isNull,
      );
      expect(
        store.read(BackgroundSlot.home, BackgroundPresets.homeDefault),
        BackgroundPresets.homeDefault,
      );
    });

    test('home and alarm backgrounds are independent', () async {
      final container = makeContainer();
      const homeConfig = BackgroundConfig.solid(0xFF102030);
      await container.read(homeBackgroundProvider.notifier).apply(homeConfig);

      expect(container.read(homeBackgroundProvider), homeConfig);
      expect(
        container.read(alarmBackgroundProvider),
        BackgroundPresets.alarmDefault,
      );
    });

    test('setDim only changes the dim value', () async {
      final container = makeContainer();
      final notifier = container.read(alarmBackgroundProvider.notifier);
      final config =
          BackgroundPresets.imagePresets(BackgroundSlot.alarm).first.config;
      await notifier.apply(config);
      await notifier.setDim(0.7);
      expect(container.read(alarmBackgroundProvider).dim, closeTo(0.7, 1e-9));
      expect(
        container.read(alarmBackgroundProvider).assetPath,
        config.assetPath,
      );
    });
  });

  group('defaults', () {
    test('home default is a warm gradient', () {
      expect(BackgroundPresets.homeDefault.kind, BackgroundKind.gradient);
      expect(
        BackgroundPresets.homeDefault.gradientColors.length,
        greaterThanOrEqualTo(2),
      );
    });

    test('alarm default is a valid image background', () {
      expect(BackgroundPresets.alarmDefault.isValid, isTrue);
      expect(BackgroundPresets.alarmDefault.isImage, isTrue);
    });
  });
}
