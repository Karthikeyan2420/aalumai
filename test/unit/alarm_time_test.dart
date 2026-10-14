import 'package:aalumai/core/utils/alarm_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AlarmTime.next', () {
    test('returns later today when time has not passed', () {
      final next = AlarmTime.next(
        hour: 8,
        minute: 0,
        repeatDaysMask: 0,
        from: DateTime(2024, 1, 1, 7, 0),
      );
      expect(next, DateTime(2024, 1, 1, 8, 0));
    });

    test('rolls to tomorrow when the time already passed', () {
      final next = AlarmTime.next(
        hour: 8,
        minute: 0,
        repeatDaysMask: 0,
        from: DateTime(2024, 1, 1, 9, 0),
      );
      expect(next, DateTime(2024, 1, 2, 8, 0));
    });

    test('respects a weekday mask (Monday only)', () {
      // 2024-01-02 is a Tuesday.
      final next = AlarmTime.next(
        hour: 8,
        minute: 0,
        repeatDaysMask: 1, // Monday
        from: DateTime(2024, 1, 2, 0, 0),
      );
      expect(next, DateTime(2024, 1, 8, 8, 0));
    });
  });

  group('AlarmTime.weekdays', () {
    test('zero mask means every day', () {
      expect(AlarmTime.weekdays(0), [1, 2, 3, 4, 5, 6, 7]);
    });

    test('decodes set bits to ISO weekdays', () {
      expect(AlarmTime.weekdays(0x05), [1, 3]);
    });
  });

  group('AlarmTime.format', () {
    test('12-hour format', () {
      expect(AlarmTime.format(13, 5), '1:05 PM');
      expect(AlarmTime.format(0, 5), '12:05 AM');
      expect(AlarmTime.format(12, 0), '12:00 PM');
    });

    test('24-hour format', () {
      expect(AlarmTime.format(13, 5, use24h: true), '13:05');
      expect(AlarmTime.format(0, 5, use24h: true), '00:05');
    });
  });
}
