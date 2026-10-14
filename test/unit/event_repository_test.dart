import 'package:aalumai/core/db/database.dart';
import 'package:aalumai/core/utils/recurrence.dart';
import 'package:aalumai/features/schedule/data/event_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Event _event({
  int id = 1,
  required DateTime start,
  required DateTime end,
  Recurrence recurrence = Recurrence.none,
}) => Event(
  id: id,
  title: 'Event $id',
  description: '',
  location: '',
  startAt: start,
  endAt: end,
  allDay: false,
  recurrenceRule: recurrence.encode(),
  reminderMinutes: -1,
  isBirthday: false,
  createdAt: DateTime(2024),
);

void main() {
  group('EventRepository.expand', () {
    test('includes a single in-range event', () {
      final events = [
        _event(start: DateTime(2024, 1, 3, 9), end: DateTime(2024, 1, 3, 10)),
      ];
      final result = EventRepository.expand(
        events,
        DateTime(2024, 1, 1),
        DateTime(2024, 1, 5),
      );
      expect(result, hasLength(1));
      expect(result.single.startAt, DateTime(2024, 1, 3, 9));
    });

    test('excludes a single out-of-range event', () {
      final events = [
        _event(start: DateTime(2024, 2, 3, 9), end: DateTime(2024, 2, 3, 10)),
      ];
      final result = EventRepository.expand(
        events,
        DateTime(2024, 1, 1),
        DateTime(2024, 1, 5),
      );
      expect(result, isEmpty);
    });

    test('expands a daily recurring event across the range', () {
      final events = [
        _event(
          start: DateTime(2024, 1, 1, 9),
          end: DateTime(2024, 1, 1, 9, 30),
          recurrence: const Recurrence(frequency: RecurrenceFrequency.daily),
        ),
      ];
      final result = EventRepository.expand(
        events,
        DateTime(2024, 1, 1),
        DateTime(2024, 1, 5),
      );
      expect(result, hasLength(4));
      expect(result.first.startAt, DateTime(2024, 1, 1, 9));
      expect(result.last.startAt, DateTime(2024, 1, 4, 9));
      // Duration is preserved for every occurrence.
      for (final e in result) {
        expect(e.endAt.difference(e.startAt), const Duration(minutes: 30));
      }
    });

    test('drops a cancelled occurrence', () {
      final events = [
        _event(
          id: 1,
          start: DateTime(2024, 1, 1, 9),
          end: DateTime(2024, 1, 1, 9, 30),
          recurrence: const Recurrence(frequency: RecurrenceFrequency.daily),
        ),
      ];
      final exceptions = [
        EventException(
          id: 1,
          eventId: 1,
          originalDate: DateTime(2024, 1, 2, 9),
          isCancelled: true,
        ),
      ];
      final result = EventRepository.expand(
        events,
        DateTime(2024, 1, 1),
        DateTime(2024, 1, 5),
        exceptions: exceptions,
      );
      expect(result, hasLength(3));
      expect(result.map((e) => e.startAt.day), isNot(contains(2)));
    });

    test('moves an occurrence when an exception supplies a new time', () {
      final events = [
        _event(
          id: 1,
          start: DateTime(2024, 1, 1, 9),
          end: DateTime(2024, 1, 1, 9, 30),
          recurrence: const Recurrence(frequency: RecurrenceFrequency.daily),
        ),
      ];
      final exceptions = [
        EventException(
          id: 1,
          eventId: 1,
          originalDate: DateTime(2024, 1, 2, 9),
          newStartAt: DateTime(2024, 1, 2, 15),
          newEndAt: DateTime(2024, 1, 2, 15, 30),
          isCancelled: false,
        ),
      ];
      final result = EventRepository.expand(
        events,
        DateTime(2024, 1, 1),
        DateTime(2024, 1, 5),
        exceptions: exceptions,
      );
      expect(result, hasLength(4));
      final moved = result.firstWhere((e) => e.startAt.day == 2);
      expect(moved.startAt, DateTime(2024, 1, 2, 15));
    });

    test('returns occurrences sorted by start time', () {
      final events = [
        _event(
          id: 1,
          start: DateTime(2024, 1, 6, 9),
          end: DateTime(2024, 1, 6, 10),
        ),
        _event(
          id: 2,
          start: DateTime(2024, 1, 2, 9),
          end: DateTime(2024, 1, 2, 10),
        ),
      ];
      final result = EventRepository.expand(
        events,
        DateTime(2024, 1, 1),
        DateTime(2024, 1, 10),
      );
      expect(result.first.startAt, DateTime(2024, 1, 2, 9));
      expect(result.last.startAt, DateTime(2024, 1, 6, 9));
    });
  });
}
