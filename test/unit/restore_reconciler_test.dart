import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/core/services/alarm_scheduler.dart';
import 'package:aalumai/core/services/reminder_notifier.dart';
import 'package:aalumai/core/services/reminder_scheduler.dart';
import 'package:aalumai/core/services/restore_reconciler.dart';
import 'package:aalumai/core/utils/recurrence.dart';
import 'package:aalumai/features/alarms/data/alarm_repository.dart';
import 'package:aalumai/features/habits/data/habit_repository.dart';
import 'package:aalumai/features/habits/domain/habit_streak.dart';
import 'package:aalumai/features/schedule/data/event_repository.dart';
import 'package:aalumai/features/tasks/data/task_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAlarmScheduler implements AlarmScheduler {
  _FakeAlarmScheduler({this.failSchedule = false});

  final bool failSchedule;
  final failCancelIds = <int>{};
  final cancelled = <int>[];
  final snoozeCancelled = <int>[];
  final scheduled = <Alarm>[];

  @override
  String? lastError;

  @override
  Future<bool> canScheduleExactAlarms() async => true;

  @override
  Future<void> requestExactAlarmsPermission() async {}

  @override
  Future<void> scheduleAlarm(Alarm alarm) async {
    if (failSchedule) {
      lastError = 'exact_alarms_not_permitted';
      throw Exception('exact_alarms_not_permitted');
    }
    scheduled.add(alarm);
  }

  @override
  Future<void> cancelAlarm(int alarmId) async {
    if (failCancelIds.contains(alarmId)) {
      throw Exception('cancel failed');
    }
    cancelled.add(alarmId);
  }

  @override
  Future<void> cancelAlarmSnooze(int alarmId) async =>
      snoozeCancelled.add(alarmId);

  @override
  Future<void> reconcile(List<Alarm> alarms) async {
    lastError = null;
    for (final alarm in alarms.where((a) => a.isEnabled)) {
      try {
        await scheduleAlarm(alarm);
      } catch (e) {
        lastError = e.toString();
      }
    }
  }
}

class _OneOff {
  const _OneOff(this.id, this.when);
  final int id;
  final DateTime when;
}

class _Daily {
  const _Daily(this.id, this.weekday);
  final int id;
  final int? weekday;
}

class _FakeNotifier implements ReminderNotifier {
  final oneOff = <_OneOff>[];
  final daily = <_Daily>[];
  final cancelled = <int>[];
  bool failCancel = false;

  @override
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    oneOff.add(_OneOff(id, when));
  }

  @override
  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    int? weekday,
  }) async {
    daily.add(_Daily(id, weekday));
  }

  @override
  Future<void> cancel(int id) async {
    if (failCancel) throw Exception('reminder cancel failed');
    cancelled.add(id);
  }
}

