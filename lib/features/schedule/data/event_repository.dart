import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/recurrence.dart';

class EventRepository {
  EventRepository(this._db);

  final AppDatabase _db;

  Stream<List<Event>> watchAll() =>
      (_db.select(_db.events)
        ..orderBy([(t) => OrderingTerm(expression: t.startAt)])).watch();

  Future<List<Event>> eventsBetween(DateTime from, DateTime to) =>
      (_db.select(_db.events)
            ..where(
              (t) =>
                  (t.startAt.isBetweenValues(from, to)) |
                  (t.endAt.isBetweenValues(from, to)) |
                  (t.startAt.isSmallerOrEqualValue(from) &
                      t.endAt.isBiggerOrEqualValue(to)),
            )
            ..orderBy([(t) => OrderingTerm(expression: t.startAt)]))
          .get();

  Stream<List<Event>> watchBetween(DateTime from, DateTime to) =>
      (_db.select(_db.events)
            ..where(
              (t) =>
                  (t.startAt.isBetweenValues(from, to)) |
                  (t.startAt.isSmallerOrEqualValue(from) &
                      t.endAt.isBiggerOrEqualValue(from)),
            )
            ..orderBy([(t) => OrderingTerm(expression: t.startAt)]))
          .watch();

  Future<int> create({
    required String title,
    String description = '',
    String location = '',
    required DateTime startAt,
    required DateTime endAt,
    bool allDay = false,
    Recurrence recurrence = Recurrence.none,
    int reminderMinutes = -1,
    bool isBirthday = false,
  }) {
    return _db
        .into(_db.events)
        .insert(
          EventsCompanion.insert(
            title: title,
            description: Value(description),
            location: Value(location),
            startAt: startAt,
            endAt: endAt,
            allDay: Value(allDay),
            recurrenceRule: Value(recurrence.encode()),
            reminderMinutes: Value(reminderMinutes),
            isBirthday: Value(isBirthday),
          ),
        );
  }

  Future<void> updateEvent(Event event) =>
      _db.update(_db.events).replace(event);

  Future<void> delete(int id) =>
      (_db.delete(_db.events)..where((t) => t.id.equals(id))).go();

  Future<void> addException(
    int eventId,
    DateTime originalDate, {
    DateTime? newStart,
    DateTime? newEnd,
    bool cancelled = false,
  }) {
    return _db
        .into(_db.eventExceptions)
        .insert(
          EventExceptionsCompanion.insert(
            eventId: eventId,
            originalDate: originalDate,
            newStartAt: Value(newStart),
            newEndAt: Value(newEnd),
            isCancelled: Value(cancelled),
          ),
        );
  }

  /// Expands recurring [events] into concrete occurrences within a range.
  /// Exceptions are applied where present.
  static List<Event> expand(
    List<Event> events,
    DateTime from,
    DateTime to, {
    List<EventException> exceptions = const [],
  }) {
    final result = <Event>[];
    for (final event in events) {
      final rule = Recurrence.parse(event.recurrenceRule);
      if (!rule.repeats) {
        if (event.endAt.isAfter(from) && event.startAt.isBefore(to)) {
          result.add(event);
        }
        continue;
      }
      final duration = event.endAt.difference(event.startAt);
      var occurrence = event.startAt;
      var guard = 0;
      while (occurrence.isBefore(from) && guard < 1000) {
        occurrence = rule.next(occurrence);
        guard++;
      }
      guard = 0;
      while (occurrence.isBefore(to) && guard < 1000) {
        EventException? ex;
        for (final e in exceptions) {
          if (e.eventId == event.id &&
              e.originalDate.year == occurrence.year &&
              e.originalDate.month == occurrence.month &&
              e.originalDate.day == occurrence.day) {
            ex = e;
            break;
          }
        }
        if (ex == null) {
          result.add(
            event.copyWith(
              startAt: occurrence,
              endAt: occurrence.add(duration),
            ),
          );
        } else if (!ex.isCancelled) {
          result.add(
            event.copyWith(
              startAt: ex.newStartAt ?? occurrence,
              endAt: ex.newEndAt ?? occurrence.add(duration),
            ),
          );
        } else {
          // Cancelled occurrence: intentionally omitted.
        }
        occurrence = rule.next(occurrence);
        guard++;
      }
    }
    result.sort((a, b) => a.startAt.compareTo(b.startAt));
    return result;
  }
}

final eventRepositoryProvider = Provider<EventRepository>(
  (ref) => EventRepository(ref.watch(appDatabaseProvider)),
);

final allEventsProvider = StreamProvider<List<Event>>(
  (ref) => ref.watch(eventRepositoryProvider).watchAll(),
);
