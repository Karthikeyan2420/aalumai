import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/core/preferences/app_preferences.dart';
import 'package:aalumai/core/providers/providers.dart';
import 'package:aalumai/core/services/notification_service.dart';
import 'package:aalumai/core/services/reminder_notifier.dart';
import 'package:aalumai/features/alarms/data/alarm_repository.dart';
import 'package:aalumai/features/expenses/data/finance_repository.dart';
import 'package:aalumai/features/fitness/data/fitness_repository.dart';
import 'package:aalumai/features/habits/data/habit_repository.dart';
import 'package:aalumai/features/jarvis/data/device_bridge.dart';
import 'package:aalumai/features/jarvis/data/memory_repository.dart';
import 'package:aalumai/features/jarvis/domain/memory_retrieval.dart';
import 'package:aalumai/features/jarvis/domain/tool_outcome.dart';
import 'package:aalumai/features/jarvis/domain/tool_specs.dart';
import 'package:aalumai/features/music/data/music_repository.dart';
import 'package:aalumai/features/music/data/player_service.dart';
import 'package:aalumai/features/notes/data/note_repository.dart';
import 'package:aalumai/features/schedule/data/event_repository.dart';
import 'package:aalumai/features/tasks/data/task_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Music playback control, abstracted so the executor never depends on the
/// Riverpod player notifier directly (and tests can drive a fake).
abstract class MusicPlaybackPort {
  bool get isPlaying;
  MusicTrack? get current;
  Future<void> playTrack(MusicTrack track);
  Future<void> resume();
}

/// Device-level actions and sensors, backed by the Android bridge
/// (`aalumai/jarvis_actions`). The unsupported implementation answers
/// honestly until the bridge ships.
abstract class JarvisDeviceBridge {
  bool get isAvailable;
  Future<({int level, bool charging})> batteryStatus();
  Future<bool> openApp(String package);
  Future<bool> openSettings(String page);
}

class UnsupportedDeviceBridge implements JarvisDeviceBridge {
  const UnsupportedDeviceBridge();

  @override
  bool get isAvailable => false;

  @override
  Future<({int level, bool charging})> batteryStatus() async =>
      throw UnsupportedError('device bridge unavailable');

  @override
  Future<bool> openApp(String package) async => false;

  @override
  Future<bool> openSettings(String page) async => false;
}

enum MatchKind { none, single, multiple }

class MatchResolution<T> {
  MatchResolution(this.kind, this.items);

  final MatchKind kind;
  final List<T> items;

  T get single => items.single;
}

/// Resolves a model-supplied `match` string against [items].
///
/// An all-digits match is tried as an id first (how the model picks after an
/// ambiguity), then exact case-insensitive equality (which wins over
/// substring matches), then substring.
MatchResolution<T> resolveMatch<T>(
  List<T> items,
  String match,
  String Function(T) label,
  int Function(T) id,
) {
  final needle = match.trim().toLowerCase();
  if (needle.isEmpty) return MatchResolution(MatchKind.none, const []);

  final asId = int.tryParse(needle);
  if (asId != null) {
    for (final item in items) {
      if (id(item) == asId) return MatchResolution(MatchKind.single, [item]);
    }
  }

  final exact = items
      .where((i) => label(i).trim().toLowerCase() == needle)
      .toList();
  if (exact.length == 1) return MatchResolution(MatchKind.single, exact);
  if (exact.length > 1) return MatchResolution(MatchKind.multiple, exact);

  final partial = items
      .where((i) => label(i).toLowerCase().contains(needle))
      .toList();
  if (partial.isEmpty) return MatchResolution(MatchKind.none, const []);
  if (partial.length == 1) return MatchResolution(MatchKind.single, partial);
  return MatchResolution(MatchKind.multiple, partial);
}

/// Executes validated tool calls against the app's real repositories.
///
/// The model never reaches a repository directly: every call enters through
/// [execute], which re-validates arguments against the spec catalog and
/// converts every failure (including unexpected ones) into a model-facing
/// [ToolOutcome] so the chat loop can never die on a tool error.
///
/// Confirmation of sensitive/destructive/external actions is NOT handled
/// here — the chat controller consults the safety policy and asks the user
/// before calling [execute].
class ToolExecutor {
  ToolExecutor({
    required this.tasks,
    required this.events,
    required this.alarms,
    required this.habits,
    required this.fitness,
    required this.notes,
    required this.finance,
    required this.music,
    required this.memories,
    required this.player,
    required this.device,
    required this.reminders,
    required this.prefs,
    required this.localeCode,
  });

