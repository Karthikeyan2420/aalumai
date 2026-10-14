import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/localization/l10n_extension.dart';
import '../../core/providers/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/alarm_time.dart';
import '../../core/widgets/common.dart';
import '../alarms/data/alarm_repository.dart';
import '../expenses/data/finance_repository.dart';
import '../fitness/data/fitness_repository.dart';
import '../habits/data/habit_repository.dart';
import '../habits/domain/habit_streak.dart';
import '../schedule/data/event_repository.dart';
import '../tasks/data/task_repository.dart';
import 'dashboard_sections.dart';
import 'quick_actions.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sections = ref.watch(dashboardConfigProvider).visible;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appNameScript),
        actions: [
          IconButton(
            tooltip: l10n.customizeDashboard,
            icon: const Icon(Icons.tune),
            onPressed: () => context.push(AppRoutes.dashboardConfig),
          ),
          IconButton(
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go(AppRoutes.settings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allEventsProvider);
          ref.invalidate(todayTasksProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            Text(
              DateFormat.yMMMMEEEEd().format(DateTime.now()),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final section in sections) ...[
              _DashboardSectionView(section: section),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _DashboardSectionView extends StatelessWidget {
  const _DashboardSectionView({required this.section});

  final DashboardSection section;

  @override
  Widget build(BuildContext context) => switch (section) {
    DashboardSection.quickActions => const _QuickActions(),
    DashboardSection.summary => const _SummaryRow(),
    DashboardSection.events => const _TodayEvents(),
    DashboardSection.tasks => const _TodayTasks(),
    DashboardSection.habits => const _HabitsSummary(),
  };
}

class _SummaryRow extends ConsumerWidget {
  const _SummaryRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final balance = ref.watch(totalBalanceProvider);
    final water = ref.watch(waterTodayProvider);
    final alarm = ref.watch(nextAlarmProvider);

    final waterTotal = (water.valueOrNull ?? const []).fold<int>(
      0,
      (s, w) => s + w.amountMl,
    );

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.account_balance_wallet_outlined,
            label: l10n.totalBalance,
            value:
                balance.valueOrNull == null
                    ? '—'
                    : formatMoney(balance.valueOrNull!, locale),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            icon: Icons.water_drop_outlined,
            label: l10n.water,
            value: '$waterTotal ml',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            icon: Icons.alarm,
            label: l10n.nextAlarm,
            value:
                alarm.valueOrNull == null
                    ? '—'
                    : AlarmTime.format(
                      alarm.valueOrNull!.hour,
                      alarm.valueOrNull!.minute,
                    ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.secondary),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ordered = orderedQuickActions(ref.watch(appPreferencesProvider));
    final primary = ordered.take(4).toList();
    return SectionCard(
      title: l10n.quickActions,
      icon: Icons.bolt_outlined,
      trailing: TextButton(
        onPressed: () => showQuickActionsSheet(context, ref),
        child: Text(l10n.navMore),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final action in primary)
            ActionChip(
              avatar: Icon(action.icon, size: 18),
              label: Text(quickActionLabel(context, action)),
              onPressed: () => runQuickAction(context, ref, action),
            ),
        ],
      ),
    );
  }
}

class _TodayEvents extends ConsumerWidget {
  const _TodayEvents();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final events = ref.watch(allEventsProvider);
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return events.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (list) {
        final todays = EventRepository.expand(list, start, end);
        return SectionCard(
          title: l10n.todaysEvents,
          icon: Icons.event_outlined,
          child:
              todays.isEmpty
                  ? Text(
                    l10n.emptyEvents,
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                  : Column(
                    children: [
                      for (final e in todays)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.schedule),
                          title: Text(e.title),
                          subtitle: Text(e.description),
                          trailing: Text(DateFormat.Hm().format(e.startAt)),
                        ),
                    ],
                  ),
        );
      },
    );
  }
}

class _TodayTasks extends ConsumerWidget {
  const _TodayTasks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tasks = ref.watch(todayTasksProvider);
    return tasks.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data:
          (list) => SectionCard(
            title: l10n.dueToday,
            icon: Icons.checklist_outlined,
            child:
                list.isEmpty
                    ? Text(
                      l10n.emptyTasks,
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                    : Column(
                      children: [
                        for (final t in list.take(5))
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: t.task.isCompleted,
                            title: Text(t.task.title),
                            onChanged:
                                (v) => ref
                                    .read(taskRepositoryProvider)
                                    .setCompleted(t.task, v ?? false),
                          ),
                      ],
                    ),
          ),
    );
  }
}

class _HabitsSummary extends ConsumerWidget {
  const _HabitsSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final habits = ref.watch(activeHabitsProvider);
    final completions = ref.watch(weekHabitCompletionsProvider);
    final today = HabitStreak.normalize(DateTime.now());
    return habits.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) {
          return SectionCard(
            title: l10n.habitChecklist,
            icon: Icons.check_circle_outline,
            child: Text(
              l10n.emptyHabits,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }
        final doneToday = <int>{};
        for (final c in completions.valueOrNull ?? const []) {
          if (HabitStreak.normalize(c.day) == today) doneToday.add(c.habitId);
        }
        return SectionCard(
          title: l10n.habitChecklist,
          icon: Icons.check_circle_outline,
          child: Column(
            children: [
              for (final habit in list.take(5))
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: doneToday.contains(habit.id),
                  title: Text(habit.name),
                  onChanged:
                      (v) => ref
                          .read(habitRepositoryProvider)
                          .setCompleted(habit.id, today, completed: v ?? false),
                ),
            ],
          ),
        );
      },
    );
  }
}
