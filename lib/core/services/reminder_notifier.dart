/// Abstraction over the local-notification backend used for task, habit and
/// event reminders. Keeping this interface separate lets [ReminderScheduler]
/// be unit-tested with a fake, without touching a platform plugin.
abstract class ReminderNotifier {
  /// Schedules a single reminder that fires once at [when].
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  });

  /// Schedules a reminder that repeats every day at [hour]:[minute], or every
  /// week on [weekday] (1 = Monday … 7 = Sunday) when [weekday] is provided.
  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    int? weekday,
  });

  /// Cancels the reminder with [id].
  Future<void> cancel(int id);
}
