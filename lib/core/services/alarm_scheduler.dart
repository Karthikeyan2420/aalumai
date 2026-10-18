import 'package:flutter/foundation.dart';

import '../db/database.dart';
import '../utils/alarm_time.dart';

/// How a scheduled alarm repeats once it has fired.
enum AlarmRepeat {
  /// Fires exactly once and is not rescheduled by the OS.
  once,

  /// Fires every day at the same local time.
  daily,

  /// Fires every week on a specific weekday.
  weekly,
}

/// A single OS-level schedule an enabled alarm requires.
///
/// [notificationId] is **stable** for a given alarm slot, so re-scheduling the
/// same alarm always overwrites the same entry instead of stacking duplicates.
@immutable
class AlarmScheduleRequest {
  const AlarmScheduleRequest({
    required this.notificationId,
    required this.when,
    required this.repeat,
    this.weekday,
  });

  final int notificationId;
  final DateTime when;
  final AlarmRepeat repeat;

  /// ISO weekday (1 = Monday … 7 = Sunday) for [AlarmRepeat.weekly].
  final int? weekday;

  @override
  bool operator ==(Object other) =>
      other is AlarmScheduleRequest &&
      other.notificationId == notificationId &&
      other.when == when &&
      other.repeat == repeat &&
      other.weekday == weekday;

  @override
  int get hashCode => Object.hash(notificationId, when, repeat, weekday);

  @override
  String toString() =>
      'AlarmScheduleRequest(id: $notificationId, when: $when, '
      'repeat: ${repeat.name}, weekday: $weekday)';
}

/// Pure, plugin-free calculation of *which* notifications an alarm needs.
///
/// Keeping this separate from the platform plugin means the scheduling rules
/// (one-time, daily, selected weekdays, obsolete-slot cancellation) can be
/// unit-tested without Android hardware.
class AlarmPlanner {
  const AlarmPlanner._();

  /// Slot 0 is used by one-time and daily alarms; slots 1..7 map to the seven
  /// ISO weekdays. Slot 8 is reserved so the range stays dense.
  static const int slotCount = 8;

  /// Id base for one-off snooze notifications; kept well clear of the alarm
  /// slot range so a snooze can never collide with a normal schedule.
  static const int snoozeBase = 4000000;

  static const Map<String, String> soundRawResources = {
    'classic': 'alarm_classic',
    'gentle': 'alarm_gentle',
    'urgent': 'alarm_urgent',
  };

  static const String defaultSoundId = 'classic';

  /// Stable notification id for [alarmId] in [slot] (0..7).
  static int slotId(int alarmId, int slot) => alarmId * 10 + slot;

  /// Stable notification id for a pending snooze of [alarmId].
  static int snoozeId(int alarmId) => snoozeBase + alarmId;

  /// Every notification id an alarm could ever own, used to cancel obsolete
  /// schedules when an alarm is edited or disabled.
  static List<int> allSlotIds(int alarmId) => [
    for (var slot = 0; slot < slotCount; slot++) slotId(alarmId, slot),
  ];

  /// The schedules required for [alarm] starting from [from].
  ///
  /// * one-time (mask 0 + [Alarm.oneTime]) → a single future occurrence;
  /// * daily (mask 0) → exactly one repeating entry (never seven duplicates);
  /// * selected weekdays → one repeating entry per selected day, each with its
  ///   own stable id.
  static List<AlarmScheduleRequest> plan(
    Alarm alarm, {
    required DateTime from,
  }) {
    if (alarm.repeatDaysMask == 0) {
      return [
        AlarmScheduleRequest(
          notificationId: slotId(alarm.id, 0),
          when: AlarmTime.next(
            hour: alarm.hour,
            minute: alarm.minute,
            repeatDaysMask: 0,
            from: from,
          ),
          repeat: alarm.oneTime ? AlarmRepeat.once : AlarmRepeat.daily,
        ),
      ];
    }

    return [
      for (final weekday in AlarmTime.weekdays(alarm.repeatDaysMask))
        AlarmScheduleRequest(
          notificationId: slotId(alarm.id, weekday),
          when: AlarmTime.next(
            hour: alarm.hour,
            minute: alarm.minute,
            repeatDaysMask: 1 << (weekday - 1),
            from: from,
          ),
          repeat: AlarmRepeat.weekly,
          weekday: weekday,
        ),
    ];
  }

  /// Slot ids that are no longer required by [requests] and must be cancelled.
  static List<int> obsoleteSlotIds(
    int alarmId,
    List<AlarmScheduleRequest> requests,
  ) {
    final keep = {for (final r in requests) r.notificationId};
    return [
      for (final id in allSlotIds(alarmId))
        if (!keep.contains(id)) id,
    ];
  }

  /// Maps a persisted `soundUri` to its bundled Android raw resource name, or
  /// `null` for the system default / unknown sounds (which fall back to the
  /// platform default notification tone).
  static String? rawSoundFor(String soundUri) =>
      soundRawResources[soundUri] ??
      (soundUri == 'system' ? null : soundRawResources[defaultSoundId]);

  /// The channel key (without the vibration suffix) for [soundUri].
  static String soundKey(String soundUri) =>
      soundUri == 'system'
          ? 'system'
          : soundRawResources[soundUri] != null
          ? soundUri
          : defaultSoundId;
}

/// A user-facing snapshot of alarm scheduling health, shown in the alarms UI.
@immutable
class AlarmSchedulingStatus {
  const AlarmSchedulingStatus({this.exactAlarmsAllowed, this.lastError});

  /// Whether the OS allows exact alarms. `null` until first queried.
  final bool? exactAlarmsAllowed;

  /// The most recent scheduling failure, or `null` when the last operation
  /// succeeded.
  final String? lastError;

  AlarmSchedulingStatus copyWith({
    bool? exactAlarmsAllowed,
    String? lastError,
    bool clearError = false,
  }) => AlarmSchedulingStatus(
    exactAlarmsAllowed: exactAlarmsAllowed ?? this.exactAlarmsAllowed,
    lastError: clearError ? null : (lastError ?? this.lastError),
  );

  @override
  bool operator ==(Object other) =>
      other is AlarmSchedulingStatus &&
      other.exactAlarmsAllowed == exactAlarmsAllowed &&
      other.lastError == lastError;

  @override
  int get hashCode => Object.hash(exactAlarmsAllowed, lastError);
}

/// Abstraction over the platform alarm backend. Implemented by
/// `NotificationService` and faked in tests so repository logic (scheduling,
/// completion, reconciliation) is verifiable without Android.
abstract class AlarmScheduler {
  /// The most recent scheduling failure, or `null` if the last attempt
  /// succeeded. Lets the UI surface a problem instead of silently swallowing it.
  String? get lastError;

  /// Whether the OS currently permits exact alarms (always true below
  /// Android 12 / on non-Android platforms).
  Future<bool> canScheduleExactAlarms();

  /// Opens the system screen that lets the user grant exact-alarm access.
  Future<void> requestExactAlarmsPermission();

  /// (Re)schedules [alarm], cancelling any obsolete slots first.
  Future<void> scheduleAlarm(Alarm alarm);

  /// Cancels every normal schedule slot of [alarmId].
  Future<void> cancelAlarm(int alarmId);

  /// Cancels the pending snooze notification of [alarmId].
  Future<void> cancelAlarmSnooze(int alarmId);

  /// Reconciles the OS schedules against [alarms] (the enabled set).
  Future<void> reconcile(List<Alarm> alarms);
}