  final TaskRepository tasks;
  final EventRepository events;
  final AlarmRepository alarms;
  final HabitRepository habits;
  final FitnessRepository fitness;
  final NoteRepository notes;
  final FinanceRepository finance;
  final MusicRepository music;
  final MemoryRepository memories;
  final MusicPlaybackPort player;
  final JarvisDeviceBridge device;
  final ReminderNotifier reminders;
  final AppPreferences prefs;

  /// Currency/locale hint for money formatting (e.g. `en`).
  final String Function() localeCode;

  Future<ToolOutcome> execute(
    String toolName,
    Map<String, Object?> rawArgs,
  ) async {
    final spec = kJarvisToolsByName[toolName];
    if (spec == null) {
      return ToolOutcome.error(
        'Unknown tool "$toolName". Only use the tools listed in the prompt.',
      );
    }
    final validation = validateToolArgs(spec, rawArgs);
    if (!validation.isValid) {
      return ToolOutcome.error(validation.errors.join(' '));
    }
    try {
      return await _dispatch(toolName, validation.args);
    } catch (e) {
      return ToolOutcome.error('The action failed: $e');
    }
  }

  Future<ToolOutcome> _dispatch(
    String tool,
    Map<String, Object?> args,
  ) async {
    switch (tool) {
      case 'task.list':
        return _taskList(args);
      case 'event.list':
        return _eventList(args);
      case 'alarm.list':
        return _alarmList();
      case 'habit.list':
        return _habitList();
      case 'workout.summary':
        return _workoutSummary(args);
      case 'note.search':
        return _noteSearch(args);
      case 'expense.summary':
        return _expenseSummary();
      case 'music.list':
        return _musicList(args);
      case 'memory.search':
        return _memorySearch(args);
      case 'device.status':
        return _deviceStatus();
      case 'task.create':
        return _taskCreate(args);
      case 'event.create':
        return _eventCreate(args);
      case 'reminder.create':
        return _reminderCreate(args);
      case 'alarm.set':
        return _alarmSet(args);
      case 'habit.log':
        return _habitLog(args);
      case 'note.create':
        return _noteCreate(args);
      case 'memory.save':
        return _memorySave(args);
      case 'expense.create':
        return _expenseCreate(args);
      case 'task.complete':
        return _taskComplete(args);
      case 'task.update':
        return _taskUpdate(args);
      case 'music.play':
        return _musicPlay(args);
      case 'alarm.toggle':
        return _alarmToggle(args);
      case 'task.delete':
        return _taskDelete(args);
      case 'alarm.delete':
        return _alarmDelete(args);
      case 'memory.forget':
        return _memoryForget(args);
      case 'device.open_app':
      case 'device.open_settings':
        if (!device.isAvailable) {
          return const ToolOutcome.error(
            'Device actions need the device bridge, which is not available '
            'in this build yet.',
          );
        }
        return tool == 'device.open_app'
            ? _deviceOpenApp(args)
            : _deviceOpenSettings(args);
      default:
        return ToolOutcome.error('Tool "$tool" is not wired up yet.');
    }
  }

  // ------------------------------------------------------------------ reads

  Future<ToolOutcome> _taskList(Map<String, Object?> args) async {
    final filter = args['filter'] as String? ?? 'open';
    final query = (args['query'] as String?)?.toLowerCase();

    List<Task> all;
    if (filter == 'today') {
      final rows = await tasks.watchToday().first;
      all = [for (final row in rows) row.task];
    } else {
      final rows = await tasks.watchAll().first;
      all = [for (final row in rows) row.task];
    }
    if (filter == 'open') {
      all = all.where((t) => !t.isCompleted).toList();
    }
    if (query != null && query.isNotEmpty) {
      all = all.where((t) => t.title.toLowerCase().contains(query)).toList();
    }
    if (all.isEmpty) return const ToolOutcome.ok('No tasks match.');

    final shown = all.take(30).toList();
    final lines = [for (final task in shown) _formatTask(task)];
    final more = all.length > shown.length
        ? '\n(+${all.length - shown.length} more)'
        : '';
    return ToolOutcome.ok(
      '${all.length} task(s):\n${lines.join('\n')}$more',
    );
  }

