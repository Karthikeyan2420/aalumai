import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../db/database.dart';
import '../utils/alarm_time.dart';
import '../../features/alarms/alarm_playback.dart';
import 'alarm_trigger_channel.dart';
import 'alarm_scheduler.dart';
import 'reminder_notifier.dart';

/// Wraps local notification / alarm scheduling.
///
/// Implements [AlarmScheduler] (alarms) and [ReminderNotifier] (task, habit and
/// event reminders). Notes:
///
/// * Alarm notifications are **silent** and only act as the trigger (full-screen
///   intent + vibration). The continuous, looping alarm tone is played by the
///   in-app `AlarmAudio` player on the Android alarm stream, so a notification
///   sound can never cut the ring short or compete with it. The channels are
///   versioned (`..._v2`) because Android 8+ binds a channel's sound/vibration
///   at creation time; bumping the version guarantees existing installs pick up
///   the new silent behaviour. The old channels are left untouched so any user
///   customisation of them is preserved; the app simply stops using them.
/// * When an exact alarm cannot be scheduled (Android 12+ and the permission is
///   denied) the request is transparently retried as an inexact alarm and the
///   condition is surfaced through [canScheduleExactAlarms].
/// * Real failures are recorded in [lastError] and rethrown so callers can show
///   an actionable message.
class NotificationService implements AlarmScheduler, ReminderNotifier {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  /// Cached result of the exact-alarm capability check. `null` until known.
  bool? _exactAllowed;
  String? _lastError;

  @override
  String? get lastError => _lastError;

  /// Invoked when the user taps an alarm (or snooze) notification, with the
  /// alarm id. Set before [init] is first called.
  void Function(int alarmId)? onAlarmNotificationTap;

  /// Supplies the global voice preferences used to build native trigger
  /// payloads. Wired once from `main.dart`, because scheduling runs outside the
  /// widget tree where the settings providers would otherwise be unreachable.
  /// When unset the platform falls back to its own defaults.
  NativeVoiceSettings Function()? voiceSettingsResolver;

  static const _reminderChannel = AndroidNotificationChannel(
    'aalumai_reminders',
    'Reminders',
    description: 'Task, habit and event reminders',
    importance: Importance.high,
  );

  bool get isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

