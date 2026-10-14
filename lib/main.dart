import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/providers/providers.dart';
import 'core/services/notification_service.dart';
import 'features/alarms/data/alarm_repository.dart';
import 'features/expenses/data/finance_repository.dart';
import 'features/fitness/data/fitness_repository.dart';
import 'features/learning/data/learning_repository.dart';
import 'features/music/data/player_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  final prefs = await SharedPreferences.getInstance();

  final audioHandler = await _initAudioHandler();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      if (audioHandler != null)
        audioHandlerProvider.overrideWithValue(audioHandler),
    ],
  );

  await _bootstrap(container);

  runApp(
    UncontrolledProviderScope(container: container, child: const AalumaiApp()),
  );
}

/// Best-effort background-audio setup. The Android media session needs a
/// foreground service, so if initialisation fails (e.g. a platform without it)
/// the app still starts and music plays in-process.
Future<AalumaiAudioHandler?> _initAudioHandler() async {
  try {
    return await AudioService.init(
      builder: () => AalumaiAudioHandler(AudioPlayer()),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.aalumai.audio',
        androidNotificationChannelName: 'Music playback',
        androidNotificationChannelDescription:
            'Controls for AALUMAI music playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (_) {
    return null;
  }
}

/// One-time, best-effort startup work: seed starter data and re-arm alarms.
/// Failures are swallowed so a plugin/DB hiccup never blocks app launch.
Future<void> _bootstrap(ProviderContainer container) async {
  try {
    await container.read(financeRepositoryProvider).seedDefaultCategories();
  } catch (_) {}
  try {
    await container.read(fitnessRepositoryProvider).seedExercises();
  } catch (_) {}
  try {
    await container.read(learningRepositoryProvider).seedCourse();
  } catch (_) {}
  try {
    final notifications = container.read(notificationServiceProvider);
    await notifications.init();
    if (_notificationsEnabled(container)) {
      await notifications.requestPermissions();
    }
  } catch (_) {}
  try {
    await container.read(alarmRepositoryProvider).reconcile();
  } catch (_) {}
}

bool _notificationsEnabled(ProviderContainer container) {
  try {
    return container.read(appPreferencesProvider).notificationsEnabled;
  } catch (_) {
    return false;
  }
}
