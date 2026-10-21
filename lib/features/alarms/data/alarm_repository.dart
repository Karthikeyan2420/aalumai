import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/providers/providers.dart';
import '../../../core/services/alarm_scheduler.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/alarm_time.dart';

enum AlarmChallenge {
  none,
  math,
  memory,
  code;

  static AlarmChallenge fromIndex(int v) =>
      AlarmChallenge.values[v.clamp(0, AlarmChallenge.values.length - 1)];
}

/// An enabled alarm paired with the next time it will ring.
class UpcomingAlarm {
  const UpcomingAlarm(this.alarm, this.next);

  final Alarm alarm;
  final DateTime next;
}

/// Owns alarm persistence **and** the OS schedule lifecycle.
///
/// The repository is the single source of truth for which notifications should
/// exist: every create/update/enable/disable/delete/complete/reconcile funnels
/// through it. It depends on the [AlarmScheduler] abstraction (not the platform
/// plugin) so the rules can be unit-tested without Android.
class AlarmRepository {
  AlarmRepository(this._db, this._notifications);

  final AppDatabase _db;
  final AlarmScheduler _notifications;

  final ValueNotifier<AlarmSchedulingStatus> _status = ValueNotifier(
    const AlarmSchedulingStatus(),
  );

  /// Observable scheduling health for the alarms UI.
  ValueListenable<AlarmSchedulingStatus> get status => _status;

  AlarmSchedulingStatus get schedulingStatus => _status.value;

  void _setStatus({bool? exact, String? error, bool clearError = false}) {
    _status.value = _status.value.copyWith(
      exactAlarmsAllowed: exact,
      lastError: error,
      clearError: clearError,
    );
  }

  /// Queries (and caches) whether exact alarms are permitted right now.
  Future<bool> refreshCapability() async {
    final exact = await _notifications.canScheduleExactAlarms();
    _setStatus(exact: exact);
    return exact;
  }

  /// Opens the OS screen to grant exact-alarm access, then refreshes status.
  Future<void> requestExactAlarms() async {
    await _notifications.requestExactAlarmsPermission();
    await refreshCapability();
  }

  /// Schedules [alarm] and records any failure instead of swallowing it.
  Future<void> _schedule(Alarm alarm) async {
    try {
      await _notifications.scheduleAlarm(alarm);
      _setStatus(clearError: true);
    } catch (e) {
      _setStatus(error: e.toString());
    }
  }

  Stream<List<Alarm>> watchAll() =>
      (_db.select(_db.alarms)..orderBy([
        (t) => OrderingTerm(expression: t.hour),
        (t) => OrderingTerm(expression: t.minute),
      ])).watch();

  Future<int> create({
    required int hour,
    required int minute,
    String label = '',
    bool isEnabled = true,
    bool oneTime = false,
    int repeatDaysMask = 0,
    String soundUri = '',
    int soundStartMs = 0,
    int soundEndMs = 0,
    int volume = 100,
    bool gradualVolume = false,
    int gradientDurationSec = 30,
    int snoozeMinutes = 5,
    int maxSnoozes = 0,
    AlarmChallenge challenge = AlarmChallenge.none,
    String challengeParam = '',
    String challengeSequence = '',
    bool vibrate = true,
    int soundMode = 2,
    String message = '',
    String finalMessage = '',
    int musicIntervalSec = 10,
    int voiceTiming = 1,
    int voicePauseSec = 5,
  }) async {
    final id = await _db
        .into(_db.alarms)
        .insert(
          AlarmsCompanion.insert(
            hour: hour,
            minute: minute,
            label: Value(label),
            isEnabled: Value(isEnabled),
            oneTime: Value(oneTime && repeatDaysMask == 0),
            repeatDaysMask: Value(repeatDaysMask),
            soundUri: Value(soundUri),
            soundStartMs: Value(soundStartMs),
            soundEndMs: Value(soundEndMs),
            volume: Value(volume),
            gradualVolume: Value(gradualVolume),
            gradientDurationSec: Value(gradientDurationSec),
            snoozeMinutes: Value(snoozeMinutes),
            maxSnoozes: Value(maxSnoozes),
            challengeType: Value(
              challenge == AlarmChallenge.none ? 0 : challenge.index,
            ),
            challengeParam: Value(challengeParam),
            challengeSequence: Value(challengeSequence),
            vibrate: Value(vibrate),
            soundMode: Value(soundMode),
            message: Value(message),
            finalMessage: Value(finalMessage),
            musicIntervalSec: Value(musicIntervalSec),
            voiceTiming: Value(voiceTiming),
            voicePauseSec: Value(voicePauseSec),
          ),
        );
    final alarm = await getById(id);
    if (alarm != null && alarm.isEnabled) {
      await _schedule(alarm);
    }
    return id;
  }