  Future<void> init() async {
    if (_initialized) return;
    try {
      tzdata.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone));
    } catch (_) {
      // Fall back to UTC if the platform timezone cannot be read.
      tzdata.initializeTimeZones();
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(
      android: android,
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse:
          (response) => _dispatchPayload(response.payload),
    );
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _dispatchPayload(launch!.notificationResponse?.payload);
      }
    } catch (_) {
      // Launch details are unavailable on some platforms; ignore.
    }
    await _ensureAlarmChannels();
    _initialized = true;
  }

  /// Stable, silent alarm channels (one vibrating, one not). The tone itself is
  /// played by the in-app player, so the notification never carries a sound.
  static const _alarmChannelVibrate = 'aalumai_alarm_ring_v2_vibrate';
  static const _alarmChannelSilent = 'aalumai_alarm_ring_v2_silent';

  /// Creates the silent alarm channels up front so they are stable before the
  /// first alarm fires.
  Future<void> _ensureAlarmChannels() async {
    final android = _android;
    if (android == null) return;
    for (final vibrate in const [true, false]) {
      try {
        await android.createNotificationChannel(_alarmChannel(vibrate));
      } catch (_) {
        // Channel creation is best-effort; scheduling still creates it.
      }
    }
  }

  AndroidNotificationChannel _alarmChannel(bool vibrate) {
    return AndroidNotificationChannel(
      _channelId(vibrate),
      'Alarm',
      description: 'Full-screen alarm with in-app continuous sound',
      importance: Importance.max,
      playSound: false,
      sound: null,
      enableVibration: vibrate,
      vibrationPattern: vibrate ? Int64List.fromList(_vibrationPattern) : null,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );
  }

  static String _channelId(bool vibrate) =>
      vibrate ? _alarmChannelVibrate : _alarmChannelSilent;

  /// A firm but steady "wake up" pulse (ms: wait, vibrate, wait, …). Only used
  /// by the silent channel as a fallback alert; the continuous vibration runs
  /// in-app alongside the looping tone.
  static const List<int> _vibrationPattern = [0, 800, 400, 800, 400, 800];

  String _channelIdFor(Alarm alarm) => _channelId(alarm.vibrate);

  /// Parses an alarm id out of a notification payload. Exposed for testing and
  /// reused by cold-start launch handling.
  static int? alarmIdFromPayload(String? payload) =>
      int.tryParse(payload ?? '');

  void _dispatchPayload(String? payload) {
    final id = alarmIdFromPayload(payload);
    if (id != null) onAlarmNotificationTap?.call(id);
  }

  Future<bool> requestPermissions() async {
    if (!isSupportedPlatform) return false;
    try {
      final notif = await _android?.requestNotificationsPermission() ?? false;
      await _android?.requestExactAlarmsPermission();
      await _android?.requestFullScreenIntentPermission();
      _exactAllowed = null;
      return notif;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> canScheduleExactAlarms() async {
    if (!isSupportedPlatform) return false;
    if (!Platform.isAndroid) return true;
    try {
      final value = await _android?.canScheduleExactNotifications();
      _exactAllowed = value ?? _exactAllowed;
      return value ?? false;
    } catch (_) {
      return _exactAllowed ?? false;
    }
  }

  @override
  Future<void> requestExactAlarmsPermission() async {
    if (!isSupportedPlatform || !Platform.isAndroid) return;
    try {
      await _android?.requestExactAlarmsPermission();
    } catch (_) {}
    _exactAllowed = null;
  }

  /// Notification details shared by alarm rings: a **silent** alarm channel, a
  /// full-screen intent (so the ringing activity can launch over the lock
  /// screen where the OS allows it) and the alarm audio usage. The tone is
  /// played by `AlarmAudio` in-app; keeping the notification silent stops a
  /// short one-shot notification sound from cutting the looping ring short.
  NotificationDetails _alarmDetails(Alarm alarm) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelIdFor(alarm),
        'Alarm',
        channelDescription: 'Full-screen alarm with in-app continuous sound',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        visibility: NotificationVisibility.public,
        ongoing: true,
        autoCancel: false,
        playSound: false,
        enableVibration: alarm.vibrate,
        vibrationPattern:
            alarm.vibrate ? Int64List.fromList(_vibrationPattern) : null,
        ticker: 'alarm',
      ),
      iOS: const DarwinNotificationDetails(
        interruptionLevel: InterruptionLevel.critical,
      ),
    );
  }

  /// Schedules a single notification, falling back to inexact scheduling when
  /// Android denies exact alarms. Rethrows genuine failures so the caller can
  /// surface them.
  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required NotificationDetails details,
    required String payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    Future<void> attempt(AndroidScheduleMode mode) => _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      details,
      androidScheduleMode: mode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: matchDateTimeComponents,
      payload: payload,
    );

    final preferExact = _exactAllowed != false;
    try {
      await attempt(
        preferExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
      if (preferExact) _exactAllowed = true;
      _lastError = null;
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted' && preferExact) {
        // Permission denied: retry inexactly rather than losing the alarm.
        _exactAllowed = false;
        await attempt(AndroidScheduleMode.inexactAllowWhileIdle);
        _lastError = null;
        return;
      }
      _lastError = e.message ?? e.code;
      rethrow;
    }
  }

  /// Schedules an enabled alarm from the pure [AlarmPlanner] plan, cancelling
  /// any obsolete slots so editing repeat days can never leave a stale ring.
  @override
  Future<void> scheduleAlarm(Alarm alarm) async {
    if (!isSupportedPlatform) return;
    await init();

    final requests = AlarmPlanner.plan(alarm, from: DateTime.now());
    for (final obsolete in AlarmPlanner.obsoleteSlotIds(alarm.id, requests)) {
      try {
        await _plugin.cancel(obsolete);
      } catch (_) {}
    }

    for (final request in requests) {
      await _schedule(
        id: request.notificationId,
        title: alarm.label.isEmpty ? 'AALUMAI' : alarm.label,
        body: AlarmTime.format(alarm.hour, alarm.minute),
        when: tz.TZDateTime.from(request.when, tz.local),
        details: _alarmDetails(alarm),
        payload: alarm.id.toString(),
        matchDateTimeComponents: switch (request.repeat) {
          AlarmRepeat.once => null,
          AlarmRepeat.daily => DateTimeComponents.time,
          AlarmRepeat.weekly => DateTimeComponents.dayOfWeekAndTime,
        },
      );
    }

    // Mirror the exact same slots into AlarmManager so the ring service can
    // produce sound when the alarm fires without a running Flutter engine.
    // Derived from the same [requests] as the notifications above, so the two
    // can never drift apart; best-effort, because a missing channel must never
    // be able to fail an alarm.
    await AlarmTriggerChannel.syncAlarm(
      alarm.id,
      _triggerSlots(alarm, requests),
    );
  }

  /// Native trigger payloads for every slot of [alarm] in [requests].
  List<AlarmTriggerSlot> _triggerSlots(
    Alarm alarm,
    List<AlarmScheduleRequest> requests,
  ) {
    final voice = voiceSettingsResolver?.call() ?? const NativeVoiceSettings();
    final mode = AlarmSoundMode.fromIndex(alarm.soundMode).name;
    final timing = VoiceTiming.fromIndex(alarm.voiceTiming).name;
    return [
      for (final request in requests)
        AlarmTriggerSlot(
          slotId: request.notificationId,
          alarmId: alarm.id,
          triggerAtMs: request.when.millisecondsSinceEpoch,
          soundUri: alarm.soundUri,
          volume: alarm.volume,
          vibrate: alarm.vibrate,
          mode: mode,
          message: alarm.message,
          musicIntervalSec: alarm.musicIntervalSec,
          voicePauseSec: alarm.voicePauseSec,
          voiceTiming: timing,
          languageCode: voice.languageCode,
          voiceName: voice.voiceName,
          speechRate: voice.rate,
          speechPitch: voice.pitch,
          speechVolume: voice.volume,
          label: alarm.label,
          hour: alarm.hour,
          minute: alarm.minute,
          repeat: switch (request.repeat) {
            AlarmRepeat.once => 'once',
            AlarmRepeat.daily => 'daily',
            AlarmRepeat.weekly => 'weekly',
          },
          weekday: request.weekday ?? 0,
        ),
    ];
  }

  /// Cancels a pending (legacy) snooze notification for [alarmId].
  @override
  Future<void> cancelAlarmSnooze(int alarmId) async {
    if (!isSupportedPlatform) return;
    await init();
    try {
      await _plugin.cancel(AlarmPlanner.snoozeId(alarmId));
    } catch (_) {}
  }

  @override
  Future<void> cancelAlarm(int alarmId) async {
    // Always dropped natively too, even when notifications are unsupported, so
    // a stale trigger can never outlive the alarm that armed it.
    await AlarmTriggerChannel.cancelAlarm(alarmId);
    if (!isSupportedPlatform) return;
    await init();
    for (final id in AlarmPlanner.allSlotIds(alarmId)) {
      try {
        await _plugin.cancel(id);
      } catch (_) {}
    }
  }

  /// Re-schedules every enabled alarm. Best-effort per alarm so one failure
  /// cannot prevent the others from being armed; failures are recorded in
  /// [lastError].
  @override
  Future<void> reconcile(List<Alarm> alarms) async {
    if (!isSupportedPlatform) return;
    await init();
    _lastError = null;
    for (final alarm in alarms.where((a) => a.isEnabled)) {
      try {
        await scheduleAlarm(alarm);
      } catch (e) {
        _lastError = e.toString();
        debugPrint('Failed to reconcile alarm ${alarm.id}: $e');
      }
    }
  }

  /// Schedules a one-off reminder used by tasks and events.
  @override
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    if (!isSupportedPlatform || when.isBefore(DateTime.now())) return;
    await init();
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(when, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _reminderChannel.id,
            _reminderChannel.name,
            channelDescription: _reminderChannel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Failed to schedule reminder $id: $e');
    }
  }

  /// Schedules a reminder that repeats daily, or weekly on [weekday]
  /// (1 = Monday … 7 = Sunday) when supplied. Used by habit reminders.
  @override
  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    int? weekday,
  }) async {
    if (!isSupportedPlatform) return;
    await init();
    try {
      final now = tz.TZDateTime.now(tz.local);
      var first = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (!first.isAfter(now)) {
        first = first.add(const Duration(days: 1));
      }
      if (weekday != null) {
        var guard = 0;
        while (first.weekday != weekday && guard < 14) {
          first = first.add(const Duration(days: 1));
          guard++;
        }
      }
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        first,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _reminderChannel.id,
            _reminderChannel.name,
            channelDescription: _reminderChannel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents:
            weekday == null
                ? DateTimeComponents.time
                : DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (e) {
      debugPrint('Failed to schedule daily reminder $id: $e');
    }
  }

  @override
  Future<void> cancel(int id) async {
    if (!isSupportedPlatform) return;
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }
}

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);
