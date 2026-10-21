import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/core/localization/generated/app_localizations.dart';
import 'package:aalumai/core/preferences/app_preferences.dart';
import 'package:aalumai/core/services/alarm_scheduler.dart';
import 'package:aalumai/core/services/reminder_notifier.dart';
import 'package:aalumai/features/alarms/data/alarm_repository.dart';
import 'package:aalumai/features/jarvis/data/briefing_scheduler.dart';
import 'package:aalumai/features/jarvis/domain/briefing.dart';
import 'package:aalumai/features/schedule/data/event_repository.dart';
import 'package:aalumai/features/tasks/data/task_repository.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeReminders implements ReminderNotifier {
  final List<int> cancelled = [];
  final List<({int id, String title, String body, DateTime when})> scheduled =
      [];

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    scheduled.add((id: id, title: title, body: body, when: when));
  }

  @override
  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    int? weekday,
  }) async {}
}

class _FakeAlarmScheduler implements AlarmScheduler {
  @override
  String? get lastError => null;

  @override
  Future<bool> canScheduleExactAlarms() async => true;

  @override
  Future<void> requestExactAlarmsPermission() async {}

  @override
  Future<void> scheduleAlarm(Alarm alarm) async {}

  @override
  Future<void> cancelAlarm(int alarmId) async {}

  @override
  Future<void> cancelAlarmSnooze(int alarmId) async {}

  @override
  Future<void> reconcile(List<Alarm> alarms) async {}
}

Future<AppLocalizations> _l10n() =>
    AppLocalizations.delegate.load(const Locale('en'));

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('nextBriefingTime', () {
    test('today when 08:00 is still ahead, tomorrow once it has passed',
        () {
      expect(
        nextBriefingTime(DateTime(2026, 3, 5, 7, 59)),
        DateTime(2026, 3, 5, 8),
      );
      expect(
        nextBriefingTime(DateTime(2026, 3, 5, 8)),
        DateTime(2026, 3, 6, 8),
      );
      expect(
        nextBriefingTime(DateTime(2026, 3, 5, 23, 30)),
        DateTime(2026, 3, 6, 8),
      );
    });
  });

  group('buildBriefing', () {
    test('is quiet when there is nothing to report', () async {
      final l10n = await _l10n();
      final content = buildBriefing(l10n: l10n, openTasks: 0, eventsToday: 0);
      expect(content.title, l10n.jarvisBriefingTitle);
      expect(content.body, l10n.jarvisBriefingQuiet);
    });

    test('combines counts and pads the alarm time', () async {
      final l10n = await _l10n();
      final content = buildBriefing(
        l10n: l10n,
        openTasks: 3,
        eventsToday: 2,
        nextAlarm: (hour: 6, minute: 5),
      );
      expect(content.body, '3 tasks due · 2 events today · Next alarm 06:05');
    });

    test('omits zero parts but keeps the rest', () async {
      final l10n = await _l10n();
      final content = buildBriefing(
        l10n: l10n,
        openTasks: 1,
        eventsToday: 0,
        nextAlarm: (hour: 7, minute: 0),
      );
      expect(content.body, '1 tasks due · Next alarm 07:00');
    });
  });

  group('reconcileDailyBriefing', () {
    late AppDatabase db;
    late AppPreferences prefs;
    late _FakeReminders reminders;
    late TaskRepository tasks;
    late EventRepository events;
    late AlarmRepository alarms;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = AppPreferences(await SharedPreferences.getInstance());
      db = AppDatabase.forTesting(NativeDatabase.memory());
      reminders = _FakeReminders();
      tasks = TaskRepository(db);
      events = EventRepository(db);
      alarms = AlarmRepository(db, _FakeAlarmScheduler());
    });

    tearDown(() => db.close());

    Future<void> reconcile() => reconcileDailyBriefing(
      reminders: reminders,
      prefs: prefs,
      tasks: tasks,
      events: events,
      alarms: alarms,
    );

    test('arms a briefing for the next morning with the day\'s facts',
        () async {
      final when = nextBriefingTime(DateTime.now());
      final dayStart = DateTime(when.year, when.month, when.day);
      await tasks.create(title: 'Buy milk', dueDate: dayStart);
      await events.create(
        title: 'Yoga',
        startAt: dayStart.add(const Duration(hours: 10)),
        endAt: dayStart.add(const Duration(hours: 11)),
      );

      await reconcile();

      final call = reminders.scheduled.single;
      expect(call.id, prefs.jarvisBriefingId);
      expect(call.id, greaterThanOrEqualTo(5000000));
      expect(call.title, 'Morning briefing');
      expect(call.body, '1 tasks due · 1 events today');
      expect(call.when.difference(when).inSeconds.abs(), lessThan(5));
    });

    test('re-arming cancels the previous slot first', () async {
      await reconcile();
      final first = reminders.scheduled.single.id;

      await reconcile();

      expect(reminders.cancelled, [first]);
      final second = reminders.scheduled.last.id;
      expect(second, isNot(first));
      expect(prefs.jarvisBriefingId, second);
    });

    test('a disabled toggle disarms without scheduling', () async {
      await prefs.setJarvisBriefingEnabled(false);

      await reconcile();

      expect(reminders.scheduled, isEmpty);
      expect(prefs.jarvisBriefingId, 0);
    });

    test('reconciling again while disarmed cancels the stale slot',
        () async {
      await reconcile();
      final armed = prefs.jarvisBriefingId;
      await prefs.setJarvisBriefingEnabled(false);

      await reconcile();

      expect(reminders.cancelled, contains(armed));
      expect(reminders.scheduled, hasLength(1));
      expect(prefs.jarvisBriefingId, 0);
    });

    test('the global notifications switch wins over the toggle', () async {
      await prefs.setNotificationsEnabled(false);

      await reconcile();

      expect(reminders.scheduled, isEmpty);
    });

    test('future tasks on other days are not counted', () async {
      final when = nextBriefingTime(DateTime.now());
      final otherDay = DateTime(when.year, when.month, when.day)
          .add(const Duration(days: 3));
      await tasks.create(title: 'Later', dueDate: otherDay);
      await tasks.create(
        title: 'Done already',
        dueDate: DateTime(when.year, when.month, when.day),
      );
      // Mark the same-day task complete so only the future one is excluded
      // for the wrong reason too.
      final done = (await tasks.watchAll().first)
          .firstWhere((row) => row.task.title == 'Done already');
      await tasks.setCompleted(done.task, true);

      await reconcile();

      expect(reminders.scheduled.single.body, contains('clear morning'));
    });
  });
}