  Future<Alarm?> getById(int id) =>
      (_db.select(_db.alarms)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> updateAlarm(Alarm alarm) async {
    // Editing an alarm resets its snooze streak for the current ring.
    final updated = alarm.copyWith(snoozeCount: 0);
    await _db.update(_db.alarms).replace(updated);
    await _notifications.cancelAlarm(updated.id);
    await _notifications.cancelAlarmSnooze(updated.id);
    if (updated.isEnabled) {
      await _schedule(updated);
    }
  }

  Future<void> setEnabled(int id, bool enabled) async {
    final alarm = await getById(id);
    if (alarm == null) return;
    await updateAlarm(alarm.copyWith(isEnabled: enabled, snoozeCount: 0));
  }

  /// Creates a disabled-free copy of [id] with a fresh id, ready to edit.
  Future<int?> duplicate(int id) async {
    final alarm = await getById(id);
    if (alarm == null) return null;
    return create(
      hour: alarm.hour,
      minute: alarm.minute,
      label: alarm.label,
      isEnabled: alarm.isEnabled,
      oneTime: alarm.oneTime,
      repeatDaysMask: alarm.repeatDaysMask,
      soundUri: alarm.soundUri,
      soundStartMs: alarm.soundStartMs,
      soundEndMs: alarm.soundEndMs,
      volume: alarm.volume,
      gradualVolume: alarm.gradualVolume,
      gradientDurationSec: alarm.gradientDurationSec,
      snoozeMinutes: alarm.snoozeMinutes,
      maxSnoozes: alarm.maxSnoozes,
      challenge: AlarmChallenge.fromIndex(alarm.challengeType),
      challengeParam: alarm.challengeParam,
      challengeSequence: alarm.challengeSequence,
      vibrate: alarm.vibrate,
      soundMode: alarm.soundMode,
      message: alarm.message,
      finalMessage: alarm.finalMessage,
      musicIntervalSec: alarm.musicIntervalSec,
      voiceTiming: alarm.voiceTiming,
      voicePauseSec: alarm.voicePauseSec,
    );
  }

  Future<void> delete(int id) async {
    await _notifications.cancelAlarm(id);
    await _notifications.cancelAlarmSnooze(id);
    await (_db.delete(_db.alarms)..where((t) => t.id.equals(id))).go();
  }

  /// Completes the ring once every dismissal challenge has been passed: stops
  /// the scheduled notification, clears any legacy snooze, and either disables
  /// the one-time alarm or re-arms the next occurrence of a repeating one.
  Future<void> complete(Alarm alarm) async {
    await _notifications.cancelAlarmSnooze(alarm.id);
    await _notifications.cancelAlarm(alarm.id);
    if (alarm.oneTime) {
      await (_db.update(_db.alarms)..where((t) => t.id.equals(alarm.id))).write(
        const AlarmsCompanion(isEnabled: Value(false), snoozeCount: Value(0)),
      );
    } else {
      await (_db.update(_db.alarms)..where(
        (t) => t.id.equals(alarm.id),
      )).write(const AlarmsCompanion(snoozeCount: Value(0)));
      final fresh = await getById(alarm.id);
      if (fresh != null && fresh.isEnabled) {
        await _schedule(fresh);
      }
    }
  }

  /// Cancels any pending legacy snooze notification for [alarmId].
  Future<void> cancelSnooze(int alarmId) =>
      _notifications.cancelAlarmSnooze(alarmId);

  /// Rebuilds the OS schedules from the database: cancels *every* alarm's
  /// normal slots and snoozes (including now-disabled alarms, e.g. after a
  /// restore) and re-arms only the enabled ones. This is safe to call on app
  /// start, after a reboot and after a restore, and never creates duplicates.
  Future<void> reconcile() async {
    final all = await _db.select(_db.alarms).get();
    for (final alarm in all) {
      await _notifications.cancelAlarm(alarm.id);
      await _notifications.cancelAlarmSnooze(alarm.id);
    }
    await _notifications.reconcile(all.where((a) => a.isEnabled).toList());
    _setStatus(
      error: _notifications.lastError,
      clearError: _notifications.lastError == null,
    );
    await refreshCapability();
  }

  /// The next fire time for a single alarm.
  DateTime nextRing(Alarm a, {DateTime? from}) => AlarmTime.next(
    hour: a.hour,
    minute: a.minute,
    repeatDaysMask: a.repeatDaysMask,
    from: from ?? DateTime.now(),
  );

  /// Every enabled alarm with its next ring time, soonest first.
  Future<List<UpcomingAlarm>> upcoming() async {
    final alarms =
        await (_db.select(_db.alarms)
          ..where((t) => t.isEnabled.equals(true))).get();
    final now = DateTime.now();
    final result = [
      for (final a in alarms) UpcomingAlarm(a, nextRing(a, from: now)),
    ]..sort((x, y) => x.next.compareTo(y.next));
    return result;
  }

  Future<Alarm?> nextAlarm() async {
    final list = await upcoming();
    return list.isEmpty ? null : list.first.alarm;
  }
}

final alarmRepositoryProvider = Provider<AlarmRepository>(
  (ref) => AlarmRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(notificationServiceProvider),
  ),
);

final alarmsProvider = StreamProvider<List<Alarm>>(
  (ref) => ref.watch(alarmRepositoryProvider).watchAll(),
);

final nextAlarmProvider = FutureProvider<Alarm?>((ref) async {
  ref.watch(alarmsProvider);
  return ref.watch(alarmRepositoryProvider).nextAlarm();
});

final upcomingAlarmsProvider = FutureProvider<List<UpcomingAlarm>>((ref) async {
  ref.watch(alarmsProvider);
  return ref.watch(alarmRepositoryProvider).upcoming();
});

/// Observable alarm scheduling health for the alarms screen banner.
final alarmSchedulingStatusProvider = Provider<AlarmSchedulingStatus>((ref) {
  ref.watch(alarmsProvider);
  return ref.watch(alarmRepositoryProvider).schedulingStatus;
});
