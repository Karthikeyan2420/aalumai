import 'package:aalumai/core/preferences/app_preferences.dart';
import 'package:aalumai/features/jarvis/assistant_engine/calculator.dart' as calc;
import 'package:aalumai/features/jarvis/assistant_engine/intent.dart';
import 'package:aalumai/features/jarvis/assistant_engine/intent_matcher.dart';
import 'package:aalumai/features/jarvis/conversation/assistant_reply.dart';
import 'package:aalumai/features/jarvis/data/tool_executor.dart';
import 'package:aalumai/features/jarvis/domain/safety_policy.dart';
import 'package:aalumai/features/jarvis/domain/tool_outcome.dart';
import 'package:aalumai/features/jarvis/knowledge/knowledge_base.dart';
import 'package:aalumai/features/jarvis/maps/maps_service.dart';
import 'package:aalumai/features/jarvis/web_search/search_result.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Orchestrates the whole model-free assistant pipeline:
///
/// 1. Match the utterance to a deterministic [Intent].
/// 2. Answer conversational intents directly.
/// 3. Resolve app commands through the [ToolExecutor] (with the safety
///    policy gating sensitive actions).
/// 4. Fall back to the local [KnowledgeBase], then online providers.
///
/// Nothing here calls a language model. Every path is either a rule, a
/// repository read/write, or a documented web API.
class AssistantEngine {
  AssistantEngine({
    required this.executor,
    required this.prefs,
    KnowledgeBase? knowledge,
    this.webSearch,
    this.maps,
    IntentMatcher? matcher,
    DateTime Function()? clock,
  })  : knowledge = knowledge ?? KnowledgeBase(),
        matcher = matcher ?? IntentMatcher(clock: clock),
        _now = clock ?? DateTime.now;

  final ToolExecutor executor;
  final AppPreferences prefs;
  final KnowledgeBase knowledge;
  final WebSearchPort? webSearch;
  final MapsService? maps;
  final IntentMatcher matcher;

  final DateTime Function() _now;

  /// Last knowledge entry discussed, for "tell me more" follow-ups.
  KnowledgeEntry? _lastKnowledge;

  /// Clears conversational follow-up state (called when the chat is cleared).
  void reset() {
    _lastKnowledge = null;
  }

  /// Produces an assistant reply for [input].
  Future<AssistantReply> respond(String input) async {
    final intent = matcher.match(input);
    switch (intent.kind) {
      case IntentKind.greeting:
        return _greeting();
      case IntentKind.howAreYou:
        return AssistantReply.answer(
          'I am running well, thank you for asking. How can I help?',
        );
      case IntentKind.whoAreYou:
        return AssistantReply.answer(
          'I am AALUMAI, your on-device assistant. I do not use a language '
          'model — I answer from rules, your data, and trusted sources.',
        );
      case IntentKind.whoAmI:
        final name = prefs.assistantUserName.trim();
        return AssistantReply.answer(
          name.isEmpty
              ? 'I do not know your name yet. You can tell me "remember my '
                  'name is ..." and I will keep it.'
              : 'Your name is $name.',
        );
      case IntentKind.thanks:
        return AssistantReply.answer('You are welcome.');
      case IntentKind.goodbye:
        return AssistantReply.answer('Goodbye. I am here whenever you need me.');
      case IntentKind.help:
        return AssistantReply.answer(_helpText);
      case IntentKind.followUpMore:
      case IntentKind.followUpWhy:
        return _followUpMore();
      case IntentKind.time:
        return AssistantReply.answer('It is ${_formatTime(_now())}.');
      case IntentKind.date:
        return AssistantReply.answer('Today is ${_formatDate(_now())}.');
      case IntentKind.dayOfWeek:
        return AssistantReply.answer('Today is ${_weekday(_now())}.');
      case IntentKind.tomorrow:
        return AssistantReply.answer(
          'Tomorrow is ${_formatDate(_now().add(const Duration(days: 1)))}.',
        );
      case IntentKind.yesterday:
        return AssistantReply.answer(
          'Yesterday was ${_formatDate(_now().subtract(const Duration(days: 1)))}.',
        );
      case IntentKind.calculate:
        return _calculate(intent);
      case IntentKind.convertUnit:
        return _convert(intent);
      case IntentKind.battery:
      case IntentKind.taskList:
      case IntentKind.taskCreate:
      case IntentKind.taskComplete:
      case IntentKind.taskDelete:
      case IntentKind.eventList:
      case IntentKind.alarmList:
      case IntentKind.alarmSet:
      case IntentKind.alarmToggle:
      case IntentKind.alarmDelete:
      case IntentKind.habitList:
      case IntentKind.habitLog:
      case IntentKind.noteCreate:
      case IntentKind.noteSearch:
      case IntentKind.expenseSummary:
      case IntentKind.expenseCreate:
      case IntentKind.workoutSummary:
      case IntentKind.musicPlay:
      case IntentKind.memorySave:
      case IntentKind.memorySearch:
      case IntentKind.memoryForget:
      case IntentKind.openApp:
      case IntentKind.openSettings:
        return _runAction(intent);
      case IntentKind.setTimer:
      case IntentKind.setReminder:
        return _runReminder(intent);
      case IntentKind.weather:
        return _weather();
      case IntentKind.nearby:
        return _nearby(intent);
      case IntentKind.question:
        return _answerQuestion(intent.text);
      case IntentKind.unknown:
        return const AssistantReply(
          text: 'I did not catch that. Could you say it another way?',
          kind: ReplyKind.unknown,
        );
    }
  }

