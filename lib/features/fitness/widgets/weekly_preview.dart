import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/l10n_extension.dart';
import '../data/fitness_repository.dart';
import '../domain/exercise_format.dart';
import '../domain/workout_preferences.dart';

/// Seven compact day selectors (Mon–Sun) showing the planned workout or
/// recovery label, a completion indicator, and selected-day styling.
class WeeklyPreview extends ConsumerWidget {
  const WeeklyPreview({super.key, this.onDayTap});

  final ValueChanged<DateTime>? onDayTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final prefs = ref.watch(workoutPreferencesProvider).valueOrNull;
    final today = DateTime.now();
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final schedules = ref.watch(scheduleWeekProvider(weekStart)).valueOrNull ?? [];
    final now = DateTime.now();

    // Map scheduled statuses by date for completion indicators.
    final statusByDate = <String, int>{};
    for (final s in schedules) {
      final key =
          '${s.date.year}-${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}';
      statusByDate[key] = s.status;
    }

    final narrow = MaterialLocalizations.of(context).narrowWeekdays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.weeklyPlanner,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final date = DateTime(
                weekStart.year,
                weekStart.month,
                weekStart.day + i,
              );
              final isToday =
                  date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day;
              final trains =
                  prefs != null &&
                  prefs.trainsOn(date.weekday) &&
                  !prefs.restsOn(date.weekday);
              final key =
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              final status = statusByDate[key];
              final completed = status == 1; // ScheduleStatus.completed.index
              final focus = WhoDailyPlan.focusFor(date.weekday);
              final recovery = WhoDailyPlan.isRecovery(date.weekday);
              final label =
                  recovery
                      ? l10n.activeRecoveryDay
                      : trains
                      ? focus
                          .map((g) => exerciseCategoryLabel(l10n, g))
                          .join(' + ')
                      : l10n.restDay;

              return GestureDetector(
                onTap:
                    onDayTap != null
                        ? () => onDayTap!(date)
                        : () => _showDayDetail(context, date, label, trains),
                child: Container(
                  width: 52,
                  decoration: BoxDecoration(
                    color:
                        isToday
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        isToday
                            ? Border.all(color: theme.colorScheme.primary)
                            : null,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        narrow[date.weekday % 7],
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight:
                              isToday ? FontWeight.w700 : FontWeight.w500,
                          color:
                              isToday
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        trains
                            ? Icons.fitness_center
                            : Icons.self_improvement,
                        size: 18,
                        color:
                            completed
                                ? theme.colorScheme.primary
                                : trains
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 4),
                      if (completed)
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: theme.colorScheme.primary,
                        )
                      else
                        const SizedBox(height: 14),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showDayDetail(
    BuildContext context,
    DateTime date,
    String label,
    bool trains,
  ) {
    final l10n = context.l10n;
    final weekday = DateFormat.EEEE(
      Localizations.localeOf(context).toString(),
    ).format(date);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  weekday,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  trains ? label : l10n.restDay,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
    );
  }
}
