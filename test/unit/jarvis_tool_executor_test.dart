import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/core/preferences/app_preferences.dart';
import 'package:aalumai/core/services/alarm_scheduler.dart';
import 'package:aalumai/core/services/reminder_notifier.dart';
import 'package:aalumai/features/alarms/data/alarm_repository.dart';
import 'package:aalumai/features/expenses/data/finance_repository.dart';
import 'package:aalumai/features/fitness/data/fitness_repository.dart';
import 'package:aalumai/features/habits/data/habit_repository.dart';
import 'package:aalumai/features/jarvis/data/memory_repository.dart';
import 'package:aalumai/features/jarvis/data/tool_executor.dart';
import 'package:aalumai/features/jarvis/domain/tool_outcome.dart';
import 'package:aalumai/features/music/data/media_scanner.dart';
import 'package:aalumai/features/music/data/music_repository.dart';
import 'package:aalumai/features/notes/data/note_repository.dart';
import 'package:aalumai/features/schedule/data/event_repository.dart';
import 'package:aalumai/features/tasks/data/task_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeScheduler implements AlarmScheduler {
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

class _FakePlayer implements MusicPlaybackPort {
  bool playing = false;
  MusicTrack? loaded;
  final List<MusicTrack> played = [];
  int resumeCalls = 0;

  @override
  bool get isPlaying => playing;

  @override
  MusicTrack? get current => loaded;

  @override
  Future<void> playTrack(MusicTrack track) async {
    playing = true;
    loaded = track;
    played.add(track);
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
    playing = true;
  }
}

class _FakeDevice implements JarvisDeviceBridge {
  bool available = false;
  ({int level, bool charging}) battery = (level: 50, charging: false);
  final openedApps = <String>[];
  final openedSettings = <String>[];

  @override
  bool get isAvailable => available;

  @override
  Future<({int level, bool charging})> batteryStatus() async => battery;

  @override
  Future<bool> openApp(String package) async {
    openedApps.add(package);
    return true;
  }

  @override
  Future<bool> openSettings(String page) async {
    openedSettings.add(page);
    return true;
  }
}

class _FakeReminders implements ReminderNotifier {
  final scheduled = <({int id, String body, DateTime when})>[];
  final cancelled = <int>[];

  @override
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    scheduled.add((id: id, body: body, when: when));
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

  @override
  Future<void> cancel(int id) async => cancelled.add(id);
}

String _iso(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}