  String _formatTask(Task task) {
    final buffer = StringBuffer(task.isCompleted ? '[x]' : '[ ]');
    buffer.write(' #${task.id} ${task.title}');
    if (task.dueDate != null) buffer.write(' — due ${_fmtDate(task.dueDate!)}');
    if (task.dueMinuteOfDay >= 0) {
      buffer.write(' at ${_fmtMinuteOfDay(task.dueMinuteOfDay)}');
    }
    final priority = TaskPriority.fromIndex(task.priority);
    if (priority != TaskPriority.medium) buffer.write(' (${priority.name})');
    return buffer.toString();
  }

  Future<ToolOutcome> _eventList(Map<String, Object?> args) async {
    final when = args['when'] as String? ?? 'today';
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final (from, to) = switch (when) {
      'tomorrow' => (
        todayStart.add(const Duration(days: 1)),
        todayStart.add(const Duration(days: 2)),
      ),
      'week' => (todayStart, todayStart.add(const Duration(days: 7))),
      _ => (todayStart, todayStart.add(const Duration(days: 1))),
    };

    final raw = await events.eventsBetween(from, to);
    final expanded = EventRepository.expand(raw, from, to);
    if (expanded.isEmpty) {
      return ToolOutcome.ok('No events $when.');
    }
    final lines = [
      for (final event in expanded.take(30))
        event.allDay
            ? '#${event.id} all day ${event.title}'
            : '#${event.id} '
                  '${_fmtClock(event.startAt.hour, event.startAt.minute)}'
                  '–${_fmtClock(event.endAt.hour, event.endAt.minute)} '
                  '${event.title}'
                  '${event.location.isEmpty ? '' : ' @ ${event.location}'}',
    ];
    return ToolOutcome.ok('${expanded.length} event(s):\n${lines.join('\n')}');
  }

  Future<ToolOutcome> _alarmList() async {
    final all = await alarms.watchAll().first;
    if (all.isEmpty) return const ToolOutcome.ok('No alarms are set.');
    final lines = [
      for (final alarm in all.take(30))
        '#${alarm.id} '
            '${_fmtClock(alarm.hour, alarm.minute)} '
            '${alarm.label.isEmpty ? '' : '"${alarm.label}" '}'
            '${alarm.isEnabled ? "on" : "off"}'
            '${alarm.repeatDaysMask == 0 ? '' : ' (${_daysLabel(alarm.repeatDaysMask)})'}',
    ];
    return ToolOutcome.ok('${all.length} alarm(s):\n${lines.join('\n')}');
  }

  Future<ToolOutcome> _habitList() async {
    final now = DateTime.now();
    final active = await habits.watchActive().first;
    if (active.isEmpty) return const ToolOutcome.ok('No active habits.');
    final lines = <String>[];
    for (final habit in active.take(30)) {
      final done = await habits.isCompleted(habit.id, now);
      lines.add(
        '#${habit.id} ${habit.name} — ${done ? 'done today' : 'pending'}',
      );
    }
    return ToolOutcome.ok('${active.length} habit(s):\n${lines.join('\n')}');
  }

  Future<ToolOutcome> _workoutSummary(Map<String, Object?> args) async {
    final period = args['period'] as String? ?? 'today';
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final from = period == 'week'
        ? todayStart.subtract(Duration(days: todayStart.weekday - 1))
        : todayStart;

    final sessions = await fitness.watchSessions(limit: 100).first;
    final recent = sessions
        .where((s) => !s.startedAt.isBefore(from))
        .toList();
    if (recent.isEmpty) {
      return ToolOutcome.ok('No workouts recorded $period.');
    }
    var durationSec = 0;
    var distanceMeters = 0;
    var calories = 0;
    for (final session in recent) {
      durationSec += session.durationSec;
      distanceMeters += session.distanceMeters;
      calories += session.calories;
    }
    final buffer = StringBuffer(
      '${recent.length} session(s) $period — '
      '${durationSec ~/ 60} min',
    );
    if (distanceMeters > 0) {
      buffer.write(', ${(distanceMeters / 1000).toStringAsFixed(2)} km');
    }
    if (calories > 0) buffer.write(', $calories kcal');
    return ToolOutcome.ok(buffer.toString());
  }