  /// Executes a confirmed action, e.g. after the user taps "Confirm".
  Future<AssistantReply> runConfirmed(
    String tool,
    Map<String, Object?> args,
  ) async {
    final outcome = await executor.execute(tool, args);
    final reply = AssistantReply.fromOutcome(tool, outcome);
    if (outcome.kind == ToolOutcomeKind.ok && tool == 'memory.save') {
      // Keep the assistant's name preference in sync if the user told us.
    }
    return reply;
  }

  // --------------------------------------------------------------- helpers

  AssistantReply _greeting() {
    final name = prefs.assistantUserName.trim();
    final part = _partOfDay();
    final who = name.isEmpty ? '' : ', $name';
    return AssistantReply.answer(
      'Good $part$who. How can I help you?',
    );
  }

  String _partOfDay() {
    final hour = _now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  AssistantReply _calculate(Intent intent) {
    final value = intent.slot<num>('value');
    if (value == null) {
      return const AssistantReply(
        text: 'I could not work out that expression.',
        kind: ReplyKind.unknown,
      );
    }
    final expression = intent.text
        .replaceAll(RegExp(r'^(please\s+)?(calculate|compute|what is|whats)\s+',
            caseSensitive: false), '')
        .replaceAll(RegExp(r'[?=]+\s*$'), '')
        .trim();
    return AssistantReply.answer(
      '${expression.isEmpty ? 'The answer' : expression} = '
      '${calc.formatNumber(value.toDouble())}.',
    );
  }

  AssistantReply _convert(Intent intent) {
    final conversion = intent.slots['conversion'];
    if (conversion is! calc.UnitConversion) {
      return const AssistantReply(
        text: 'I could not work out that conversion.',
        kind: ReplyKind.unknown,
      );
    }
    return AssistantReply.answer(conversion.describe());
  }

  AssistantReply _followUpMore() {
    final entry = _lastKnowledge;
    if (entry == null) {
      return const AssistantReply(
        text: 'More about what? Ask me a question and I will expand on it.',
        kind: ReplyKind.unknown,
      );
    }
    final body = entry.body.isNotEmpty ? entry.body : entry.summary;
    return AssistantReply(
      text: body,
      kind: ReplyKind.knowledge,
      spokenText: body,
    );
  }

  Future<AssistantReply> _runAction(Intent intent) async {
    final call = _toolFor(intent);
    if (call == null) {
      return const AssistantReply(
        text: 'I did not understand that command. Try rephrasing it.',
        kind: ReplyKind.unknown,
      );
    }
    final (tool, args) = call;
    final decision = decideAction(tool);
    if (decision == Decision.confirm) {
      return AssistantReply(
        text: '${describeAction(tool, args)} Shall I go ahead?',
        kind: ReplyKind.confirm,
        pendingTool: tool,
        pendingArgs: args,
        spokenText: describeAction(tool, args),
      );
    }
    final outcome = await executor.execute(tool, args);
    return AssistantReply.fromOutcome(tool, outcome);
  }

  /// Maps an action intent to a `(tool, args)` pair.
  (String, Map<String, Object?>)? _toolFor(Intent intent) {
    final slots = intent.slots;
    switch (intent.kind) {
      case IntentKind.battery:
        return ('device.status', const {});
      case IntentKind.taskList:
        return ('task.list', const {});
      case IntentKind.taskCreate:
        final title = intent.slot<String>('title') ?? '';
        if (title.isEmpty) return null;
        return ('task.create', {'title': title});
      case IntentKind.taskComplete:
        final match = intent.slot<String>('match') ?? '';
        if (match.isEmpty) return null;
        return ('task.complete', {'match': match});
      case IntentKind.taskDelete:
        final match = intent.slot<String>('match') ?? '';
        if (match.isEmpty) return null;
        return ('task.delete', {'match': match});
      case IntentKind.eventList:
        return ('event.list', {'when': slots['when'] ?? 'today'});
      case IntentKind.alarmList:
        return ('alarm.list', const {});
      case IntentKind.alarmSet:
        final hour = intent.slot<int>('hour');
        final minute = intent.slot<int>('minute');
        if (hour == null || minute == null) return null;
        return ('alarm.set', {
          'hour': hour,
          'minute': minute,
          if (slots['label'] != null) 'label': slots['label'],
          if (slots['days'] != null) 'days': slots['days'],
        });
      case IntentKind.alarmToggle:
        final match = intent.slot<String>('match') ?? '';
        final enabled = slots['enabled'];
        if (match.isEmpty || enabled is! bool) return null;
        return ('alarm.toggle', {'match': match, 'enabled': enabled});
      case IntentKind.alarmDelete:
        final match = intent.slot<String>('match') ?? '';
        if (match.isEmpty) return null;
        return ('alarm.delete', {'match': match});
      case IntentKind.habitList:
        return ('habit.list', const {});
      case IntentKind.habitLog:
        final match = intent.slot<String>('match') ?? '';
        if (match.isEmpty) return null;
        return ('habit.log', {'match': match});
      case IntentKind.noteCreate:
        final body = intent.slot<String>('body') ?? '';
        if (body.isEmpty) return null;
        return ('note.create', {'body': body});
      case IntentKind.noteSearch:
        final query = intent.slot<String>('query') ?? '';
        if (query.isEmpty) return null;
        return ('note.search', {'query': query});
      case IntentKind.expenseSummary:
        return ('expense.summary', const {});
      case IntentKind.expenseCreate:
        final amount = intent.slot<num>('amount');
        if (amount == null || amount <= 0) return null;
        return ('expense.create', {
          'amount': amount.toDouble(),
          'type': slots['type'] ?? 'expense',
          if ((slots['note'] as String?)?.isNotEmpty ?? false)
            'note': slots['note'],
        });
      case IntentKind.workoutSummary:
        return ('workout.summary', {'period': slots['period'] ?? 'today'});
      case IntentKind.musicPlay:
        return ('music.play', {
          if (slots['match'] != null) 'match': slots['match'],
        });
      case IntentKind.memorySave:
        final content = intent.slot<String>('content') ?? '';
        if (content.isEmpty) return null;
        return ('memory.save', {'content': content});
      case IntentKind.memorySearch:
        return ('memory.search', {
          if ((slots['query'] as String?)?.isNotEmpty ?? false)
            'query': slots['query'],
        });
      case IntentKind.memoryForget:
        final match = intent.slot<String>('match') ?? '';
        if (match.isEmpty) return null;
        return ('memory.forget', {'match': match});
      case IntentKind.openApp:
        final package = intent.slot<String>('package') ?? '';
        if (package.isEmpty) return null;
        return ('device.open_app', {'package': package});
      case IntentKind.openSettings:
        final page = intent.slot<String>('page') ?? '';
        if (page.isEmpty) return null;
        return ('device.open_settings', {'page': page});
      default:
        return null;
    }
  }

  Future<AssistantReply> _runReminder(Intent intent) async {
    if (intent.kind == IntentKind.setTimer) {
      final seconds = intent.slot<int>('duration_seconds');
      if (seconds == null || seconds <= 0) {
        return const AssistantReply(
          text: 'How long should the timer be?',
          kind: ReplyKind.unknown,
        );
      }
      final minutes = (seconds / 60).round();
      final label = minutes >= 1
          ? '$minutes minute timer'
          : '$seconds second timer';
      final outcome = await executor.execute('reminder.create', {
        'text': label,
        'fire_at': _now().add(Duration(seconds: seconds)),
      });
      return AssistantReply.fromOutcome('reminder.create', outcome);
    }
    // setReminder
    final seconds = intent.slot<int>('duration_seconds');
    final text = intent.slot<String>('text') ?? 'Reminder';
    final fireAt = _now().add(Duration(seconds: seconds ?? 600));
    final outcome = await executor.execute('reminder.create', {
      'text': text,
      'fire_at': fireAt,
    });
    final reply = AssistantReply.fromOutcome('reminder.create', outcome);
    if (reply.kind == ReplyKind.action) {
      final when = _formatDateTime(fireAt);
      return AssistantReply(
        text: 'Okay, I will remind you to $text at $when.',
        kind: ReplyKind.action,
      );
    }
    return reply;
  }

  Future<AssistantReply> _weather() async {
    final search = webSearch;
    final mapService = maps;
    if (search == null || mapService == null) {
      return const AssistantReply(
        text: 'Weather needs an internet connection.',
        kind: ReplyKind.unknown,
      );
    }
    if (!prefs.assistantOnlineSearchEnabled) {
      return const AssistantReply(
        text: 'Online lookups are turned off. Enable them in assistant '
            'settings to get the weather.',
        kind: ReplyKind.unknown,
      );
    }
    try {
      if (!await search.isOnline) {
        return const AssistantReply(
          text: 'You appear to be offline, so I cannot fetch the weather.',
          kind: ReplyKind.unknown,
        );
      }
      final position = await mapService.currentPosition();
      final result = await search.weather(position.latitude, position.longitude);
      if (result == null) {
        return const AssistantReply(
          text: 'I could not get the weather right now.',
          kind: ReplyKind.unknown,
        );
      }
      return AssistantReply(
        text: result.summary,
        kind: ReplyKind.online,
        sources: [result],
        spokenText: result.summary,
      );
    } on LocationException catch (e) {
      return AssistantReply(text: e.message, kind: ReplyKind.unknown);
    } catch (e) {
      return _onlineFailure(e);
    }
  }

  Future<AssistantReply> _nearby(Intent intent) async {
    final mapService = maps;
    if (mapService == null) {
      return const AssistantReply(
        text: 'Nearby search is not available in this build.',
        kind: ReplyKind.unknown,
      );
    }
    if (!prefs.assistantOnlineSearchEnabled) {
      return const AssistantReply(
        text: 'Online lookups are turned off. Enable them in assistant '
            'settings to search nearby places.',
        kind: ReplyKind.unknown,
      );
    }
    final query = intent.slot<String>('query') ?? '';
    if (query.isEmpty) {
      return const AssistantReply(
        text: 'What would you like me to find nearby?',
        kind: ReplyKind.unknown,
      );
    }
    try {
      final position = await mapService.currentPosition();
      final centre = LatLng(position.latitude, position.longitude);
      final results = await mapService.searchNearby(query, around: centre);
      if (results.isEmpty) {
        return AssistantReply(
          text: 'I could not find any $query near you.',
          kind: ReplyKind.unknown,
        );
      }
      final buffer = StringBuffer('Here is what I found nearby:\n');
      for (final place in results.take(5)) {
        buffer.write('• ${place.name} — ${place.describeDistanceFrom(centre)}');
        if (place.address.isNotEmpty) buffer.write(' (${place.address})');
        buffer.write('\n');
      }
      return AssistantReply(
        text: buffer.toString().trim(),
        kind: ReplyKind.online,
        sources: [
          SearchResult(
            title: 'OpenStreetMap',
            summary: 'Places data from OpenStreetMap contributors.',
            sourceUrl: 'https://www.openstreetmap.org/'
                '#map=15/${centre.latitude}/${centre.longitude}',
            sourceName: 'OpenStreetMap',
          ),
        ],
        spokenText: 'I found ${results.length} places nearby. '
            'The closest is ${results.first.name}, '
            '${results.first.describeDistanceFrom(centre)} away.',
      );
    } on LocationException catch (e) {
      return AssistantReply(text: e.message, kind: ReplyKind.unknown);
    } catch (e) {
      return _onlineFailure(e);
    }
  }

  Future<AssistantReply> _answerQuestion(String question) async {
    // 1. Local knowledge base.
    final match = knowledge.match(question);
    if (match != null && match.score >= KnowledgeBase.matchThreshold) {
      _lastKnowledge = match.entry;
      return AssistantReply(
        text: match.entry.summary,
        kind: ReplyKind.knowledge,
        spokenText: match.entry.summary,
      );
    }

    // 2. Online fallback (if allowed and available).
    final search = webSearch;
    if (search != null && prefs.assistantOnlineSearchEnabled) {
      try {
        if (await search.isOnline) {
          final result = await search.encyclopedia(
            question,
            language: prefs.assistantSpeechLanguage,
          );
          if (result != null) {
            return AssistantReply(
              text: result.summary,
              kind: ReplyKind.online,
              sources: [result],
              spokenText: result.summary,
            );
          }
        }
      } catch (e) {
        debugPrint('Online question lookup failed: $e');
        // Fall through to the honest offline answer.
      }
    }

    // 3. Honest fallback — never invent.
    if (match != null) {
      _lastKnowledge = match.entry;
      return AssistantReply(
        text: match.entry.summary,
        kind: ReplyKind.knowledge,
        spokenText: match.entry.summary,
      );
    }
    final onlineHint = prefs.assistantOnlineSearchEnabled
        ? 'and I could not find an answer online'
        : 'and online lookups are turned off';
    return AssistantReply(
      text: 'Sorry, I do not know that $onlineHint. I will not guess.',
      kind: ReplyKind.unknown,
    );
  }

  AssistantReply _onlineFailure(Object error) {
    if (error is WebSearchException) {
      return AssistantReply(text: error.message, kind: ReplyKind.unknown);
    }
    return const AssistantReply(
      text: 'I could not reach the internet for that.',
      kind: ReplyKind.unknown,
    );
  }

  // --------------------------------------------------------- formatting

  String _formatTime(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final meridiem = t.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $meridiem';
  }

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _formatDate(DateTime d) =>
      '${_weekday(d)}, ${d.day} ${_months[d.month - 1]} ${d.year}';

  String _weekday(DateTime d) => const [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
    'Sunday',
  ][d.weekday - 1];

  String _formatDateTime(DateTime d) =>
      '${_formatTime(d)} on ${d.day} ${_months[d.month - 1]}';

  static const _helpText =
      'I can help with:\n'
      '• Time, date and day\n'
      '• Maths and unit conversions\n'
      '• Timers and reminders\n'
      '• Alarms, tasks, habits and notes\n'
      '• Expenses, workouts and music\n'
      '• Battery, opening apps and settings\n'
      '• The weather and nearby places\n'
      '• General questions from my knowledge base or the web\n'
      'Just ask in plain language.';

  /// Rounds a double for display (kept public for tests).
  static double round(double value, [int places = 2]) =>
      calc.roundTo(value, places);
}
