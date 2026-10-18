import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/core/services/reminder_notifier.dart';
import 'package:aalumai/core/services/reminder_scheduler.dart';
import 'package:aalumai/core/utils/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

class _OneOff {
  _OneOff(this.id, this.title, this.body, this.when);
  final int id;
  final String title;
  final String body;
  final DateTime when;
}

class _Daily {
  _Daily(this.id, this.hour, this.minute, this.weekday);
  final int id;
  final int hour;
  final int minute;
  final int? weekday;
}

class FakeReminderNotifier implements ReminderNotifier {
  final oneOff = <_OneOff>[];
  final daily = <_Daily>[];
  final cancelled = <int>[];

  @override
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    oneOff.add(_OneOff(id, title, body, when));
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
    daily.add(_Daily(id, hour, minute, weekday));
  }

  @override
  Future<void> cancel(int id) async => cancelled.add(id);
}

Task _task({int id = 1, DateTime? reminderAt, bool isCompleted = false}) =>
    Task(
      id: id,
      title: 'Task $id',
      notes: 'notes',
      dueDate: null,
      dueMinuteOfDay: -1,
      priority: 1,
      parentId: null,
      recurrenceRule: '',
      isCompleted: isCompleted,
      completedAt: isCompleted ? DateTime(2024) : null,
      reminderAt: reminderAt,
      tagIds: '',
      sortOrder: 0,
      createdAt: DateTime(2024),
    );

Habit _habit({
  int id = 1,
  int scheduleType = 0,
  int weekdaysMask = 0,
  int reminderMinuteOfDay = -1,
  bool isArchived = false,
}) => Habit(
  id: id,
  name: 'Habit $id',
  note: 'note',
  scheduleType: scheduleType,
  weekdaysMask: weekdaysMask,
  targetPerWeek: 7,
  isMeasurable: false,
  goalValue: 0,
  unit: '',
  isArchived: isArchived,
  sortOrder: 0,
  reminderMinuteOfDay: reminderMinuteOfDay,
  createdAt: DateTime(2024),
);

Event _event({
  int id = 1,
  required DateTime start,
  int reminderMinutes = -1,
  Recurrence recurrence = Recurrence.none,
}) => Event(
  id: id,
  title: 'Event $id',
  description: 'desc',
  location: '',
  startAt: start,
  endAt: start.add(const Duration(hours: 1)),
  allDay: false,
  recurrenceRule: recurrence.encode(),
  reminderMinutes: reminderMinutes,
  isBirthday: false,
  createdAt: DateTime(2024),
);

