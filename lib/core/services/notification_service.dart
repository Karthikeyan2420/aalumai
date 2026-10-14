import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../db/database.dart';
import '../utils/alarm_time.dart';

/// Wraps local notification / alarm scheduling.
///
/// All calls are best-effort: on platforms without a native implementation
/// (or when permissions are denied) the methods throw
/// [MissingPluginException]/[PlatformException], which callers catch so the UI
/// can surface an honest message instead of crashing.
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const _alarmChannel = AndroidNotificationChannel(
    'aalumai_alarms',
    'Alarms',
    description: 'Alarm and reminder notifications',
    importance: Importance.max,
    playSound: true,
  );

  static const _reminderChannel = AndroidNotificationChannel(
    'aalumai_reminders',
    'Reminders',
    description: 'Task, habit and event reminders',
    importance: Importance.high,
  );

  bool get isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

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
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    if (!isSupportedPlatform) return false;
    try {
      final android =
          _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      final notif = await android?.requestNotificationsPermission() ?? false;
      await android?.requestExactAlarmsPermission();
      return notif;
    } catch (_) {
      return false;
    }
  }

  Future<bool> canScheduleExactAlarms() async {
    if (!isSupportedPlatform) return false;
    try {
      final android =
          _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      return await android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  int _idFor(int alarmId, int weekday) => alarmId * 10 + weekday;

  /// (Re)schedules every enabled alarm. Called on app start and after system
  /// events such as reboot / time-zone changes.
  Future<void> reconcile(List<Alarm> alarms) async {
    if (!isSupportedPlatform) return;
    await init();
    try {
      await _plugin.cancelAll();
    } catch (_) {}
    for (final alarm in alarms.where((a) => a.isEnabled)) {
      await scheduleAlarm(alarm);
    }
  }

  Future<void> scheduleAlarm(Alarm alarm) async {
    if (!isSupportedPlatform) return;
    await init();
    final weekdays = AlarmTime.weekdays(alarm.repeatDaysMask);
    final isDaily = alarm.repeatDaysMask == 0;
    for (final weekday in weekdays) {
      final id = isDaily ? _idFor(alarm.id, 0) : _idFor(alarm.id, weekday);
      final next = AlarmTime.next(
        hour: alarm.hour,
        minute: alarm.minute,
        repeatDaysMask: isDaily ? 0 : (1 << (weekday - 1)),
        from: DateTime.now(),
      );
      try {
        await _plugin.zonedSchedule(
          id,
          alarm.label.isEmpty ? 'AALUMAI' : alarm.label,
          AlarmTime.format(alarm.hour, alarm.minute),
          tz.TZDateTime.from(next, tz.local),
          NotificationDetails(
            android: AndroidNotificationDetails(
              _alarmChannel.id,
              _alarmChannel.name,
              channelDescription: _alarmChannel.description,
              importance: Importance.max,
              priority: Priority.high,
              fullScreenIntent: true,
              category: AndroidNotificationCategory.alarm,
              ongoing: true,
              autoCancel: false,
            ),
            iOS: const DarwinNotificationDetails(
              interruptionLevel: InterruptionLevel.critical,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents:
              isDaily
                  ? DateTimeComponents.time
                  : DateTimeComponents.dayOfWeekAndTime,
        );
      } catch (e) {
        debugPrint('Failed to schedule alarm ${alarm.id}/$weekday: $e');
      }
    }
  }

  Future<void> cancelAlarm(int alarmId) async {
    if (!isSupportedPlatform) return;
    await init();
    for (var i = 0; i <= 7; i++) {
      try {
        await _plugin.cancel(_idFor(alarmId, i));
      } catch (_) {}
    }
  }

  /// Schedules a one-off reminder used by tasks, habits and events.
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
