import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Circular progress for plan day (e.g. day 12 of 30).
class DayProgressRing extends StatelessWidget {
  const DayProgressRing({
    super.key,
    required this.day,
    required this.total,
    this.size = 56,
    this.strokeWidth = 5,
    this.accent,
  });

  final int day;
  final int total;
  final double size;
  final double strokeWidth;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? theme.colorScheme.secondary;
    final progress = total <= 0 ? 0.0 : (day / total).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: strokeWidth,
            backgroundColor: color.withValues(alpha: 0.15),
            color: color,
          ),
          Text(
            '$day',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Day 12 of 30" with optional ring.
class DayCounter extends StatelessWidget {
  const DayCounter({
    super.key,
    required this.day,
    required this.total,
    this.showRing = true,
    this.accent,
  });

  final int day;
  final int total;
  final bool showRing;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? theme.colorScheme.secondary;
    return Row(
      children: [
        if (showRing) ...[
          DayProgressRing(day: day, total: total, accent: color),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Day $day of $total',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${(100 * day / total).round()}% through your plan',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StreakBadge extends StatelessWidget {
  const StreakBadge({super.key, required this.days, this.accent});

  final int days;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? AppColors.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, size: 18, color: color),
          const SizedBox(width: 4),
          Text(
            days <= 0 ? 'Start streak' : '$days-day streak',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class SessionStatRow extends StatelessWidget {
  const SessionStatRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accent,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? theme.colorScheme.secondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Short motivational line under a title.
class MotivationLine extends StatelessWidget {
  const MotivationLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyLarge?.copyWith(
        height: 1.35,
        color: theme.colorScheme.onSurface,
      ),
    );
  }
}