  Future<ToolOutcome> _noteSearch(Map<String, Object?> args) async {
    final query = args['query'] as String;
    final found = await notes.search(query).first;
    if (found.isEmpty) return ToolOutcome.ok('No notes match "$query".');
    final lines = [
      for (final note in found.take(5))
        '#${note.id} '
            '${note.title.isEmpty ? '(untitled)' : note.title} — '
            '${_excerpt(note.body, 80)}',
    ];
    return ToolOutcome.ok('${found.length} note(s):\n${lines.join('\n')}');
  }

  Future<ToolOutcome> _expenseSummary() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final totals = await finance.totals(monthStart, now);
    final balances = await finance.balances();
    var balancePaise = 0;
    for (final entry in balances) {
      balancePaise += entry.balancePaise;
    }
    final currency = localeCode();
    return ToolOutcome.ok(
      'Total balance: ${formatMoney(balancePaise, currency)}. '
      'This month: spent ${formatMoney(totals.expense, currency)}, '
      'earned ${formatMoney(totals.income, currency)}.',
    );
  }

  Future<ToolOutcome> _musicList(Map<String, Object?> args) async {
    final query = (args['query'] as String?)?.toLowerCase();
    final tracks = await music.allTracks();
    Iterable<MusicTrack> filtered = tracks;
    if (query != null && query.isNotEmpty) {
      filtered = tracks.where(
        (track) =>
            track.title.toLowerCase().contains(query) ||
            track.artist.toLowerCase().contains(query) ||
            track.album.toLowerCase().contains(query) ||
            track.genre.toLowerCase().contains(query),
      );
    }
    final top = filtered.take(15).toList();
    if (top.isEmpty) return const ToolOutcome.ok('No tracks match.');
    final lines = [
      for (final track in top)
        '#${track.id} ${track.title} — ${track.artist} '
            '(${_fmtDuration(track.durationMs)})',
    ];
    final more = filtered.length > top.length
        ? '\n(+${filtered.length - top.length} more)'
        : '';
    return ToolOutcome.ok('${filtered.length} track(s):\n${lines.join('\n')}$more');
  }

  Future<ToolOutcome> _memorySearch(Map<String, Object?> args) async {
    final query = args['query'] as String? ?? '';
    final all = await memories.all();
    if (all.isEmpty) return const ToolOutcome.ok('No memories saved yet.');
    final hits = rankMemories(memories: all, query: query, limit: 8);
    if (hits.isEmpty) return ToolOutcome.ok('No memories match.');
    final lines = [
      for (final hit in hits)
        '#${hit.record.id} [${hit.record.category.name}] ${hit.record.content}',
    ];
    return ToolOutcome.ok(lines.join('\n'));
  }

  Future<ToolOutcome> _deviceStatus() async {
    if (!device.isAvailable) {
      return const ToolOutcome.error(
        'Battery status needs the device bridge, which is not available in '
        'this build yet.',
      );
    }
    final battery = await device.batteryStatus();
    return ToolOutcome.ok(
      'Battery ${battery.level}%'
      '${battery.charging ? ', charging' : ', not charging'}.',
    );
  }

  // ---------------------------------------------------------------- creates

  Future<ToolOutcome> _taskCreate(Map<String, Object?> args) async {
    final title = args['title'] as String;
    final due = args['due'] as DateTime?;
    final (dueDate, minuteOfDay) = _splitDue(due);

    final id = await tasks.create(
      title: title,
      dueDate: dueDate,
      dueMinuteOfDay: minuteOfDay ?? -1,
      priority: _priorityFromArg(args['priority'] as String?),
    );
    return ToolOutcome.ok('Created task #$id "$title".');
  }

  Future<ToolOutcome> _eventCreate(Map<String, Object?> args) async {
    final title = args['title'] as String;
    final start = args['start'] as DateTime;
    final end = args['end'] as DateTime? ?? start.add(const Duration(hours: 1));
    if (!end.isAfter(start)) {
      return const ToolOutcome.error(
        'The end time must be after the start time.',
      );
    }
    final id = await events.create(
      title: title,
      startAt: start,
      endAt: end,
      location: args['location'] as String? ?? '',
    );
    return ToolOutcome.ok(
      'Created event #$id "$title" at ${_fmtDateTime(start)}.',
    );
  }

  Future<ToolOutcome> _reminderCreate(Map<String, Object?> args) async {
    final text = args['text'] as String;
    final fireAt = args['fire_at'] as DateTime;
    if (!fireAt.isAfter(DateTime.now())) {
      return const ToolOutcome.error(
        'That time has already passed — pick a future time.',
      );
    }
    final id = await prefs.nextJarvisReminderId();
    await reminders.scheduleReminder(
      id: id,
      title: 'Reminder',
      body: text,
      when: fireAt,
    );
    return ToolOutcome.ok('Reminder set for ${_fmtDateTime(fireAt)}: "$text".');
  }

  Future<ToolOutcome> _alarmSet(Map<String, Object?> args) async {
    final hour = args['hour'] as int;
    final minute = args['minute'] as int;
    final label = args['label'] as String? ?? '';
    final days = (args['days'] as List<int>?) ?? const <int>[];
    var mask = 0;
    for (final day in days) {
      mask |= 1 << day;
    }
    final id = await alarms.create(
      hour: hour,
      minute: minute,
      label: label,
      isEnabled: true,
      oneTime: mask == 0,
      repeatDaysMask: mask,
    );
    return ToolOutcome.ok(
      'Alarm #$id set for ${_fmtClock(hour, minute)}'
      '${mask == 0 ? ' (one-time)' : ' on ${_daysLabel(mask)}'}.',
    );
  }

  Future<ToolOutcome> _habitLog(Map<String, Object?> args) async {
    final match = args['match'] as String;
    final active = await habits.watchActive().first;
    final resolution = resolveMatch(
      active,
      match,
      (habit) => habit.name,
      (habit) => habit.id,
    );
    switch (resolution.kind) {
      case MatchKind.none:
        return ToolOutcome.notFound('No active habit matches "$match".');
      case MatchKind.multiple:
        return _ambiguous('habits', resolution.items, (h) => h.name, (h) => h.id);
      case MatchKind.single:
        final habit = resolution.single;
        if (await habits.isCompleted(habit.id, DateTime.now())) {
          return ToolOutcome.ok('"${habit.name}" is already logged today.');
        }
        await habits.setCompleted(habit.id, DateTime.now(), completed: true);
        return ToolOutcome.ok('Logged "${habit.name}" for today.');
    }
  }

  Future<ToolOutcome> _noteCreate(Map<String, Object?> args) async {
    final body = args['body'] as String;
    final id = await notes.create(
      title: args['title'] as String? ?? '',
      body: body,
    );
    return ToolOutcome.ok('Created note #$id.');
  }

  Future<ToolOutcome> _memorySave(Map<String, Object?> args) async {
    final content = args['content'] as String;
    final category = memoryCategoryFromDb(args['category'] as String?);
    final id = await memories.save(content: content, category: category);
    return ToolOutcome.ok(
      'Saved memory #$id (${category.name}). It is pending the user\'s '
      'confirmation.',
    );
  }

  Future<ToolOutcome> _expenseCreate(Map<String, Object?> args) async {
    final amount = args['amount'] as double;
    final paise = (amount * 100).round();
    final type = args['type'] == 'income'
        ? TransactionType.income
        : TransactionType.expense;
    final note = args['note'] as String? ?? '';
    final categoryName = args['category'] as String?;

    int? categoryId;
    if (categoryName != null) {
      final categories = await finance.watchCategories().first;
      final needle = categoryName.toLowerCase();
      Category? match;
      for (final category in categories) {
        if (category.name.toLowerCase() == needle) {
          match = category;
          break;
        }
      }
      match ??= () {
        for (final category in categories) {
          if (category.name.toLowerCase().contains(needle)) return category;
        }
        return null;
      }();
      if (match == null) {
        final names = categories.take(12).map((c) => c.name).join(', ');
        return ToolOutcome.error(
          'No category named "$categoryName". Available: $names.',
        );
      }
      categoryId = match.id;
    }

    final accounts = await finance.watchAccounts().first;
    if (accounts.isEmpty) {
      return const ToolOutcome.error(
        'No account exists yet — add one in Expenses before recording '
        'transactions.',
      );
    }
    final id = await finance.addTransaction(
      accountId: accounts.first.id,
      type: type,
      amountPaise: paise,
      date: DateTime.now(),
      categoryId: categoryId,
      note: note,
    );
    final currency = localeCode();
    return ToolOutcome.ok(
      'Recorded ${type == TransactionType.income ? 'income' : 'expense'} '
      '#$id of ${formatMoney(paise, currency)}.',
    );
  }

  // ---------------------------------------------------------------- updates

  Future<ToolOutcome> _taskComplete(Map<String, Object?> args) async {
    final match = args['match'] as String;
    final all = await _allTasks();
    final resolution = resolveMatch(
      all,
      match,
      (task) => task.title,
      (task) => task.id,
    );
    switch (resolution.kind) {
      case MatchKind.none:
        return ToolOutcome.notFound('No task matches "$match".');
      case MatchKind.multiple:
        return _ambiguous('tasks', resolution.items, (t) => t.title, (t) => t.id);
      case MatchKind.single:
        final task = resolution.single;
        if (task.isCompleted) {
          return ToolOutcome.ok('"${task.title}" is already done.');
        }
        await tasks.setCompleted(task, true);
        return ToolOutcome.ok('Marked "${task.title}" as done.');
    }
  }

  Future<ToolOutcome> _taskUpdate(Map<String, Object?> args) async {
    final match = args['match'] as String;
    final all = await _allTasks();
    final resolution = resolveMatch(
      all,
      match,
      (task) => task.title,
      (task) => task.id,
    );
    switch (resolution.kind) {
      case MatchKind.none:
        return ToolOutcome.notFound('No task matches "$match".');
      case MatchKind.multiple:
        return _ambiguous('tasks', resolution.items, (t) => t.title, (t) => t.id);
      case MatchKind.single:
        final task = resolution.single;
        final newTitle = args['new_title'] as String?;
        final due = args['due'] as DateTime?;
        final (dueDate, minuteOfDay) = due == null
            ? (null, null)
            : _splitDue(due);

        final updated = task.copyWith(
          title: newTitle ?? task.title,
          dueDate: Value(due == null ? task.dueDate : dueDate),
          dueMinuteOfDay: due == null
              ? task.dueMinuteOfDay
              : (minuteOfDay ?? -1),
          priority:
              args['priority'] == null
                  ? task.priority
                  : _priorityFromArg(args['priority'] as String?).index,
        );
        await tasks.updateTask(updated);
        return ToolOutcome.ok('Updated task #${task.id}.');
    }
  }

  Future<ToolOutcome> _musicPlay(Map<String, Object?> args) async {
    final match = args['match'] as String?;
    if (match == null || match.trim().isEmpty) {
      if (player.isPlaying) {
        return ToolOutcome.ok(
          'Already playing ${player.current?.title ?? 'music'}.',
        );
      }
      final current = player.current;
      if (current != null) {
        await player.resume();
        return ToolOutcome.ok('Resumed "${current.title}".');
      }
      return const ToolOutcome.notFound(
        'Nothing is loaded — name a track or artist to play.',
      );
    }

    final tracks = await music.allTracks();
    final filtered = tracks
        .where(
          (track) =>
              track.title.toLowerCase().contains(match.toLowerCase()) ||
              track.artist.toLowerCase().contains(match.toLowerCase()),
        )
        .take(30)
        .toList();
    final resolution = resolveMatch(
      filtered,
      match,
      (track) => '${track.title} — ${track.artist}',
      (track) => track.id,
    );
    switch (resolution.kind) {
      case MatchKind.none:
        return ToolOutcome.notFound('No track matches "$match".');
      case MatchKind.multiple:
        return _ambiguous(
          'tracks',
          resolution.items,
          (t) => '${t.title} — ${t.artist}',
          (t) => t.id,
        );
      case MatchKind.single:
        final track = resolution.single;
        await player.playTrack(track);
        return ToolOutcome.ok(
          'Playing "${track.title}" by ${track.artist}.',
        );
    }
  }

  Future<ToolOutcome> _alarmToggle(Map<String, Object?> args) async {
    final match = args['match'] as String;
    final enabled = args['enabled'] as bool;
    final all = await alarms.watchAll().first;
    String labelOf(Alarm alarm) {
      final time = _fmtClock(alarm.hour, alarm.minute);
      return alarm.label.isEmpty ? time : '$time ${alarm.label}';
    }

    final resolution = resolveMatch(all, match, labelOf, (alarm) => alarm.id);
    switch (resolution.kind) {
      case MatchKind.none:
        return ToolOutcome.notFound('No alarm matches "$match".');
      case MatchKind.multiple:
        return _ambiguous('alarms', resolution.items, labelOf, (a) => a.id);
      case MatchKind.single:
        final alarm = resolution.single;
        await alarms.setEnabled(alarm.id, enabled);
        return ToolOutcome.ok(
          'Alarm #${alarm.id} ${enabled ? 'enabled' : 'disabled'}.',
        );
    }
  }

  // ------------------------------------------------------------- destructive

  Future<ToolOutcome> _taskDelete(Map<String, Object?> args) async {
    final match = args['match'] as String;
    final all = await _allTasks();
    final resolution = resolveMatch(
      all,
      match,
      (task) => task.title,
      (task) => task.id,
    );
    switch (resolution.kind) {
      case MatchKind.none:
        return ToolOutcome.notFound('No task matches "$match".');
      case MatchKind.multiple:
        return _ambiguous('tasks', resolution.items, (t) => t.title, (t) => t.id);
      case MatchKind.single:
        final task = resolution.single;
        await tasks.delete(task.id);
        return ToolOutcome.ok('Deleted task "${task.title}".');
    }
  }

  Future<ToolOutcome> _alarmDelete(Map<String, Object?> args) async {
    final match = args['match'] as String;
    final all = await alarms.watchAll().first;
    String labelOf(Alarm alarm) {
      final time = _fmtClock(alarm.hour, alarm.minute);
      return alarm.label.isEmpty ? time : '$time ${alarm.label}';
    }

    final resolution = resolveMatch(all, match, labelOf, (alarm) => alarm.id);
    switch (resolution.kind) {
      case MatchKind.none:
        return ToolOutcome.notFound('No alarm matches "$match".');
      case MatchKind.multiple:
        return _ambiguous('alarms', resolution.items, labelOf, (a) => a.id);
      case MatchKind.single:
        final alarm = resolution.single;
        await alarms.delete(alarm.id);
        return ToolOutcome.ok(
          'Deleted alarm at ${_fmtClock(alarm.hour, alarm.minute)}.',
        );
    }
  }

  Future<ToolOutcome> _memoryForget(Map<String, Object?> args) async {
    final match = args['match'] as String;

    // An all-digits match is the id the model picked from an ambiguity.
    final asId = int.tryParse(match.trim());
    if (asId != null) {
      final byId = await memories.getById(asId);
      if (byId != null) {
        await memories.delete(byId.id);
        return ToolOutcome.ok('Forgot: "${byId.content}".');
      }
    }

    final all = await memories.all();
    final hits = matchMemories(all, match);
    if (hits.isEmpty) {
      return ToolOutcome.notFound('No memory matches "$match".');
    }
    if (hits.length > 1) {
      return _ambiguous(
        'memories',
        hits,
        (memory) => _excerpt(memory.content, 60),
        (memory) => memory.id,
      );
    }
    final memory = hits.single;
    await memories.delete(memory.id);
    return ToolOutcome.ok('Forgot: "${memory.content}".');
  }

  // ------------------------------------------------- device bridge passthru

  Future<ToolOutcome> _deviceOpenApp(Map<String, Object?> args) async {
    final package = args['package'] as String;
    final opened = await device.openApp(package);
    return opened
        ? ToolOutcome.ok('Opened $package.')
        : ToolOutcome.notFound('Could not open $package — is it installed?');
  }

  Future<ToolOutcome> _deviceOpenSettings(Map<String, Object?> args) async {
    final page = args['page'] as String;
    final opened = await device.openSettings(page);
    return opened
        ? ToolOutcome.ok('Opened the $page settings page.')
        : ToolOutcome.error('Could not open the $page settings page.');
  }

  // -------------------------------------------------------------- internals

  Future<List<Task>> _allTasks() async {
    final rows = await tasks.watchAll().first;
    return [for (final row in rows) ...[row.task, ...row.subtasks]];
  }

  ToolOutcome _ambiguous<T>(
    String what,
    List<T> items,
    String Function(T) label,
    int Function(T) id,
  ) {
    final top = items.take(5).toList();
    final choices = [
      for (final item in top) ToolChoice(id(item), label(item)),
    ];
    final lines = [for (final choice in choices) choice.toString()];
    return ToolOutcome.ambiguous(
      'Several $what match. Ask the user which one they mean, then call the '
      'tool again with "match" set to the id or the exact label.\n'
      '${lines.join('\n')}',
      choices,
    );
  }

  TaskPriority _priorityFromArg(String? raw) => switch (raw) {
    'low' => TaskPriority.low,
    'high' => TaskPriority.high,
    _ => TaskPriority.medium,
  };

  /// Splits a due date-time into a date-only [DateTime] and a minute-of-day
  /// (-1 when the model gave a plain date with no time).
  (DateTime?, int?) _splitDue(DateTime? due) {
    if (due == null) return (null, null);
    final date = DateTime(due.year, due.month, due.day);
    final minuteOfDay = (due.hour == 0 && due.minute == 0)
        ? -1
        : due.hour * 60 + due.minute;
    return (date, minuteOfDay);
  }
}

