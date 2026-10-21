import 'package:aalumai/core/localization/generated/app_localizations.dart';
import 'package:aalumai/core/preferences/app_preferences.dart';
import 'package:aalumai/core/services/reminder_notifier.dart';
import 'package:aalumai/features/alarms/data/alarm_repository.dart';
import 'package:aalumai/features/schedule/data/event_repository.dart';
import 'package:aalumai/features/tasks/data/task_repository.dart';
import 'package:flutter/widgets.dart' show Locale;

import '../domain/briefing.dart';

/// Re-arms Jarvis's morning briefing notification.
///
/// Called on every app start (best-effort, in the same style as the other
/// startup reconciles) and whenever the toggle flips. The previously armed
/// slot is cancelled first, so at most one briefing notification ever exists.
/// Facts are read at arm time for the target morning — each app launch
/// refreshes them.
Future<void> reconcileDailyBriefing({
  required ReminderNotifier reminders,
  required AppPreferences prefs,
  required TaskRepository tasks,
  required EventRepository events,
  required AlarmRepository alarms,
}) async {
  final armedId = prefs.jarvisBriefingId;
  if (armedId > 0) await reminders.cancel(armedId);
  await prefs.setJarvisBriefingId(0);
  if (!prefs.jarvisBriefingEnabled || !prefs.notificationsEnabled) return;

  final when = nextBriefingTime(DateTime.now());
  final dayStart = DateTime(when.year, when.month, when.day);
  final dayEnd = dayStart.add(const Duration(days: 1));

  final rows = await tasks.watchAll().first;
  final openTasks =
      rows
          .where((row) => !row.task.isCompleted && row.task.dueDate == dayStart)
          .length;
  final dayEvents = await events.eventsBetween(dayStart, dayEnd);

  // The soonest alarm ringing at or after the briefing fires.
  ({int hour, int minute})? morningAlarm;
  for (final upcoming in await alarms.upcoming()) {
    if (!upcoming.next.isBefore(when)) {
      morningAlarm = (hour: upcoming.alarm.hour, minute: upcoming.alarm.minute);
      break;
    }
  }

  final l10n = await AppLocalizations.delegate.load(
    Locale(prefs.localeCode ?? 'en'),
  );
  final content = buildBriefing(
    l10n: l10n,
    openTasks: openTasks,
    eventsToday: dayEvents.length,
    nextAlarm: morningAlarm,
  );

  final id = await prefs.nextJarvisReminderId();
  await reminders.scheduleReminder(
    id: id,
    title: content.title,
    body: content.body,
    when: when,
  );
  await prefs.setJarvisBriefingId(id);
}
