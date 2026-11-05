import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/providers.dart';

/// User choice for loading workout GIFs and yoga images.
class FitnessMediaSettings {
  const FitnessMediaSettings({
    required this.online,
    required this.offlinePackReady,
  });

  final bool online;
  final bool offlinePackReady;
}

class FitnessMediaSettingsNotifier extends Notifier<FitnessMediaSettings> {
  @override
  FitnessMediaSettings build() {
    final prefs = ref.read(appPreferencesProvider);
    return FitnessMediaSettings(
      online: prefs.fitnessMediaOnline,
      offlinePackReady: prefs.fitnessOfflinePackReady,
    );
  }

  Future<void> setOnline(bool online) async {
    await ref.read(appPreferencesProvider).setFitnessMediaOnline(online);
    state = FitnessMediaSettings(
      online: online,
      offlinePackReady: state.offlinePackReady,
    );
  }

  Future<void> markOfflinePackReady() async {
    await ref.read(appPreferencesProvider).setFitnessOfflinePackReady(true);
    state = FitnessMediaSettings(
      online: state.online,
      offlinePackReady: true,
    );
  }
}

final fitnessMediaSettingsProvider =
    NotifierProvider<FitnessMediaSettingsNotifier, FitnessMediaSettings>(
      FitnessMediaSettingsNotifier.new,
    );

final fitnessMediaOnlineProvider = Provider<bool>(
  (ref) => ref.watch(fitnessMediaSettingsProvider).online,
);