void main() {
  late AppDatabase db;
  late TaskRepository tasks;
  late EventRepository events;
  late AlarmRepository alarms;
  late HabitRepository habits;
  late NoteRepository notes;
  late FinanceRepository finance;
  late MusicRepository music;
  late MemoryRepository memories;
  late _FakePlayer player;
  late _FakeDevice device;
  late _FakeReminders reminders;
  late AppPreferences prefs;
  late ToolExecutor executor;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tasks = TaskRepository(db);
    events = EventRepository(db);
    alarms = AlarmRepository(db, _FakeScheduler());
    habits = HabitRepository(db);
    notes = NoteRepository(db);
    finance = FinanceRepository(db);
    music = MusicRepository(db, MediaScanner());
    memories = MemoryRepository(db);
    player = _FakePlayer();
    device = _FakeDevice();
    reminders = _FakeReminders();
    prefs = AppPreferences(await SharedPreferences.getInstance());
    executor = ToolExecutor(
      tasks: tasks,
      events: events,
      alarms: alarms,
      habits: habits,
      fitness: FitnessRepository(db),
      notes: notes,
      finance: finance,
      music: music,
      memories: memories,
      player: player,
      device: device,
      reminders: reminders,
      prefs: prefs,
      localeCode: () => 'en',
    );
  });

  tearDown(() => db.close());

  group('validation gate', () {
    test('unknown tools are refused', () async {
      final outcome = await executor.execute('shell.exec', const {});
      expect(outcome.kind, ToolOutcomeKind.error);
      expect(outcome.message, contains('Unknown tool'));
    });

    test('invalid arguments are refused with the spec errors', () async {
      final outcome = await executor.execute('task.create', const {});
      expect(outcome.kind, ToolOutcomeKind.error);
      expect(outcome.message, contains('title'));
    });
  });

  group('tasks', () {
    test('create then list with filters and query', () async {
      await executor.execute('task.create', {
        'title': 'Buy milk',
        'priority': 'high',
      });
      await executor.execute('task.create', {'title': 'Call the dentist'});

      final open = await executor.execute('task.list', const {});
      expect(open.kind, ToolOutcomeKind.ok);
      expect(open.message, contains('Buy milk'));
      expect(open.message, contains('(high)'));

      final all = await executor.execute('task.list', {'filter': 'all'});
      expect(all.message, contains('2 task(s)'));

      final queried = await executor.execute('task.list', {
        'filter': 'all',
        'query': 'dentist',
      });
      expect(queried.message, contains('Call the dentist'));
      expect(queried.message, isNot(contains('Buy milk')));
    });

    test('due date-times split into date + minute-of-day', () async {
      await executor.execute('task.create', {
        'title': 'Standup',
        'due': '2026-10-21 09:00',
      });
      final task = (await tasks.watchAll().first).single.task;
      expect(task.dueDate, DateTime(2026, 10, 21));
      expect(task.dueMinuteOfDay, 9 * 60);
    });

    test('complete is ambiguous for several matches, then honours ids',
        () async {
      final first = await tasks.create(title: 'Buy milk');
      await tasks.create(title: 'Buy milk powder');

      final ambiguous = await executor.execute('task.complete', {
        'match': 'milk',
      });
      expect(ambiguous.kind, ToolOutcomeKind.ambiguous);
      expect(ambiguous.choices.map((c) => c.id), containsAll([first]));

      final picked = await executor.execute('task.complete', {
        'match': '$first',
      });
      expect(picked.kind, ToolOutcomeKind.ok);
      expect((await tasks.getById(first))!.isCompleted, isTrue);

      final missing = await executor.execute('task.complete', {
        'match': 'nonexistent thing',
      });
      expect(missing.kind, ToolOutcomeKind.notFound);
    });

    test('update changes the title of the resolved task', () async {
      final id = await tasks.create(title: 'Water plants');
      final outcome = await executor.execute('task.update', {
        'match': 'plants',
        'new_title': 'Water the plants and the balcony',
      });
      expect(outcome.kind, ToolOutcomeKind.ok);
      expect((await tasks.getById(id))!.title, 'Water the plants and the balcony');
    });

    test('delete removes exactly one task', () async {
      final id = await tasks.create(title: 'Scratch card');
      final outcome = await executor.execute('task.delete', {
        'match': 'Scratch card',
      });
      expect(outcome.kind, ToolOutcomeKind.ok);
      expect(await tasks.getById(id), isNull);
    });
  });

  group('alarms', () {
    test('set one-time and repeating alarms with the right mask', () async {
      final oneTime = await executor.execute('alarm.set', {
        'hour': 6,
        'minute': 30,
        'label': 'Gym',
      });
      expect(oneTime.kind, ToolOutcomeKind.ok);
      expect(oneTime.message, contains('one-time'));

      await executor.execute('alarm.set', {
        'hour': 7,
        'minute': 0,
        'days': [0, 2, 4],
      });
      final all = await alarms.watchAll().first;
      expect(all, hasLength(2));
      final repeating = all.firstWhere((a) => a.hour == 7);
      expect(repeating.repeatDaysMask, 0x15); // Mo, We, Fr
      expect(repeating.oneTime, isFalse);
    });

    test('toggle resolves by time and flips the enabled flag', () async {
      final id = await alarms.create(hour: 7, minute: 0, label: 'Wake up');
      final outcome = await executor.execute('alarm.toggle', {
        'match': '07:00',
        'enabled': false,
      });
      expect(outcome.kind, ToolOutcomeKind.ok);
      expect((await alarms.getById(id))!.isEnabled, isFalse);
    });

    test('delete by label', () async {
      final id = await alarms.create(hour: 8, minute: 15, label: 'Meds');
      final outcome = await executor.execute('alarm.delete', {
        'match': 'Meds',
      });
      expect(outcome.kind, ToolOutcomeKind.ok);
      expect(await alarms.getById(id), isNull);
    });
  });

  group('events and habits', () {
    test('event.create rejects end-before-start and stores valid events',
        () async {
      final bad = await executor.execute('event.create', {
        'title': 'Backwards',
        'start': '2026-10-21 10:00',
        'end': '2026-10-21 09:00',
      });
      expect(bad.kind, ToolOutcomeKind.error);

      final today = DateTime.now();
      final start = DateTime(today.year, today.month, today.day, 12, 0);
      final created = await executor.execute('event.create', {
        'title': 'Lunch with Anu',
        'start': _iso(start),
        'location': 'Cafe',
      });
      expect(created.kind, ToolOutcomeKind.ok);

      final listed = await executor.execute('event.list', {'when': 'today'});
      expect(listed.message, contains('Lunch with Anu'));
      expect(listed.message, contains('@ Cafe'));
    });

    test('habit.log is idempotent and asks when several habits match',
        () async {
      await habits.create(name: 'Drink water');
      await habits.create(name: 'Drink green tea');

      final ambiguous = await executor.execute('habit.log', {
        'match': 'drink',
      });
      expect(ambiguous.kind, ToolOutcomeKind.ambiguous);

      final logged = await executor.execute('habit.log', {
        'match': 'Drink water',
      });
      expect(logged.kind, ToolOutcomeKind.ok);

      final again = await executor.execute('habit.log', {
        'match': 'Drink water',
      });
      expect(again.message, contains('already logged'));
    });
  });

  group('notes, memories and expenses', () {
    test('note.create then note.search', () async {
      await executor.execute('note.create', {
        'title': 'Gift ideas',
        'body': 'Ani likes coffee beans from Coorg.',
      });
      final found = await executor.execute('note.search', {'query': 'gift'});
      expect(found.kind, ToolOutcomeKind.ok);
      expect(found.message, contains('Gift ideas'));
    });

    test('memory.save stays pending until confirmed; forget resolves by id',
        () async {
      final saved = await executor.execute('memory.save', {
        'content': 'User drinks filter coffee every morning.',
        'category': 'preference',
      });
      expect(saved.kind, ToolOutcomeKind.ok);
      expect((await memories.all()).single.confirmed, isFalse);

      await memories.save(content: 'User takes coffee after the gym.');
      final ambiguous = await executor.execute('memory.forget', {
        'match': 'coffee',
      });
      expect(ambiguous.kind, ToolOutcomeKind.ambiguous);
      expect(ambiguous.choices, hasLength(2));

      final id = ambiguous.choices.first.id;
      final forgotten = await executor.execute('memory.forget', {
        'match': '$id',
      });
      expect(forgotten.kind, ToolOutcomeKind.ok);
      expect(await memories.count(), 1);
    });

    test('memory.search ranks and returns the top hits', () async {
      await memories.save(content: 'User drinks filter coffee.');
      await memories.save(content: 'User runs on Sundays.');
      final found = await executor.execute('memory.search', {
        'query': 'coffee',
      });
      expect(found.kind, ToolOutcomeKind.ok);
      expect(found.message, contains('filter coffee'));
      expect(found.message, isNot(contains('runs on Sundays')));
    });

    test('expense.create resolves categories and reports unknown ones',
        () async {
      await finance.createAccount(name: 'Wallet');
      await finance.createCategory('Coffee', CategoryKind.expense);

      final unknown = await executor.execute('expense.create', {
        'amount': 2.5,
        'category': 'Bananas',
      });
      expect(unknown.kind, ToolOutcomeKind.error);
      expect(unknown.message, contains('Coffee'));

      final created = await executor.execute('expense.create', {
        'amount': 2.5,
        'category': 'coffee',
        'note': 'latte',
      });
      expect(created.kind, ToolOutcomeKind.ok);

      final summary = await executor.execute('expense.summary', const {});
      expect(summary.kind, ToolOutcomeKind.ok);
      expect(summary.message, contains('This month'));
      expect(summary.message, contains('₹'));
    });

    test('expense.create refuses when no account exists', () async {
      final outcome = await executor.execute('expense.create', {
        'amount': 1,
      });
      expect(outcome.kind, ToolOutcomeKind.error);
      expect(outcome.message, contains('No account'));
    });
  });

  group('music', () {
    Future<int> insertTrack(String title, String artist) =>
        db.into(db.musicTracks).insert(
          MusicTracksCompanion.insert(
            uri: 'file:///${title.toLowerCase().replaceAll(' ', '_')}.mp3',
            title: Value(title),
            artist: Value(artist),
          ),
        );

    test('music.list filters by query', () async {
      await insertTrack('Sunshine Walk', 'Anu R');
      await insertTrack('Midnight Study', 'Kavi');
      final outcome = await executor.execute('music.list', {
        'query': 'sunshine',
      });
      expect(outcome.kind, ToolOutcomeKind.ok);
      expect(outcome.message, contains('Sunshine Walk'));
      expect(outcome.message, isNot(contains('Midnight Study')));
    });

    test('music.play picks a track and resumes when idle', () async {
      final id = await insertTrack('Sunshine Walk', 'Anu R');

      final nothing = await executor.execute('music.play', const {});
      expect(nothing.kind, ToolOutcomeKind.notFound);

      final played = await executor.execute('music.play', {
        'match': 'Sunshine',
      });
      expect(played.kind, ToolOutcomeKind.ok);
      expect(player.played.single.id, id);
      expect(player.isPlaying, isTrue);

      player.playing = false;
      final resumed = await executor.execute('music.play', const {});
      expect(resumed.message, contains('Resumed'));
      expect(player.resumeCalls, 1);
    });
  });

  group('reminders and device bridge', () {
    test('reminder.create schedules in the Jarvis id block, rejects the past',
        () async {
      final past = await executor.execute('reminder.create', {
        'text': 'Too late',
        'fire_at': '2000-01-01 09:00',
      });
      expect(past.kind, ToolOutcomeKind.error);

      final future = DateTime.now().add(const Duration(hours: 2));
      final created = await executor.execute('reminder.create', {
        'text': 'Drink water',
        'fire_at': _iso(future),
      });
      expect(created.kind, ToolOutcomeKind.ok);
      expect(reminders.scheduled, hasLength(1));
      expect(reminders.scheduled.single.id, greaterThanOrEqualTo(5000000));
      expect(reminders.scheduled.single.body, 'Drink water');

      await executor.execute('reminder.create', {
        'text': 'Stretch',
        'fire_at': _iso(future.add(const Duration(minutes: 5))),
      });
      expect(reminders.scheduled[1].id, greaterThan(reminders.scheduled[0].id));
    });

    test('device.status is an honest error until the bridge exists', () async {
      final outcome = await executor.execute('device.status', const {});
      expect(outcome.kind, ToolOutcomeKind.error);
      expect(outcome.message, contains('device bridge'));

      device.available = true;
      device.battery = (level: 82, charging: true);
      final live = await executor.execute('device.status', const {});
      expect(live.message, contains('82%'));
      expect(live.message, contains('charging'));
    });

    test('device actions refuse without the bridge and run with it', () async {
      final refused = await executor.execute('device.open_settings', {
        'page': 'wifi',
      });
      expect(refused.kind, ToolOutcomeKind.error);

      device.available = true;
      final opened = await executor.execute('device.open_settings', {
        'page': 'wifi',
      });
      expect(opened.kind, ToolOutcomeKind.ok);
      expect(device.openedSettings, ['wifi']);
    });
  });

  group('resolveMatch', () {
    test('prefers id, then exact, then substring', () {
      final items = [
        (id: 3, label: 'Buy milk'),
        (id: 7, label: 'Buy milk powder'),
      ];

      final byId = resolveMatch(items, '7', (i) => i.label, (i) => i.id);
      expect(byId.kind, MatchKind.single);
      expect(byId.single.id, 7);

      final exact = resolveMatch(
        items,
        'buy milk',
        (i) => i.label,
        (i) => i.id,
      );
      expect(exact.kind, MatchKind.single);
      expect(exact.single.id, 3);

      final partial = resolveMatch(items, 'powder', (i) => i.label, (i) => i.id);
      expect(partial.kind, MatchKind.single);
      expect(partial.single.id, 7);

      final many = resolveMatch(items, 'milk', (i) => i.label, (i) => i.id);
      expect(many.kind, MatchKind.multiple);

      final none = resolveMatch(items, 'zzz', (i) => i.label, (i) => i.id);
      expect(none.kind, MatchKind.none);
    });
  });
}