void main() {
  late AppDatabase db;
  late _FakeAlarmScheduler alarmScheduler;
  late _FakeNotifier notifier;
  late ReminderScheduler reminders;
  late AlarmRepository alarmRepo;
  late TaskRepository taskRepo;
  late HabitRepository habitRepo;
  late EventRepository eventRepo;

  void build({bool failSchedule = false}) {
    alarmScheduler = _FakeAlarmScheduler(failSchedule: failSchedule);
    notifier = _FakeNotifier();
    reminders = ReminderScheduler(notifier);
    alarmRepo = AlarmRepository(db, alarmScheduler);
    taskRepo = TaskRepository(db, reminders);
    habitRepo = HabitRepository(db, reminders);
    eventRepo = EventRepository(db, reminders);
  }

  RestoreReconciler reconciler() => RestoreReconciler(
    database: db,
    alarmScheduler: alarmScheduler,
    reminderNotifier: notifier,
    alarmRepository: alarmRepo,
    taskRepository: taskRepo,
    habitRepository: habitRepo,
    eventRepository: eventRepo,
  );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    build();
  });

  tearDown(() => db.close());

  test('re-arms restored enabled alarms and cancels obsolete ones', () async {
    final enabledId = await alarmRepo.create(hour: 7, minute: 0);
    final disabledId = await alarmRepo.create(
      hour: 8,
      minute: 0,
      isEnabled: false,
    );
    alarmScheduler.cancelled.clear();
    alarmScheduler.scheduled.clear();

    const obsoleteId = 99;
    final outcome = await reconciler().reconcile(
      ScheduleSnapshot(
        alarmIds: {enabledId, disabledId, obsoleteId},
        taskIds: const {},
        habitIds: const {},
        eventIds: const {},
      ),
    );

    expect(outcome.isComplete, isTrue, reason: outcome.errors.toString());
    expect(alarmScheduler.cancelled, contains(obsoleteId));
    expect(alarmScheduler.snoozeCancelled, contains(obsoleteId));
    expect(alarmScheduler.scheduled.map((a) => a.id), contains(enabledId));
    expect(
      alarmScheduler.scheduled.map((a) => a.id),
      isNot(contains(disabledId)),
      reason: 'disabled alarms must not be re-armed',
    );
  });

  test('cancels obsolete task, habit and event reminders', () async {
    await taskRepo.create(
      title: 'Restored task',
      reminderAt: DateTime.now().add(const Duration(days: 1)),
    );
    await habitRepo.create(
      name: 'Restored habit',
      schedule: HabitSchedule.selectedWeekdays,
      weekdaysMask: (1 << 0) | (1 << 2),
      reminderMinuteOfDay: 7 * 60,
    );
    final eventStart = DateTime.now().add(const Duration(days: 2));
    await eventRepo.create(
      title: 'Restored event',
      startAt: eventStart,
      endAt: eventStart.add(const Duration(hours: 1)),
      reminderMinutes: 10,
    );

    notifier.cancelled.clear();
    notifier.oneOff.clear();
    notifier.daily.clear();

    final outcome = await reconciler().reconcile(
      const ScheduleSnapshot(
        alarmIds: {},
        taskIds: {42},
        habitIds: {43},
        eventIds: {44},
      ),
    );

    expect(outcome.isComplete, isTrue, reason: outcome.errors.toString());
    expect(notifier.cancelled, contains(ReminderScheduler.taskReminderId(42)));
    expect(notifier.cancelled, contains(ReminderScheduler.eventReminderId(44)));
    for (var weekday = 0; weekday <= 7; weekday++) {
      expect(
        notifier.cancelled,
        contains(ReminderScheduler.habitReminderId(43, weekday)),
      );
    }

    expect(notifier.oneOff, isNotEmpty);
    expect(
      notifier.daily.map((d) => d.weekday).toSet(),
      containsAll(<int>{1, 3}),
      reason: 'restored weekly habit reminder',
    );
  });

  test(
    'recurring restored event reminder is rescheduled to next occurrence',
    () async {
      final start = DateTime.now().subtract(const Duration(days: 3, hours: 1));
      await eventRepo.create(
        title: 'Daily standup',
        startAt: start,
        endAt: start.add(const Duration(minutes: 15)),
        recurrence: const Recurrence(frequency: RecurrenceFrequency.daily),
        reminderMinutes: 5,
      );
      notifier.oneOff.clear();

      final outcome = await reconciler().reconcile(
        const ScheduleSnapshot(
          alarmIds: {},
          taskIds: {},
          habitIds: {},
          eventIds: {},
        ),
      );

      expect(outcome.isComplete, isTrue, reason: outcome.errors.toString());
      expect(notifier.oneOff, hasLength(1));
      expect(
        notifier.oneOff.single.when.isAfter(DateTime.now()),
        isTrue,
        reason: 'recurring reminder must point at a future occurrence',
      );
    },
  );

  test(
    'permission-restricted schedule failures are reported, data intact',
    () async {
      build(failSchedule: true);
      final id = await alarmRepo.create(hour: 6, minute: 30);
      alarmScheduler.scheduled.clear();

      final outcome = await reconciler().reconcile(
        ScheduleSnapshot(
          alarmIds: {id},
          taskIds: const {},
          habitIds: const {},
          eventIds: const {},
        ),
      );

      expect(outcome.isComplete, isFalse);
      expect(outcome.alarmsReconciled, isFalse);
      expect(outcome.errors, isNotEmpty);
      expect(await alarmRepo.getById(id), isNotNull);
    },
  );

  test('obsolete cancellation failures are reported as partial', () async {
    final id = await alarmRepo.create(hour: 9, minute: 0);
    alarmScheduler.cancelled.clear();
    alarmScheduler.failCancelIds.add(77);

    final outcome = await reconciler().reconcile(
      ScheduleSnapshot(
        alarmIds: {id, 77},
        taskIds: const {},
        habitIds: const {},
        eventIds: const {},
      ),
    );

    expect(outcome.obsoleteCancelled, isFalse);
    expect(outcome.alarmsReconciled, isTrue);
    expect(outcome.errors, isNotEmpty);
    expect(await alarmRepo.getById(id), isNotNull);
  });
}
