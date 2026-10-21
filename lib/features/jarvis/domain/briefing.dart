import 'package:aalumai/core/localization/generated/app_localizations.dart';

/// A ready-to-post morning-briefing notification.
class BriefingContent {
  const BriefingContent({required this.title, required this.body});

  final String title;
  final String body;
}

/// The next briefing firing time: today's [hour]:[minute] while it is still
/// ahead, otherwise tomorrow's.
DateTime nextBriefingTime(DateTime now, {int hour = 8, int minute = 0}) {
  final today = DateTime(now.year, now.month, now.day, hour, minute);
  return !now.isBefore(today) ? today.add(const Duration(days: 1)) : today;
}

/// Builds the briefing from facts the app already knows — deterministic,
/// offline, and independent of whether a model is installed or loaded.
///
/// [openTasks]/[eventsToday] count the target morning's day; [nextAlarm] is
/// the soonest alarm ringing at or after the briefing fires (`null` when the
/// morning has no alarm).
BriefingContent buildBriefing({
  required AppLocalizations l10n,
  required int openTasks,
  required int eventsToday,
  ({int hour, int minute})? nextAlarm,
}) {
  final title = l10n.jarvisBriefingTitle;
  if (openTasks == 0 && eventsToday == 0 && nextAlarm == null) {
    return BriefingContent(title: title, body: l10n.jarvisBriefingQuiet);
  }
  final alarmTime =
      nextAlarm == null
          ? null
          : '${nextAlarm.hour.toString().padLeft(2, '0')}:'
              '${nextAlarm.minute.toString().padLeft(2, '0')}';
  final parts = [
    if (openTasks > 0) l10n.jarvisBriefingTasks(openTasks),
    if (eventsToday > 0) l10n.jarvisBriefingEvents(eventsToday),
    if (alarmTime != null) l10n.jarvisBriefingAlarm(alarmTime),
  ];
  return BriefingContent(title: title, body: parts.join(' · '));
}