void main() {
  group('nextReminderTime', () {
    test('returns null when no reminder is configured', () {
      final e = _event(start: DateTime(2024, 1, 1, 9), reminderMinutes: -1);
      expect(ReminderScheduler.nextReminderTime(e, DateTime(2024)), isNull);
    });

    test('subtracts the lead time from a future one-off event', () {
      final now = DateTime(2024, 1, 1, 8);
      final e = _event(start: DateTime(2024, 1, 1, 9), reminderMinutes: 15);
      expect(
        ReminderScheduler.nextReminderTime(e, now),
        DateTime(2024, 1, 1, 8, 45),
      );
    });

    test('returns null for a past one-off event', () {
      final now = DateTime(2024, 6, 1);
      final e = _event(start: DateTime(2024, 1, 1, 9), reminderMinutes: 10);
      expect(ReminderScheduler.nextReminderTime(e, now), isNull);
    });

    test('advances a recurring event to the next future occurrence', () {
      final now = DateTime(2024, 1, 3, 12);
      final e = _event(
        start: DateTime(2024, 1, 1, 9),
        reminderMinutes: 30,
        recurrence: const Recurrence(frequency: RecurrenceFrequency.daily),
      );
      // Next occurrence after 2024-01-03 12:00 is 2024-01-04 09:00.
      expect(
        ReminderScheduler.nextReminderTime(e, now),
        DateTime(2024, 1, 4, 8, 30),
      );
    });
  });

  group('ReminderScheduler.syncTask', () {
    test('schedules a future reminder', () async {
      final fake = FakeReminderNotifier();
      final scheduler = ReminderScheduler(fake);
      final when = DateTime.now().add(const Duration(hours: 2));
      await scheduler.syncTask(_task(id: 7, reminderAt: when));
      expect(fake.cancelled, contains(ReminderScheduler.taskReminderId(7)));
      expect(fake.oneOff, hasLength(1));
      expect(fake.oneOff.single.id, ReminderScheduler.taskReminderId(7));
      expect(fake.oneOff.single.when, when);
    });

    test('does not schedule a completed task', () async {
      final fake = FakeReminderNotifier();
      final scheduler = ReminderScheduler(fake);
      await scheduler.syncTask(
        _task(
          reminderAt: DateTime.now().add(const Duration(hours: 2)),
          isCompleted: true,
        ),
      );
      expect(fake.oneOff, isEmpty);
      expect(fake.cancelled, isNotEmpty);
    });

    test('does not schedule a reminder in the past', () async {
      final fake = FakeReminderNotifier();
      final scheduler = ReminderScheduler(fake);
      await scheduler.syncTask(
        _task(reminderAt: DateTime.now().subtract(const Duration(hours: 2))),
      );
      expect(fake.oneOff, isEmpty);
    });

    test('clears the reminder when none is set', () async {
      final fake = FakeReminderNotifier();
      final scheduler = ReminderScheduler(fake);
      await scheduler.syncTask(_task());
      expect(fake.oneOff, isEmpty);
      expect(fake.cancelled, contains(ReminderScheduler.taskReminderId(1)));
    });
  });

  group('ReminderScheduler.syncHabit', () {
    test('schedules a single daily reminder for a daily habit', () async {
      final fake = FakeReminderNotifier();
      final scheduler = ReminderScheduler(fake);
      await scheduler.syncHabit(_habit(reminderMinuteOfDay: 7 * 60 + 30));
      expect(fake.daily, hasLength(1));
      expect(fake.daily.single.hour, 7);
      expect(fake.daily.single.minute, 30);
      expect(fake.daily.single.weekday, isNull);
    });

    test('schedules one reminder per selected weekday', () async {
      final fake = FakeReminderNotifier();
      final scheduler = ReminderScheduler(fake);
      // Monday + Wednesday.
      await scheduler.syncHabit(
        _habit(
          scheduleType: 1,
          weekdaysMask: (1 << 0) | (1 << 2),
          reminderMinuteOfDay: 8 * 60,
        ),
      );
      final weekdays = fake.daily.map((d) => d.weekday).toList()..sort();
      expect(weekdays, [1, 3]);
    });

    test('clears reminders when the habit has no time set', () async {
      final fake = FakeReminderNotifier();
      final scheduler = ReminderScheduler(fake);
      await scheduler.syncHabit(_habit(reminderMinuteOfDay: -1));
      expect(fake.daily, isEmpty);
      expect(fake.cancelled, isNotEmpty);
    });

    test('clears reminders for an archived habit', () async {
      final fake = FakeReminderNotifier();
      final scheduler = ReminderScheduler(fake);
      await scheduler.syncHabit(
        _habit(reminderMinuteOfDay: 8 * 60, isArchived: true),
      );
      expect(fake.daily, isEmpty);
    });
  });

  group('ReminderScheduler.syncEvent', () {
    test('schedules a future event reminder', () async {
      final fake = FakeReminderNotifier();
      final scheduler = ReminderScheduler(fake);
      final start = DateTime.now().add(const Duration(days: 1));
      await scheduler.syncEvent(
        _event(id: 3, start: start, reminderMinutes: 10),
      );
      expect(fake.oneOff, hasLength(1));
      expect(fake.oneOff.single.id, ReminderScheduler.eventReminderId(3));
      expect(
        fake.oneOff.single.when,
        start.subtract(const Duration(minutes: 10)),
      );
    });

    test('clears the reminder when none is configured', () async {
      final fake = FakeReminderNotifier();
      final scheduler = ReminderScheduler(fake);
      await scheduler.syncEvent(
        _event(start: DateTime.now().add(const Duration(days: 1))),
      );
      expect(fake.oneOff, isEmpty);
      expect(fake.cancelled, contains(ReminderScheduler.eventReminderId(1)));
    });
  });
}
