import '../../../core/db/database.dart';
import 'weekly_planner.dart';

/// Public-health thresholds used to frame activity goals. These mirror the WHO
/// recommendations for adults (18–64): 150–300 minutes of moderate-intensity
/// aerobic activity per week (or the vigorous equivalent) plus muscle-
/// strengthening on at least two days per week.
///
/// AALUMAI content is *informed by* this guidance; it is never "WHO-certified".
class WhoGuidance {
  const WhoGuidance._();

  static const moderateMinutesMin = 150;
  static const moderateMinutesMax = 300;
  static const vigorousMinutesMin = 75;
  static const vigorousMinutesMax = 150;
  static const strengthDaysMin = 2;

  /// One vigorous minute counts as two moderate minutes.
  static const vigorousToModerateFactor = 2;

  static const attribution = 'Informed by WHO physical-activity guidance';
}

/// A week's progress against the WHO thresholds, derived from completed
/// sessions. Aerobic minutes count run/walk sessions; strength days count
/// distinct calendar days with a completed strength workout.
class WhoWeeklyProgress {
  const WhoWeeklyProgress({
    required this.aerobicMinutes,
    required this.vigorousMinutes,
    required this.strengthDays,
  });

  final int aerobicMinutes;
  final int vigorousMinutes;
  final int strengthDays;

  int get moderateEquivalentMinutes =>
      aerobicMinutes + vigorousMinutes * WhoGuidance.vigorousToModerateFactor;

  bool get meetsAerobic =>
      moderateEquivalentMinutes >= WhoGuidance.moderateMinutesMin;

  bool get meetsStrength => strengthDays >= WhoGuidance.strengthDaysMin;

  bool get meetsAll => meetsAerobic && meetsStrength;

  double get aerobicProgress =>
      (moderateEquivalentMinutes / WhoGuidance.moderateMinutesMin).clamp(
        0.0,
        1.0,
      );

  double get strengthProgress =>
      (strengthDays / WhoGuidance.strengthDaysMin).clamp(0.0, 1.0);
}

/// Computes this week's WHO progress from [sessions], relative to [now].
WhoWeeklyProgress whoWeeklyProgress(
  List<WorkoutSession> sessions, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final start = WeekDates.startOfWeek(reference);
  final end = DateTime(start.year, start.month, start.day + 7);

  var aerobic = 0;
  var vigorous = 0;
  final strengthDays = <String>{};

  for (final s in sessions) {
    if (s.endedAt == null || s.durationSec <= 0) continue;
    if (s.startedAt.isBefore(start) || !s.startedAt.isBefore(end)) continue;
    final minutes = (s.durationSec / 60).round();
    if (s.type == 1 || s.type == 2) {
      // Run/walk/cycle style aerobic work.
      aerobic += minutes;
    } else if (s.type == 0) {
      strengthDays.add(
        '${s.startedAt.year}-${s.startedAt.month}-${s.startedAt.day}',
      );
    }
  }

  return WhoWeeklyProgress(
    aerobicMinutes: aerobic,
    vigorousMinutes: vigorous,
    strengthDays: strengthDays.length,
  );
}
