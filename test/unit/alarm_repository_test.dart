import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/core/services/alarm_scheduler.dart';
import 'package:aalumai/features/alarms/data/alarm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeScheduler implements AlarmScheduler {
  final List<int> cancelled = [];
  final List<Alarm> scheduled = [];

  @override
  String? get lastError => null;

  @override
  Future<bool> canScheduleExactAlarms() async => true;

  @override
  Future<void> requestExactAlarmsPermission() async {}

  @override
  Future<void> scheduleAlarm(Alarm alarm) async => scheduled.add(alarm);

  @override
  Future<void> cancelAlarm(int alarmId) async => cancelled.add(alarmId);

  @override
  Future<void> cancelAlarmSnooze(int alarmId) async {}

  @override
  Future<void> reconcile(List<Alarm> alarms) async {}
}

void main() {
  late AppDatabase db;
  late _FakeScheduler scheduler;
  late AlarmRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    scheduler = _FakeScheduler();
    repo = AlarmRepository(db, scheduler);
  });

  tearDown(() => db.close());

  test('completing a repeating alarm re-arms the next occurrence', () async {
    final id = await repo.create(
      hour: 7,
      minute: 30,
      repeatDaysMask: 0x1F,
      challengeSequence: 'math',
    );
    final alarm = (await repo.getById(id))!;
    expect(alarm.oneTime, isFalse);

    scheduler.scheduled.clear();
    scheduler.cancelled.clear();
    await repo.complete(alarm);

    // The current ring is cancelled, then the alarm is re-armed for next time.
    expect(scheduler.cancelled, contains(id));
    expect(scheduler.scheduled.map((a) => a.id), contains(id));

    final after = (await repo.getById(id))!;
    expect(after.isEnabled, isTrue, reason: 'repeating alarms stay enabled');
  });

  test('completing a one-time alarm disables it and does not re-arm', () async {
    final id = await repo.create(
      hour: 7,
      minute: 30,
      oneTime: true,
      challengeSequence: 'math',
    );
    final alarm = (await repo.getById(id))!;
    expect(alarm.oneTime, isTrue);

    scheduler.scheduled.clear();
    await repo.complete(alarm);

    expect(scheduler.scheduled, isEmpty);
    final after = (await repo.getById(id))!;
    expect(after.isEnabled, isFalse);
  });

  test('editing an alarm reschedules it with the new time', () async {
    final id = await repo.create(
      hour: 6,
      minute: 15,
      challengeSequence: 'math',
    );
    scheduler.scheduled.clear();

    final alarm = (await repo.getById(id))!;
    await repo.updateAlarm(alarm.copyWith(hour: 8, minute: 45));

    expect(scheduler.scheduled.map((a) => a.hour), contains(8));
    expect(scheduler.scheduled.map((a) => a.minute), contains(45));
  });
}
