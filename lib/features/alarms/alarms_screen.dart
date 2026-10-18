import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/localization/generated/app_localizations.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/services/alarm_scheduler.dart';
import '../../core/utils/alarm_time.dart';
import '../../core/widgets/common.dart';
import 'alarm_editor_screen.dart';
import 'alarm_ringing_screen.dart';
import 'data/alarm_repository.dart';

class AlarmsScreen extends ConsumerWidget {
  const AlarmsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final alarms = ref.watch(alarmsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.alarms)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'alarmsAdd',
        onPressed: () => showAlarmEditor(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.add),
      ),
      body: alarms.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.alarm,
              message: l10n.emptyAlarms,
              actionLabel: l10n.newAlarm,
              onAction: () => showAlarmEditor(context, ref),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              const _SchedulingBanner(),
              const _UpcomingCard(),
              for (final a in list) _AlarmTile(alarm: a),
            ],
          );
        },
      ),
    );
  }
}

/// Shows an actionable message when exact alarms are blocked by the OS or the
/// last scheduling attempt failed, instead of silently swallowing the problem.
class _SchedulingBanner extends ConsumerStatefulWidget {
  const _SchedulingBanner();

  @override
  ConsumerState<_SchedulingBanner> createState() => _SchedulingBannerState();
}

class _SchedulingBannerState extends ConsumerState<_SchedulingBanner> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(alarmRepositoryProvider).refreshCapability();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = ref.watch(alarmRepositoryProvider).status;
    return ValueListenableBuilder<AlarmSchedulingStatus>(
      valueListenable: status,
      builder: (context, value, _) {
        final children = <Widget>[];
        if (value.exactAlarmsAllowed == false) {
          children.add(
            Card(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.alarm),
                title: Text(l10n.exactAlarmTitle),
                subtitle: Text(l10n.exactAlarmBody),
                trailing: TextButton(
                  onPressed:
                      () =>
                          ref
                              .read(alarmRepositoryProvider)
                              .requestExactAlarms(),
                  child: Text(l10n.exactAlarmAction),
                ),
              ),
            ),
          );
        }
        if (value.lastError != null) {
          children.add(
            Card(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.error_outline),
                title: Text(l10n.alarmScheduleError),
                subtitle: Text(value.lastError!),
              ),
            ),
          );
        }
        if (children.isEmpty) return const SizedBox.shrink();
        return Column(children: children);
      },
    );
  }
}

class _UpcomingCard extends ConsumerWidget {
  const _UpcomingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final upcoming = ref.watch(upcomingAlarmsProvider).valueOrNull ?? const [];
    if (upcoming.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 20,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.upcomingAlarms,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final item in upcoming.take(4))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(
                      AlarmTime.format(item.alarm.hour, item.alarm.minute),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.alarm.label.isEmpty
                            ? _relativeDay(context, item.next)
                            : item.alarm.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _relativeDay(context, item.next),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _relativeDay(BuildContext context, DateTime next) {
    final now = DateTime.now();
    final days =
        DateTime(
          next.year,
          next.month,
          next.day,
        ).difference(DateTime(now.year, now.month, now.day)).inDays;
    final l10n = context.l10n;
    return switch (days) {
      0 => l10n.today,
      1 => l10n.tomorrow,
      _ => MaterialLocalizations.of(context).formatMediumDate(next),
    };
  }
}

/// A single alarm: an emphasised card showing the time, which days it fires,
/// its label and next ring, with preview / enable / overflow controls.
class _AlarmTile extends ConsumerWidget {
  const _AlarmTile({required this.alarm});
  final Alarm alarm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = alarm.isEnabled;
    final next =
        enabled ? ref.read(alarmRepositoryProvider).nextRing(alarm) : null;
    final dim = enabled ? scheme.onSurface : scheme.outline;
    final muted = enabled ? scheme.onSurfaceVariant : scheme.outline;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      elevation: 0,
      color:
          enabled
              ? scheme.primaryContainer.withValues(alpha: 0.35)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color:
              enabled
                  ? scheme.secondary.withValues(alpha: 0.4)
                  : scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showAlarmEditor(context, ref, alarm: alarm),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AlarmTime.format(alarm.hour, alarm.minute),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w300,
                        color: dim,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.previewAlarm,
                    icon: const Icon(Icons.play_circle_outline),
                    onPressed:
                        () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder:
                                (_) => AlarmRingingScreen(
                                  alarm: alarm,
                                  isPreview: true,
                                ),
                          ),
                        ),
                  ),
                  Switch(
                    value: enabled,
                    onChanged:
                        (v) => ref
                            .read(alarmRepositoryProvider)
                            .setEnabled(alarm.id, v),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          await showAlarmEditor(context, ref, alarm: alarm);
                        case 'duplicate':
                          await ref
                              .read(alarmRepositoryProvider)
                              .duplicate(alarm.id);
                        case 'delete':
                          final ok = await confirmDialog(
                            context,
                            title: l10n.deleteConfirmTitle,
                            body: l10n.deleteConfirmBody,
                            confirmLabel: l10n.delete,
                          );
                          if (ok) {
                            await ref
                                .read(alarmRepositoryProvider)
                                .delete(alarm.id);
                          }
                      }
                    },
                    itemBuilder:
                        (context) => [
                          PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
                          PopupMenuItem(
                            value: 'duplicate',
                            child: Text(l10n.duplicate),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(l10n.delete),
                          ),
                        ],
                  ),
                ],
              ),
              if (alarm.label.isNotEmpty) ...[
                Text(
                  alarm.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: dim,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (_showsChips) ...[
                const SizedBox(height: 8),
                _DayChips(mask: alarm.repeatDaysMask, active: enabled),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.repeat, size: 14, color: muted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _repeatSummary(l10n),
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ),
                  if (next != null) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.schedule, size: 14, color: scheme.secondary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${l10n.nextRing}: ${_formatNext(context, next)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A one-time alarm has no repeat days to show; a daily one is implied by
  /// every chip being lit.
  bool get _showsChips => !(alarm.repeatDaysMask == 0 && alarm.oneTime);

  String _repeatSummary(AppLocalizations l10n) {
    if (alarm.repeatDaysMask == 0) {
      return alarm.oneTime ? l10n.oneTime : l10n.everyDay;
    }
    return l10n.selectedDays;
  }

  String _formatNext(BuildContext context, DateTime next) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(next.year, next.month, next.day);
    final diff = day.difference(today).inDays;
    final l10n = context.l10n;
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(next));
    return switch (diff) {
      0 => '${l10n.today} · $time',
      1 => '${l10n.tomorrow} · $time',
      _ =>
        '${MaterialLocalizations.of(context).formatMediumDate(next)} · $time',
    };
  }
}

/// The seven weekday chips, lit for every day this alarm fires on.
class _DayChips extends StatelessWidget {
  const _DayChips({required this.mask, required this.active});

  final int mask;
  final bool active;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = active ? AlarmTime.weekdays(mask).toSet() : const <int>{};
    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  on.contains(i + 1)
                      ? scheme.secondary
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
            ),
            child: Text(
              _labels[i],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: on.contains(i + 1) ? scheme.onSecondary : scheme.outline,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
