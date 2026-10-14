import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/providers/providers.dart';
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

class AlarmRepository {
  AlarmRepository(this._db, this._notifications);

  final AppDatabase _db;
  final NotificationService _notifications;

  Stream<List<Alarm>> watchAll() =>
      (_db.select(_db.alarms)
        ..orderBy([(t) => OrderingTerm(expression: t.hour)])).watch();

  Future<int> create({
    required int hour,
    required int minute,
    String label = '',
    bool isEnabled = true,
    int repeatDaysMask = 0,
    String soundUri = '',
    int soundStartMs = 0,
    int soundEndMs = 0,
    bool gradualVolume = false,
    int gradientDurationSec = 30,
    int snoozeMinutes = 5,
    AlarmChallenge challenge = AlarmChallenge.none,
    String challengeParam = '',
    bool vibrate = true,
  }) async {
    final id = await _db
        .into(_db.alarms)
        .insert(
          AlarmsCompanion.insert(
            hour: hour,
            minute: minute,
            label: Value(label),
            isEnabled: Value(isEnabled),
            repeatDaysMask: Value(repeatDaysMask),
            soundUri: Value(soundUri),
            soundStartMs: Value(soundStartMs),
            soundEndMs: Value(soundEndMs),
            gradualVolume: Value(gradualVolume),
            gradientDurationSec: Value(gradientDurationSec),
            snoozeMinutes: Value(snoozeMinutes),
            challengeType: Value(challenge.index),
            challengeParam: Value(challengeParam),
            vibrate: Value(vibrate),
          ),
        );
    final alarm = await getById(id);
    if (alarm != null && alarm.isEnabled) {
      await _notifications.scheduleAlarm(alarm);
    }
    return id;
  }

  Future<Alarm?> getById(int id) =>
      (_db.select(_db.alarms)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> updateAlarm(Alarm alarm) async {
    await _db.update(_db.alarms).replace(alarm);
    await _notifications.cancelAlarm(alarm.id);
    if (alarm.isEnabled) {
      await _notifications.scheduleAlarm(alarm);
    }
  }

  Future<void> setEnabled(int id, bool enabled) async {
    final alarm = await getById(id);
    if (alarm == null) return;
    await updateAlarm(alarm.copyWith(isEnabled: enabled));
  }

  Future<void> delete(int id) async {
    await _notifications.cancelAlarm(id);
    await (_db.delete(_db.alarms)..where((t) => t.id.equals(id))).go();
  }

  /// Re-schedules all enabled alarms. Call after reboot / time-zone changes
  /// (see AndroidManifest receivers) or on app start.
  Future<void> reconcile() async {
    final alarms =
        await (_db.select(_db.alarms)
          ..where((t) => t.isEnabled.equals(true))).get();
    await _notifications.reconcile(alarms);
  }

  Future<Alarm?> nextAlarm() async {
    final alarms =
        await (_db.select(_db.alarms)
          ..where((t) => t.isEnabled.equals(true))).get();
    Alarm? best;
    DateTime? bestTime;
    final now = DateTime.now();
    for (final a in alarms) {
      final t = AlarmTime.next(
        hour: a.hour,
        minute: a.minute,
        repeatDaysMask: a.repeatDaysMask,
        from: now,
      );
      if (bestTime == null || t.isBefore(bestTime)) {
        bestTime = t;
        best = a;
      }
    }
    return best;
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
