import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/core/services/reminder_scheduler.dart';
import 'package:aalumai/core/utils/recurrence.dart';
import 'package:aalumai/features/habits/data/habit_repository.dart';
import 'package:aalumai/features/habits/domain/habit_streak.dart';
import 'package:aalumai/features/schedule/data/event_repository.dart';
import 'package:aalumai/features/tasks/data/task_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reminder_scheduler_test.dart' show FakeReminderNotifier;

void main() {
  late AppDatabase db;
  late FakeReminderNotifier fake;
  late ReminderScheduler scheduler;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    fake = FakeReminderNotifier();
    scheduler = ReminderScheduler(fake);
  });

  tearDown(() => db.close());

  test('creating a task with a reminder schedules it', () async {
    final repo = TaskRepository(db, scheduler);
    final when = DateTime.now().add(const Duration(days: 1));
    final id = await repo.create(title: 'Call mum', reminderAt: when);
    expect(fake.oneOff, hasLength(1));
    expect(fake.oneOff.single.id, ReminderScheduler.taskReminderId(id));
    expect(fake.oneOff.single.when, (await repo.getById(id))!.reminderAt);
  });

  test('completing a task clears its reminder', () async {
    final repo = TaskRepository(db, scheduler);
    final id = await repo.create(
      title: 'Pay bill',
      reminderAt: DateTime.now().add(const Duration(days: 1)),
    );
    fake.oneOff.clear();
    final task = (await repo.getById(id))!;
    await repo.setCompleted(task, true);
    expect(fake.oneOff, isEmpty);
    expect(fake.cancelled, contains(ReminderScheduler.taskReminderId(id)));
  });

  test('deleting a task clears its reminder', () async {
    final repo = TaskRepository(db, scheduler);
    final id = await repo.create(
      title: 'Tidy',
      reminderAt: DateTime.now().add(const Duration(days: 1)),
    );
    await repo.delete(id);
    expect(fake.cancelled, contains(ReminderScheduler.taskReminderId(id)));
  });

  test('reconcileReminders re-schedules stored tasks', () async {
    final repo = TaskRepository(db, scheduler);
    await repo.create(
      title: 'Water plants',
      reminderAt: DateTime.now().add(const Duration(days: 3)),
    );
    fake.oneOff.clear();
    await repo.reconcileReminders();
    expect(fake.oneOff, hasLength(1));
  });

  test('creating a habit with a reminder schedules it', () async {
    final repo = HabitRepository(db, scheduler);
    final id = await repo.create(
      name: 'Read',
      schedule: HabitSchedule.daily,
      reminderMinuteOfDay: 21 * 60,
    );
    expect(fake.daily, hasLength(1));
    expect(fake.daily.single.id, ReminderScheduler.habitReminderId(id, 0));
    expect(fake.daily.single.hour, 21);
    expect(fake.daily.single.minute, 0);
  });

  test('archiving a habit clears its reminder', () async {
    final repo = HabitRepository(db, scheduler);
    final id = await repo.create(name: 'Gym', reminderMinuteOfDay: 6 * 60);
    fake.daily.clear();
    await repo.setArchived(id, true);
    expect(fake.daily, isEmpty);
    expect(fake.cancelled, isNotEmpty);
  });

  test('creating an event with a reminder schedules it', () async {
    final repo = EventRepository(db, scheduler);
    final start = DateTime.now().add(const Duration(days: 2));
    final id = await repo.create(
      title: 'Standup',
      startAt: start,
      endAt: start.add(const Duration(minutes: 30)),
      reminderMinutes: 15,
    );
    expect(fake.oneOff, hasLength(1));
    expect(fake.oneOff.single.id, ReminderScheduler.eventReminderId(id));
    final stored = (await repo.getById(id))!;
    expect(
      fake.oneOff.single.when,
      stored.startAt.subtract(const Duration(minutes: 15)),
    );
  });

  test('reconcileReminders re-schedules stored events', () async {
    final repo = EventRepository(db, scheduler);
    final start = DateTime.now().add(const Duration(days: 4));
    await repo.create(
      title: 'Review',
      startAt: start,
      endAt: start.add(const Duration(hours: 1)),
      reminderMinutes: 30,
    );
    fake.oneOff.clear();
    await repo.reconcileReminders();
    expect(fake.oneOff, hasLength(1));
  });

  test('repositories work without a scheduler (optional dependency)', () async {
    final repo = TaskRepository(db);
    final id = await repo.create(
      title: 'No reminders',
      reminderAt: DateTime.now().add(const Duration(days: 1)),
    );
    expect((await repo.getById(id))!.title, 'No reminders');
    expect(fake.oneOff, isEmpty);
  });

  test(
    'recurrence-encoding helper round-trips through event reminders',
    () async {
      final repo = EventRepository(db, scheduler);
      final start = DateTime.now().add(const Duration(days: 1));
      final id = await repo.create(
        title: 'Daily',
        startAt: start,
        endAt: start.add(const Duration(hours: 1)),
        recurrence: const Recurrence(frequency: RecurrenceFrequency.daily),
        reminderMinutes: 5,
      );
      final event = (await repo.getById(id))!;
      expect(Recurrence.parse(event.recurrenceRule).repeats, isTrue);
      expect(
        fake.oneOff.single.when,
        event.startAt.subtract(const Duration(minutes: 5)),
      );
    },
  );
}
