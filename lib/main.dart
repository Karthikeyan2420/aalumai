import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/providers/providers.dart';
import 'core/router/navigator_key.dart';
import 'core/services/alarm_trigger_channel.dart';
import 'core/services/notification_service.dart';
import 'features/alarms/alarm_ringing_screen.dart';
import 'features/alarms/data/alarm_repository.dart';
import 'features/alarms/data/alarm_voice_settings.dart';
import 'features/alarms/ringing_coordinator.dart';
import 'features/expenses/data/finance_repository.dart';
import 'features/fitness/data/fitness_repository.dart';
import 'features/habits/data/habit_repository.dart';
import 'features/jarvis/data/briefing_scheduler.dart';
import 'features/learning/data/learning_repository.dart';
import 'features/music/data/player_service.dart';
import 'features/schedule/data/event_repository.dart';
import 'features/tasks/data/task_repository.dart';

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

  // Ask for notification / exact-alarm permission only after the first frame so
  // the plugin has an attached Activity. Requesting during [_bootstrap] (before
  // the UI exists) makes flutter_local_notifications dereference a null Context.
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => _requestPermissions(container),
  );
}

/// Best-effort notification permission prompt, run once the UI is mounted.
Future<void> _requestPermissions(ProviderContainer container) async {
  try {
    if (_notificationsEnabled(container)) {
      await container.read(notificationServiceProvider).requestPermissions();
    }
  } catch (_) {}
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
    await container.read(fitnessRepositoryProvider).seedStarterPlans();
  } catch (_) {}
  try {
    await container.read(learningRepositoryProvider).seedCourse();
  } catch (_) {}
  try {
    final notifications = container.read(notificationServiceProvider);
    notifications.onAlarmNotificationTap =
        (alarmId) => _openAlarm(container, alarmId);
    notifications.voiceSettingsResolver = () => _nativeVoiceSettings(container);
    // The native ring service can surface the ringing screen on its own: while
    // the device is unlocked Android suppresses the full-screen intent, so this
    // in-app event is what makes the alarm UI appear automatically.
    AlarmTriggerChannel.onRingStarted =
        (alarmId) => _openAlarm(container, alarmId);
    AlarmTriggerChannel.onOpenAlarm =
        (alarmId) => _openAlarm(container, alarmId);
    AlarmTriggerChannel.ensureListening();
    await notifications.init();
  } catch (_) {}
  try {
    // A cold start from the alarm notification carries the alarm id natively;
    // surface the ringing screen once the navigator is mounted.
    final pending = await AlarmTriggerChannel.takePendingOpenAlarm();
    if (pending != null) _openAlarm(container, pending);
  } catch (_) {}
  try {
    await container.read(alarmRepositoryProvider).reconcile();
  } catch (_) {}
  try {
    await container.read(taskRepositoryProvider).reconcileReminders();
  } catch (_) {}
  try {
    await container.read(habitRepositoryProvider).reconcileReminders();
  } catch (_) {}
  try {
    await container.read(eventRepositoryProvider).reconcileReminders();
  } catch (_) {}
  try {
    await reconcileDailyBriefing(
      reminders: container.read(notificationServiceProvider),
      prefs: container.read(appPreferencesProvider),
      tasks: container.read(taskRepositoryProvider),
      events: container.read(eventRepositoryProvider),
      alarms: container.read(alarmRepositoryProvider),
    );
  } catch (_) {}
}

bool _notificationsEnabled(ProviderContainer container) {
  try {
    return container.read(appPreferencesProvider).notificationsEnabled;
  } catch (_) {
    return false;
  }
}

/// Global voice preferences for native alarm payloads.
///
/// An explicit voice language wins, then the in-app interface language, and an
/// empty value tells the platform to use the device locale — which is what
/// "follow the app language" means when the app itself follows the system.
NativeVoiceSettings _nativeVoiceSettings(ProviderContainer container) {
  try {
    final settings = container.read(alarmVoiceSettingsProvider);
    final locale = container.read(appPreferencesProvider).localeCode;
    final language =
        settings.followsAppLanguage
            ? (locale ?? '')
            : (settings.languageCode ?? '');
    return NativeVoiceSettings(
      languageCode: language,
      voiceName: settings.voiceName ?? '',
      rate: settings.rate,
      pitch: settings.pitch,
      volume: settings.volume,
    );
  } catch (_) {
    return const NativeVoiceSettings();
  }
}

/// Serialises ringing screens so a full-screen intent plus a notification tap
/// (or a cold-start launch) cannot stack two identical rings.
final RingingCoordinator _ringing = RingingCoordinator();

/// Surfaces the ringing screen for [alarmId]. Called when the user taps an
/// alarm notification. The navigator may not be mounted yet (cold start), so
/// the push is deferred to the next frame, retrying a bounded number of times.
void _openAlarm(ProviderContainer container, int alarmId, [int attempt = 0]) {
  Future<void> show() async {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) {
      debugPrint(
        'ALARMDBG openAlarm($alarmId) navigator=null attempt=$attempt',
      );
      if (attempt < 20) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _openAlarm(container, alarmId, attempt + 1),
        );
      }
      return;
    }
    // Claim the ring only once the navigator is ready; a duplicate delivery for
    // the same alarm is ignored while it is still ringing.
    final claimed = _ringing.tryAcquire(alarmId);
    debugPrint('ALARMDBG openAlarm($alarmId) navigator=ok claimed=$claimed');
    if (!claimed) return;
    try {
      final alarm = await container
          .read(alarmRepositoryProvider)
          .getById(alarmId);
      debugPrint('ALARMDBG openAlarm($alarmId) found=${alarm?.id}');
      if (alarm == null) return;
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => AlarmRingingScreen(alarm: alarm),
        ),
      );
    } catch (e) {
      debugPrint('ALARMDBG openAlarm($alarmId) failed: $e');
    } finally {
      _ringing.release(alarmId);
    }
  }

  show();
}
