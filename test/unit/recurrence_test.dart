import 'package:aalumai/core/utils/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Recurrence.parse', () {
    test('empty/null means no repeat', () {
      expect(Recurrence.parse(null).repeats, isFalse);
      expect(Recurrence.parse('').repeats, isFalse);
      expect(Recurrence.parse('  ').frequency, RecurrenceFrequency.none);
    });

    test('parses frequency and interval', () {
      final r = Recurrence.parse('FREQ=WEEKLY;INTERVAL=2');
      expect(r.frequency, RecurrenceFrequency.weekly);
      expect(r.interval, 2);
    });

    test('clamps invalid interval to 1', () {
      expect(Recurrence.parse('FREQ=DAILY;INTERVAL=0').interval, 1);
      expect(Recurrence.parse('FREQ=DAILY;INTERVAL=abc').interval, 1);
    });

    test('unknown frequency becomes none', () {
      expect(
        Recurrence.parse('FREQ=HOURLY').frequency,
        RecurrenceFrequency.none,
      );
    });
  });

  group('Recurrence.encode', () {
    test('round-trips', () {
      const r = Recurrence(frequency: RecurrenceFrequency.monthly, interval: 3);
      expect(
        Recurrence.parse(r.encode()).frequency,
        RecurrenceFrequency.monthly,
      );
      expect(Recurrence.parse(r.encode()).interval, 3);
    });

    test('none encodes to empty string', () {
      expect(Recurrence.none.encode(), '');
    });
  });

  group('Recurrence.next', () {
    test('daily adds interval days', () {
      const r = Recurrence(frequency: RecurrenceFrequency.daily, interval: 2);
      expect(r.next(DateTime(2024, 1, 1)), DateTime(2024, 1, 3));
    });

    test('weekly adds 7*interval days', () {
      const r = Recurrence(frequency: RecurrenceFrequency.weekly, interval: 2);
      expect(r.next(DateTime(2024, 1, 1)), DateTime(2024, 1, 15));
    });

    test('monthly clamps to last day of shorter month', () {
      const r = Recurrence(frequency: RecurrenceFrequency.monthly);
      expect(r.next(DateTime(2024, 1, 31)), DateTime(2024, 2, 29));
    });

    test('yearly rolls over', () {
      const r = Recurrence(frequency: RecurrenceFrequency.yearly);
      expect(r.next(DateTime(2023, 6, 15)), DateTime(2024, 6, 15));
    });

    test('none returns input unchanged', () {
      final d = DateTime(2024, 5, 5);
      expect(Recurrence.none.next(d), d);
    });
  });
}