final jarvisToolExecutorProvider = Provider<ToolExecutor>((ref) {
  return ToolExecutor(
    tasks: ref.watch(taskRepositoryProvider),
    events: ref.watch(eventRepositoryProvider),
    alarms: ref.watch(alarmRepositoryProvider),
    habits: ref.watch(habitRepositoryProvider),
    fitness: ref.watch(fitnessRepositoryProvider),
    notes: ref.watch(noteRepositoryProvider),
    finance: ref.watch(financeRepositoryProvider),
    music: ref.watch(musicRepositoryProvider),
    memories: ref.watch(jarvisMemoryRepositoryProvider),
    player: _RiverpodMusicPlayback(ref),
    device: const AndroidDeviceBridge(),
    reminders: ref.watch(notificationServiceProvider),
    prefs: ref.watch(appPreferencesProvider),
    localeCode: () => ref.read(localeCodeProvider) ?? 'en',
  );
});

class _RiverpodMusicPlayback implements MusicPlaybackPort {
  _RiverpodMusicPlayback(this._ref);

  final Ref _ref;

  PlayerState get _state => _ref.read(musicPlayerProvider);

  @override
  bool get isPlaying => _state.playing;

  @override
  MusicTrack? get current => _state.current;

  @override
  Future<void> playTrack(MusicTrack track) =>
      _ref.read(musicPlayerProvider.notifier).playTrack(track);

