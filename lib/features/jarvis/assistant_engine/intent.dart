/// Intent model for the model-free assistant.
///
/// The engine recognises a fixed set of [IntentKind]s from the user's text
/// with deterministic rules. There is no language model: an intent is either
/// matched with high confidence or handed to the knowledge/web-search
/// fallback.
library;

/// Every command the local engine understands.
enum IntentKind {
  greeting,
  howAreYou,
  whoAreYou,
  whoAmI,
  thanks,
  goodbye,
  help,
  followUpMore,
  followUpWhy,
  time,
  date,
  dayOfWeek,
  tomorrow,
  yesterday,
  calculate,
  convertUnit,
  setTimer,
  setReminder,
  battery,
  // App-domain commands routed to the tool executor.
  taskList,
  taskCreate,
  taskComplete,
  taskDelete,
  eventList,
  alarmList,
  alarmSet,
  alarmToggle,
  alarmDelete,
  habitList,
  habitLog,
  noteCreate,
  noteSearch,
  expenseSummary,
  expenseCreate,
  workoutSummary,
  musicPlay,
  memorySave,
  memorySearch,
  memoryForget,
  openApp,
  openSettings,
  weather,
  nearby,
  // Not a command: hand off to knowledge / web search.
  question,
  unknown,
}

/// One recognised intent, carrying the raw text plus any structured slots
/// the matcher extracted (numbers, durations, dates, etc.).
class Intent {
  const Intent(this.kind, {this.text = '', this.slots = const {}});

  final IntentKind kind;

  /// The user's original (trimmed) text.
  final String text;

  /// Extracted slots, e.g. `{'hour': 7, 'minute': 30}` or `{'query': 'milk'}`.
  final Map<String, Object?> slots;

  T? slot<T>(String name) {
    final value = slots[name];
    return value is T ? value : null;
  }

  @override
  String toString() => 'Intent(${kind.name}, slots: $slots)';
}
