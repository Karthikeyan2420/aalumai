import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/l10n_extension.dart';
import '../data/fitness_repository.dart';

/// Compact progress summary: workouts completed this week, total workout
/// minutes, and a weekly completion progress bar. Uses actual saved session
/// data.
class ProgressSummary extends ConsumerWidget {
  const ProgressSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sessions = ref.watch(workoutSessionsProvider).valueOrNull ?? [];
    final prefs = ref.watch(workoutPreferencesProvider).valueOrNull;

    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    final weekSessions =
        sessions
            .where((s) => s.endedAt != null && s.startedAt.isAfter(weekStart))
            .toList();

    final workouts = weekSessions.length;
    final totalMinutes = weekSessions.fold<int>(
      0,
      (sum, s) => sum + (s.durationSec / 60).round(),
    );

    final targetWorkouts =
        prefs != null ? _trainingDaysCount(prefs.trainingDaysMask) : 4;
    final ratio =
        targetWorkouts > 0
            ? (workouts / targetWorkouts).clamp(0.0, 1.0)
            : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.progress,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    icon: Icons.fitness_center,
                    label: l10n.workouts,
                    value: '$workouts',
                  ),
                ),
                Expanded(
                  child: _Stat(
                    icon: Icons.timer_outlined,
                    label: l10n.duration,
                    value: '$totalMinutes ${l10n.minutesShort}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: ratio, minHeight: 8),
            ),
            const SizedBox(height: 4),
            Text(
              '$workouts / $targetWorkouts ${l10n.thisWeek}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _trainingDaysCount(int mask) {
    var count = 0;
    for (var d = 0; d < 7; d++) {
      if ((mask & (1 << d)) != 0) count++;
    }
    return count;
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
