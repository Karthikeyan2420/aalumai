/// Minimal, dependency-free recurrence support shared by tasks and events.
///
/// Rules use a compact `FREQ=...;INTERVAL=n` syntax, e.g.
/// `FREQ=DAILY;INTERVAL=1`, `FREQ=WEEKLY;INTERVAL=2`, `FREQ=MONTHLY`.
/// An empty rule means "does not repeat".
class Recurrence {
  const Recurrence({required this.frequency, this.interval = 1});

  final RecurrenceFrequency frequency;
  final int interval;

  static const none = Recurrence(frequency: RecurrenceFrequency.none);

  bool get repeats => frequency != RecurrenceFrequency.none;

  static Recurrence parse(String? rule) {
    if (rule == null || rule.trim().isEmpty) return none;
    var freq = RecurrenceFrequency.none;
    var interval = 1;
    for (final part in rule.split(';')) {
      final kv = part.split('=');
      if (kv.length != 2) continue;
      final key = kv[0].trim().toUpperCase();
      final value = kv[1].trim();
      if (key == 'FREQ') {
        freq = switch (value.toUpperCase()) {
          'DAILY' => RecurrenceFrequency.daily,
          'WEEKLY' => RecurrenceFrequency.weekly,
          'MONTHLY' => RecurrenceFrequency.monthly,
          'YEARLY' => RecurrenceFrequency.yearly,
          _ => RecurrenceFrequency.none,
        };
      } else if (key == 'INTERVAL') {
        interval = int.tryParse(value) ?? 1;
      }
    }
    return Recurrence(frequency: freq, interval: interval < 1 ? 1 : interval);
  }

  String encode() {
    if (!repeats) return '';
    return 'FREQ=${frequency.name.toUpperCase()};INTERVAL=$interval';
  }

  /// The next occurrence strictly after [from].
  DateTime next(DateTime from) {
    switch (frequency) {
      case RecurrenceFrequency.none:
        return from;
      case RecurrenceFrequency.daily:
        return from.add(Duration(days: interval));
      case RecurrenceFrequency.weekly:
        return from.add(Duration(days: 7 * interval));
      case RecurrenceFrequency.monthly:
        return _addMonths(from, interval);
      case RecurrenceFrequency.yearly:
        return _addMonths(from, 12 * interval);
    }
  }

  static DateTime _addMonths(DateTime date, int months) {
    final totalMonths = date.month - 1 + months;
    final year = date.year + (totalMonths ~/ 12);
    final month = totalMonths % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = date.day > lastDay ? lastDay : date.day;
    return DateTime(year, month, day, date.hour, date.minute);
  }
}

enum RecurrenceFrequency {
  none,
  daily,
  weekly,
  monthly,
  yearly;

  String get labelKey => name.toUpperCase();
}