  @override
  Future<void> resume() async {
    final state = _state;
    if (!state.playing && state.hasTrack) {
      await _ref.read(musicPlayerProvider.notifier).togglePlay();
    }
  }
}

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _weekdayNames = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

String _pad2(int value) => value.toString().padLeft(2, '0');

String _fmtClock(int hour, int minute) => '${_pad2(hour)}:${_pad2(minute)}';

String _fmtMinuteOfDay(int minuteOfDay) =>
    _fmtClock(minuteOfDay ~/ 60, minuteOfDay % 60);

String _fmtDate(DateTime date) =>
    '${_pad2(date.day)} ${_monthNames[date.month - 1]}';

String _fmtDateTime(DateTime date) =>
    '${_fmtDate(date)} ${_fmtClock(date.hour, date.minute)}';

String _fmtDuration(int millis) {
  final totalSeconds = millis ~/ 1000;
  return '${totalSeconds ~/ 60}:${_pad2(totalSeconds % 60)}';
}

String _daysLabel(int mask) {
  final days = [
    for (var bit = 0; bit < 7; bit++)
      if (mask & (1 << bit) != 0) _weekdayNames[bit],
  ];
  return days.isEmpty ? '' : days.join(',');
}

String _excerpt(String text, int max) {
  final trimmed = text.trim();
  return trimmed.length <= max ? trimmed : '${trimmed.substring(0, max)}…';
}
