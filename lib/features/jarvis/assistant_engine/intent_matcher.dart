/// Deterministic intent matcher: turns a normalised user utterance into an
/// [Intent] without any language model.
///
/// Rules are ordered by specificity: the first pattern that matches wins.
/// Anything that matches nothing becomes [IntentKind.question], which the
/// engine then resolves against the local knowledge base and, failing that,
/// the web-search providers.
library;

import 'calculator.dart' as calc;
import 'intent.dart';
import 'text_normalizer.dart';

class IntentMatcher {
  IntentMatcher({DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final DateTime Function() _now;

  /// Recognises [input] and returns the best [Intent].
  Intent match(String input) {
    final original = input.trim();
    final text = canonicalize(original);
    if (text.isEmpty) return Intent(IntentKind.unknown, text: original);

    for (final rule in _rules) {
      final slots = rule.tryMatch(text, _now());
      if (slots != null) {
        return Intent(rule.kind, text: original, slots: slots);
      }
    }
    return Intent(IntentKind.question, text: original);
  }

  static final List<_Rule> _rules = _buildRules();
}

/// A single matching rule: [tryMatch] returns extracted slots on a hit or
/// `null` on a miss.
class _Rule {
  const _Rule(this.kind, this.tryMatch);

  final IntentKind kind;
  final Map<String, Object?>? Function(String text, DateTime now) tryMatch;
}

_TimeSlot? _parseTimeOfDay(String text) {
  // "7", "7:30", "7 30", "07:30", "7 pm", "half past 7", "quarter to 8"
  final hm = RegExp(r'\b(\d{1,2})[:.](\d{2})\s*(am|pm)?\b').firstMatch(text);
  if (hm != null) {
    var hour = int.parse(hm.group(1)!);
    final minute = int.parse(hm.group(2)!);
    final meridiem = hm.group(3);
    hour = _applyMeridiem(hour, meridiem, text);
    return _TimeSlot(hour, minute);
  }

  final hp = RegExp(r'half past\s+(\d{1,2})').firstMatch(text);
  if (hp != null) {
    return _TimeSlot(
      _applyMeridiem(int.parse(hp.group(1)!), null, text),
      30,
    );
  }
  final qt = RegExp(r'quarter to\s+(\d{1,2})').firstMatch(text);
  if (qt != null) {
    final hour = _applyMeridiem(int.parse(qt.group(1)!), null, text) - 1;
    return _TimeSlot((hour + 24) % 24, 45);
  }
  final qp = RegExp(r'quarter past\s+(\d{1,2})').firstMatch(text);
  if (qp != null) {
    return _TimeSlot(
      _applyMeridiem(int.parse(qp.group(1)!), null, text),
      15,
    );
  }

  final ampm = RegExp(r'\b(\d{1,2})\s*(am|pm)\b').firstMatch(text);
  if (ampm != null) {
    final hour = _applyMeridiem(
      int.parse(ampm.group(1)!),
      ampm.group(2),
      text,
    );
    return _TimeSlot(hour, 0);
  }

  final hourOnly =
      RegExp(r'\b(?:at|for|wake me at)\s+(\d{1,2})\b').firstMatch(text);
  if (hourOnly != null) {
    return _TimeSlot(_applyMeridiem(int.parse(hourOnly.group(1)!), null, text), 0);
  }
  return null;
}

int _applyMeridiem(int hour, String? meridiem, String text) {
  final hasPm = meridiem == 'pm' || text.contains('evening') || text.contains('night');
  final hasAm = meridiem == 'am' || text.contains('morning');
  if (hasPm && hour < 12) return hour + 12;
  if (hasAm && hour == 12) return 0;
  return hour.clamp(0, 23);
}

class _TimeSlot {
  const _TimeSlot(this.hour, this.minute);

  final int hour;
  final int minute;
}

/// Parses a duration phrase into a [Duration], e.g. "5 minutes",
/// "1 hour 30 minutes", "90 seconds", "half an hour".
Duration? _parseDuration(String text) {
  if (text.contains('half an hour') || text.contains('half hour')) {
    return const Duration(minutes: 30);
  }
  final matches = RegExp(
    r'(\d+)\s*(hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s)\b',
  ).allMatches(text);
  var total = Duration.zero;
  var found = false;
  for (final match in matches) {
    final value = int.parse(match.group(1)!);
    final unit = match.group(2)!;
    found = true;
    if (unit.startsWith('h')) {
      total += Duration(hours: value);
    } else if (unit.startsWith('m')) {
      total += Duration(minutes: value);
    } else {
      total += Duration(seconds: value);
    }
  }
  return found ? total : null;
}

/// Extracts the weekday numbers (Mo=0..Su=6) mentioned in [text].
List<int> _parseWeekdays(String text) {
  const names = {
    'monday': 0, 'mon': 0,
    'tuesday': 1, 'tue': 1, 'tues': 1,
    'wednesday': 2, 'wed': 2,
    'thursday': 3, 'thu': 3, 'thur': 3, 'thurs': 3,
    'friday': 4, 'fri': 4,
    'saturday': 5, 'sat': 5,
    'sunday': 6, 'sun': 6,
  };
  final days = <int>{};
  for (final entry in names.entries) {
    if (RegExp('\\b${entry.key}\\b').hasMatch(text)) days.add(entry.value);
  }
  if (text.contains('every weekday') || text.contains('weekdays')) {
    for (var i = 0; i < 5; i++) {
      days.add(i);
    }
  } else if (text.contains('every day') ||
      text.contains('everyday') ||
      text.contains('daily')) {
    for (var i = 0; i < 7; i++) {
      days.add(i);
    }
  }
  return days.toList();
}

List<_Rule> _buildRules() {
  bool has(String text, List<String> needles) =>
      needles.any((n) => text.contains(n));
  bool startsWithAny(String text, List<String> prefixes) =>
      prefixes.any(text.startsWith);
  bool equalsAny(String text, List<String> values) => values.contains(text);

  return [
    // ------------------------------------------------------------- social
    _Rule(IntentKind.greeting, (t, _) {
      if (equalsAny(t, [
        'hi', 'hello', 'hey', 'yo', 'hi there', 'hello there', 'hey there',
        'good morning', 'good afternoon', 'good evening', 'good day',
      ]) || startsWithAny(t, ['hello ', 'hi ', 'hey '])) {
        return const {};
      }
      return null;
    }),
    _Rule(IntentKind.howAreYou, (t, _) => has(t, [
          'how are you', 'how are you doing', 'how do you do',
          'how is it going', 'how are things',
        ])
            ? const {}
            : null),
    _Rule(IntentKind.whoAreYou, (t, _) => has(t, [
          'who are you', 'what are you', 'what is your name',
          'whats your name', 'your name', 'introduce yourself',
        ])
            ? const {}
            : null),
    _Rule(IntentKind.whoAmI, (t, _) => has(t, [
          'who am i', 'what is my name', 'whats my name', 'do you know me',
          'what do you know about me', 'my name',
        ])
            ? const {}
            : null),
    _Rule(IntentKind.thanks, (t, _) => has(t, [
          'thank you', 'thanks', 'thankyou', 'appreciate it', 'cheers',
          'nice one', 'well done',
        ])
            ? const {}
            : null),
    _Rule(IntentKind.goodbye, (t, _) => equalsAny(t, [
          'bye', 'goodbye', 'see you', 'see ya', 'good night', 'goodnight',
          'talk later', 'that is all', 'stop',
        ])
            ? const {}
            : null),
    _Rule(IntentKind.help, (t, _) => startsWithAny(t, [
          'help', 'what can you do', 'what can you do for me',
          'what do you do', 'show commands', 'list commands',
        ])
            ? const {}
            : null),
    _Rule(IntentKind.followUpMore, (t, _) => equalsAny(t, [
          'tell me more', 'more', 'go on', 'continue', 'and then', 'why',
        ]) || has(t, ['more details', 'more about that', 'expand on that'])
            ? const {}
            : null),

    // ------------------------------------------------------------ time/day
    _Rule(IntentKind.time, (t, _) => has(t, [
          'what time is it', 'what is the time', 'whats the time',
          'current time', 'the time now', 'tell me the time', 'time now',
          'what time',
        ]) || equalsAny(t, ['time'])
            ? const {}
            : null),
    _Rule(IntentKind.date, (t, _) => has(t, [
          'what is the date', 'whats the date', 'what date is it',
          'current date', "today's date", 'todays date', 'what day is today',
          'what is today',
        ])
            ? const {}
            : null),
    _Rule(IntentKind.dayOfWeek, (t, _) => has(t, [
          'what day is it', 'what day is it today', 'which day is it',
          'day of the week',
        ])
            ? const {}
            : null),
    _Rule(IntentKind.tomorrow, (t, _) => has(t, [
          'tomorrow date', 'what is tomorrow', 'whats tomorrow',
          'date tomorrow', 'day tomorrow',
        ])
            ? const {}
            : null),
    _Rule(IntentKind.yesterday, (t, _) => has(t, [
          'yesterday date', 'what was yesterday', 'date yesterday',
        ])
            ? const {}
            : null),

    // ---------------------------------------------------------- calculator
    _Rule(IntentKind.calculate, (t, _) {
      final value = _tryCalculator(t);
      return value == null ? null : {'expression': t, 'value': value};
    }),
    _Rule(IntentKind.convertUnit, (t, _) {
      final conversion = _tryConversion(t);
      return conversion == null ? null : {'conversion': conversion};
    }),

    // ------------------------------------------------------ timers/reminders
    _Rule(IntentKind.setTimer, (t, _) {
      if (!has(t, ['timer', 'countdown'])) return null;
      final duration = _parseDuration(t);
      if (duration == null) return null;
      return {'duration_seconds': duration.inSeconds};
    }),
    _Rule(IntentKind.setReminder, (t, _) {
      if (!startsWithAny(t, ['remind me', 'set a reminder', 'set reminder',
          'reminder to', 'add a reminder'])) {
        return null;
      }
      final duration = _parseDuration(t);
      final text = _reminderText(t);
      return {
        if (duration != null) 'duration_seconds': duration.inSeconds,
        'text': text,
      };
    }),

    // ------------------------------------------------------------ alarms
    _Rule(IntentKind.alarmSet, (t, _) {
      if (!has(t, ['alarm', 'wake me'])) return null;
      if (has(t, ['list', 'what alarms', 'show alarms', 'my alarms'])) {
        return null;
      }
      final time = _parseTimeOfDay(t);
      if (time == null) return null;
      final days = _parseWeekdays(t);
      final labelMatch = RegExp(r'(?:called|labelled|labeled|for)\s+(.+)$')
          .firstMatch(t);
      return {
        'hour': time.hour,
        'minute': time.minute,
        if (days.isNotEmpty) 'days': days,
        if (labelMatch != null) 'label': _cleanLabel(labelMatch.group(1)!),
      };
    }),
    _Rule(IntentKind.alarmList, (t, _) => has(t, [
          'list alarms', 'what alarms', 'show alarms', 'my alarms',
          'list my alarms', 'alarms set',
        ]) || equalsAny(t, ['alarms'])
            ? const {}
            : null),
    _Rule(IntentKind.alarmToggle, (t, _) {
      if (!has(t, ['alarm'])) return null;
      final enable = has(t, ['enable', 'turn on', 'switch on', 'activate']);
      final disable = has(t, ['disable', 'turn off', 'switch off', 'deactivate']);
      if (!enable && !disable) return null;
      final match = _alarmMatch(t);
      if (match == null) return null;
      return {'match': match, 'enabled': enable};
    }),
    _Rule(IntentKind.alarmDelete, (t, _) {
      if (!has(t, ['alarm'])) return null;
      if (!has(t, ['delete', 'remove', 'cancel', 'clear'])) return null;
      final match = _alarmMatch(t);
      return match == null ? null : {'match': match};
    }),

    // ------------------------------------------------------------- tasks
    _Rule(IntentKind.taskList, (t, _) => has(t, [
          'list tasks', 'my tasks', 'show tasks', 'what tasks', 'task list',
          'list my tasks', 'show my tasks', 'what are my tasks', 'to do list',
          'todo list', 'what do i have to do',
        ])
            ? const {}
            : null),
    _Rule(IntentKind.taskCreate, (t, _) {
      if (!has(t, ['add task', 'create task', 'new task', 'add a task',
          'add to do', 'add a to do', 'add todo', 'remind me to', 'add a task to'])) {
        return null;
      }
      final title = _taskTitle(t);
      if (title.isEmpty) return null;
      return {'title': title};
    }),
    _Rule(IntentKind.taskComplete, (t, _) {
      if (!has(t, ['complete', 'mark done', 'finish', 'done with', 'tick off'])) {
        return null;
      }
      if (!has(t, ['task', 'to do', 'todo'])) {
        // Allow "complete <thing>" only when a task word is present to avoid
        // stealing unrelated requests.
        if (!startsWithAny(t, ['complete ', 'finish '])) return null;
      }
      final match = _afterKeywords(t, ['complete', 'mark', 'finish', 'done with', 'tick off']);
      return match == null ? null : {'match': match};
    }),
    _Rule(IntentKind.taskDelete, (t, _) {
      if (!has(t, ['task', 'to do', 'todo'])) return null;
      if (!has(t, ['delete', 'remove', 'cancel'])) return null;
      final match = _afterKeywords(t, ['delete', 'remove', 'cancel']);
      return match == null ? null : {'match': match};
    }),

    // ------------------------------------------------------------ events
    _Rule(IntentKind.eventList, (t, _) => has(t, [
          'my schedule', 'my calendar', 'what is on my calendar',
          'events today', 'my events', 'what do i have today',
          'any meetings', 'my meetings', 'show my calendar',
        ])
            ? {'when': has(t, ['tomorrow']) ? 'tomorrow' : (has(t, ['week']) ? 'week' : 'today')}
            : null),

    // ------------------------------------------------------------- habits
    _Rule(IntentKind.habitList, (t, _) => has(t, [
          'my habits', 'list habits', 'show habits', 'habit list',
          'what habits',
        ])
            ? const {}
            : null),
    _Rule(IntentKind.habitLog, (t, _) {
      if (!has(t, ['habit'])) return null;
      if (!has(t, ['done', 'log', 'complete', 'did', 'mark'])) return null;
      final match = _afterKeywords(t, ['done', 'log', 'complete', 'did', 'mark']);
      final habit = match ?? _cleanLabel(t.replaceAll('habit', '').trim());
      return habit.isEmpty ? null : {'match': habit};
    }),

    // -------------------------------------------------------------- notes
    _Rule(IntentKind.noteCreate, (t, _) {
      if (!has(t, ['note', 'write down', 'make a note', 'jot down'])) return null;
      if (has(t, ['search', 'find', 'list', 'show'])) return null;
      final body = _afterKeywords(t, [
        'make a note', 'write down', 'note that', 'note down', 'add a note',
        'create a note', 'note',
      ]);
      return {'body': _cleanLabel(body ?? t)};
    }),
    _Rule(IntentKind.noteSearch, (t, _) {
      if (!has(t, ['note'])) return null;
      if (!has(t, ['search', 'find', 'list', 'show', 'what'])) return null;
      final query = _afterKeywords(t, ['search', 'find', 'for']);
      return {'query': _cleanLabel(query ?? '')};
    }),

    // ----------------------------------------------------------- expenses
    _Rule(IntentKind.expenseSummary, (t, _) => has(t, [
          'my expenses', 'expense summary', 'how much did i spend',
          'how much have i spent', 'my spending', 'my balance',
          'spending summary', 'expenses this month',
        ])
            ? const {}
            : null),
    _Rule(IntentKind.expenseCreate, (t, _) {
      final amountMatch = RegExp(
        r'(?:spent|paid|expense|income|earned|received|team?)\s*(?:of|:)?\s*'
        r'(?:rs\.?|inr|rupees|\$|usd)?\s*(\d+(?:\.\d+)?)',
      ).firstMatch(t);
      if (amountMatch == null) return null;
      final amount = double.tryParse(amountMatch.group(1)!);
      if (amount == null) return null;
      final isIncome = has(t, ['income', 'earned', 'received', 'salary']);
      return {
        'amount': amount,
        'type': isIncome ? 'income' : 'expense',
        'note': _expenseNote(t),
      };
    }),

    // ----------------------------------------------------------- workouts
    _Rule(IntentKind.workoutSummary, (t, _) => has(t, [
          'my workout', 'workout summary', 'my workouts', 'how much did i run',
          'my runs', 'my steps', 'my activity', 'fitness summary',
        ])
            ? {'period': has(t, ['week', 'this week']) ? 'week' : 'today'}
            : null),

    // ------------------------------------------------------------- music
    _Rule(IntentKind.musicPlay, (t, _) {
      if (has(t, ['play music', 'play song', 'play some music'])) {
        return const {};
      }
      final match = RegExp(r'^play\s+(.+)$').firstMatch(t);
      if (match == null) return null;
      return {'match': _cleanLabel(match.group(1)!)};
    }),

    // ----------------------------------------------------------- memory
    _Rule(IntentKind.memorySave, (t, _) {
      final prefixes = [
        'remember that', 'remember ', 'keep in mind', 'note that i',
        'save this', 'remember i',
      ];
      for (final prefix in prefixes) {
        if (t.startsWith(prefix)) {
          final content = _cleanLabel(t.substring(prefix.length).trim());
          if (content.isNotEmpty) return {'content': content};
        }
      }
      return null;
    }),
    _Rule(IntentKind.memorySearch, (t, _) {
      if (!has(t, ['remember', 'memory', 'memories'])) return null;
      if (!has(t, ['what do you know', 'what did i tell', 'recall', 'do you remember',
          'my memories', 'search memory'])) {
        return null;
      }
      final query = _afterKeywords(t, ['about', 'remember']);
      return {'query': _cleanLabel(query ?? '')};
    }),
    _Rule(IntentKind.memoryForget, (t, _) {
      if (!has(t, ['forget', 'delete memory', 'remove memory'])) return null;
      final match = _afterKeywords(t, ['forget', 'delete', 'remove']);
      return {'match': _cleanLabel(match ?? '')};
    }),

    // ------------------------------------------------------------ device
    _Rule(IntentKind.battery, (t, _) => has(t, [
          'battery', 'how much charge', 'charge level', 'power level',
          'phone battery',
        ])
            ? const {}
            : null),
    _Rule(IntentKind.openApp, (t, _) {
      final match = RegExp(r'^open\s+(.+)$').firstMatch(t);
      if (match == null) return null;
      final app = _cleanLabel(match.group(1)!);
      // "open ... settings" is handled by the settings intent.
      if (app.endsWith('settings') || app.contains('settings ')) return null;
      final appMap = {
        'whatsapp': 'com.whatsapp',
        'youtube': 'com.google.android.youtube',
        'maps': 'com.google.android.apps.maps',
        'google maps': 'com.google.android.apps.maps',
        'camera': 'com.android.camera2',
        'gallery': 'com.android.gallery3d',
        'settings': 'com.android.settings',
        'chrome': 'com.android.chrome',
        'gmail': 'com.google.android.gm',
        'instagram': 'com.instagram.android',
        'facebook': 'com.facebook.katana',
        'spotify': 'com.spotify.music',
      };
      return {'package': appMap[app] ?? app, 'app_name': app};
    }),
    _Rule(IntentKind.openSettings, (t, _) {
      final match = RegExp(r'^(?:open|go to|show)\s+(?:the\s+)?(.+?)\s+settings$')
          .firstMatch(t);
      if (match == null) return null;
      final page = _mapSettingsPage(match.group(1)!);
      return page == null ? null : {'page': page};
    }),

    // ------------------------------------------------------------ weather
    _Rule(IntentKind.weather, (t, _) => has(t, [
          'weather', 'temperature', 'how hot', 'how cold', 'is it raining',
          'will it rain', 'forecast',
        ])
            ? const {}
            : null),
    _Rule(IntentKind.nearby, (t, _) {
      final match = RegExp(
        r'(?:find|where is|where are|nearby|near me|closest|nearest|show me)'
        r'\s+(.+?)(?:\s+(?:near me|nearby|around here|close by))?$',
      ).firstMatch(t);
      if (match == null) return null;
      final target = _cleanLabel(match.group(1)!);
      if (target.isEmpty) return null;
      return {'query': target};
    }),
  ];
}

// ---------------------------------------------------------------------------
// helpers shared by rules
// ---------------------------------------------------------------------------

double? _tryCalculator(String text) {
  try {
    return calc.tryEvaluate(text);
  } catch (_) {
    return null;
  }
}

calc.UnitConversion? _tryConversion(String text) {
  try {
    return calc.tryParseConversion(text);
  } catch (_) {
    return null;
  }
}

/// Trims quotes/whitespace and capitalises nothing — callers decide casing.
String _cleanLabel(String text) =>
    text.trim().replaceAll(RegExp(r'^["\u201c\u2018]|["\u201d\u2019]$'), '').trim();

/// Removes filler words from a captured reminder/task title.
String _stripFillers(String text) {
  var out = _cleanLabel(text);
  out = out.replaceAll(RegExp(r'\bin\s+\d+\s*(hours?|hrs?|minutes?|mins?|'
      r'seconds?|secs?|h|m|s)\b'), '').trim();
  out = out.replaceAll(RegExp(r'\b(at|by)\s+\d{1,2}([:.]\d{2})?\s*(am|pm)?\b'),
      '').trim();
  return out.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _reminderText(String text) {
  var out = text;
  for (final prefix in [
    'remind me to',
    'remind me',
    'set a reminder to',
    'set a reminder',
    'set reminder to',
    'set reminder',
    'add a reminder to',
    'add a reminder',
    'reminder to',
  ]) {
    if (out.startsWith(prefix)) {
      out = out.substring(prefix.length);
      break;
    }
  }
  final cleaned = _stripFillers(out);
  return cleaned.isEmpty ? 'Reminder' : cleaned;
}

String _taskTitle(String text) {
  var out = text;
  for (final prefix in [
    'add a task to',
    'add a task',
    'add task to',
    'add task',
    'create a task to',
    'create a task',
    'create task',
    'new task to',
    'new task',
    'add to do',
    'add a to do',
    'add todo',
    'remind me to',
  ]) {
    if (out.startsWith(prefix)) {
      out = out.substring(prefix.length);
      break;
    }
  }
  final cleaned = _stripFillers(out);
  return cleaned;
}

/// Returns the text after the first matching keyword, cleaned. Used for
/// "complete X" / "delete X" style commands.
String? _afterKeywords(String text, List<String> keywords) {
  for (final keyword in keywords) {
    final index = text.indexOf(keyword);
    if (index >= 0) {
      var rest = text.substring(index + keyword.length).trim();
      rest = rest.replaceAll(RegExp(r'^(the|a|an|my|to)\s+'), '').trim();
      rest = _stripFillers(rest);
      if (rest.isNotEmpty) return rest;
    }
  }
  return null;
}

String? _alarmMatch(String text) {
  final time = RegExp(r'\b(\d{1,2}[:.]\d{2}|\d{1,2}\s*(?:am|pm))\b')
      .firstMatch(text);
  if (time != null) return time.group(1);
  final label = _afterKeywords(text, ['called', 'labelled', 'labeled', 'for']);
  if (label != null) return label;
  return null;
}

String _expenseNote(String text) {
  final note = _afterKeywords(text, ['for', 'on']);
  return note ?? '';
}

String? _mapSettingsPage(String raw) {
  final page = raw.toLowerCase().trim();
  const valid = {
    'wifi', 'bluetooth', 'sound', 'display', 'battery', 'apps',
    'location', 'data', 'storage', 'notification', 'notifications',
    'date', 'accessibility', 'nfc', 'airplane',
  };
  if (valid.contains(page)) return page == 'notifications' ? 'notification' : page;
  if (page.contains('wi-fi') || page.contains('wifi')) return 'wifi';
  if (page.contains('bluetooth')) return 'bluetooth';
  if (page.contains('sound') || page.contains('volume')) return 'sound';
  if (page.contains('display') || page.contains('brightness')) return 'display';
  if (page.contains('battery')) return 'battery';
  if (page.contains('app')) return 'apps';
  if (page.contains('location') || page.contains('gps')) return 'location';
  return null;
}
