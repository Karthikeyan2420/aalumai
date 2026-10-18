import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import 'background_config.dart';
import 'background_presets.dart';
import 'background_store.dart';

/// Storage-backed access to the persisted background settings.
final backgroundStoreProvider = Provider<BackgroundStore>(
  (ref) => BackgroundStore(ref.watch(sharedPreferencesProvider)),
);

/// Controls a single slot's background. Home and alarm use separate instances
/// of this controller (see [homeBackgroundProvider] / [alarmBackgroundProvider]).
class BackgroundController extends Notifier<BackgroundConfig> {
  BackgroundController(this.slot);

  final BackgroundSlot slot;

  @override
  BackgroundConfig build() {
    // Degrade gracefully when preferences are unavailable (e.g. a widget test
    // that does not override [sharedPreferencesProvider]): render the slot's
    // built-in default instead of throwing.
    try {
      return ref
          .watch(backgroundStoreProvider)
          .read(slot, BackgroundPresets.defaultFor(slot));
    } catch (_) {
      return BackgroundPresets.defaultFor(slot);
    }
  }

  /// Persists and applies [config].
  Future<void> apply(BackgroundConfig config) async {
    await ref.read(backgroundStoreProvider).write(slot, config);
    state = config;
  }

  /// Adjusts the readability scrim of the current (image) background.
  Future<void> setDim(double dim) =>
      apply(state.copyWith(dim: dim.clamp(0, 1).toDouble()));

  /// Removes any stored preference and restores the built-in default.
  Future<void> reset() async {
    await ref.read(backgroundStoreProvider).clear(slot);
    state = BackgroundPresets.defaultFor(slot);
  }
}

final homeBackgroundProvider =
    NotifierProvider<BackgroundController, BackgroundConfig>(
      () => BackgroundController(BackgroundSlot.home),
    );

final alarmBackgroundProvider =
    NotifierProvider<BackgroundController, BackgroundConfig>(
      () => BackgroundController(BackgroundSlot.alarm),
    );

/// Resolves the provider for a [slot], so shared UI can render either one.
NotifierProvider<BackgroundController, BackgroundConfig> backgroundProviderFor(
  BackgroundSlot slot,
) => switch (slot) {
  BackgroundSlot.home => homeBackgroundProvider,
  BackgroundSlot.alarm => alarmBackgroundProvider,
};
