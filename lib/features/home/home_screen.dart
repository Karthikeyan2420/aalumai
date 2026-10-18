import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/backgrounds/background_presets.dart';
import '../../core/db/database.dart';
import '../../core/localization/generated/app_localizations.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/providers/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/module_theme.dart';
import '../../core/utils/alarm_time.dart';
import '../../core/widgets/background_view.dart';
import '../../core/widgets/dashboard_components.dart';
import '../alarms/alarm_editor_screen.dart';
import '../alarms/data/alarm_repository.dart';
import '../expenses/data/finance_repository.dart';
import '../fitness/data/fitness_repository.dart';
import '../habits/data/habit_repository.dart';
import '../habits/domain/habit_streak.dart';
import '../learning/data/learning_repository.dart';
import '../meals/data/meal_repository.dart';
import '../music/data/music_providers.dart';
import '../notes/data/note_repository.dart';
import '../savings/data/savings_repository.dart';
import '../schedule/data/event_repository.dart';
import '../tasks/data/task_repository.dart';
import '../tasks/task_editor.dart';
import 'dashboard_sections.dart';
import 'quick_actions.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sections = ref.watch(dashboardConfigProvider).visible;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.appNameScript,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: l10n.customizeDashboard,
            icon: const Icon(Icons.tune),
            onPressed: () => context.push(AppRoutes.dashboardConfig),
          ),
          IconButton(
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: CustomBackground(
        slot: BackgroundSlot.home,
        minOverlay: 0.2,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(allEventsProvider);
            ref.invalidate(todayTasksProvider);
            ref.invalidate(nextAlarmProvider);
            ref.invalidate(waterTodayProvider);
            ref.invalidate(weekHabitCompletionsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
            children: [
              const _GreetingHeader(),
              const SizedBox(height: 16),
              for (final section in sections) ...[
                _DashboardSectionView(section: section),
                const SizedBox(height: 14),
              ],
              const _ModulesGrid(),
            ],
          ),
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
    DashboardSection.summary => const _TodaySummary(),
    DashboardSection.events => const _Upcoming(),
    DashboardSection.tasks => const _TodayTasks(),
    DashboardSection.habits => const _HabitsSummary(),
  };
}

/// Warm greeting block: a time-of-day icon, the full date and the app tagline.
class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    final (icon, accent) = switch (hour) {
      < 6 => (Icons.nightlight_round, ModuleAccents.music),
      < 12 => (Icons.wb_twilight, ModuleAccents.expenses),
      < 18 => (Icons.wb_sunny, ModuleAccents.savings),
      _ => (Icons.nights_stay, ModuleAccents.tasks),
    };
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: softTint(context, accent, 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat.yMMMMEEEEd().format(DateTime.now()),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.tagline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact daily progress drawn from real habit completion and task data.
class _TodaySummary extends ConsumerWidget {
  const _TodaySummary();

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
    final nextAlarm = alarm.valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.account_balance_wallet,
                accent: ModuleAccents.expenses,
                label: l10n.totalBalance,
                value:
                    balance.valueOrNull == null
                        ? '—'
                        : formatMoney(balance.valueOrNull!, locale),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                icon: Icons.water_drop,
                accent: ModuleAccents.water,
                label: l10n.water,
                value: '$waterTotal ml',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                icon: Icons.alarm,
                accent: ModuleAccents.alarm,
                label: l10n.nextAlarm,
                value:
                    nextAlarm == null
                        ? '—'
                        : AlarmTime.format(nextAlarm.hour, nextAlarm.minute),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _HabitTaskProgress(),
      ],
    );
  }
}

class _HabitTaskProgress extends ConsumerWidget {
  const _HabitTaskProgress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final habits = ref.watch(activeHabitsProvider).valueOrNull ?? const [];
    final completions =
        ref.watch(weekHabitCompletionsProvider).valueOrNull ?? const [];
    final tasks = ref.watch(todayTasksProvider).valueOrNull ?? const [];

    final today = HabitStreak.normalize(DateTime.now());
    final doneHabits =
        completions
            .where((c) => HabitStreak.normalize(c.day) == today)
            .map((c) => c.habitId)
            .toSet()
            .length;
    final doneTasks = tasks.where((t) => t.task.isCompleted).length;

    final habitProgress = habits.isEmpty ? 0.0 : doneHabits / habits.length;
    final taskProgress = tasks.isEmpty ? 0.0 : doneTasks / tasks.length;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProgressRow(
            icon: Icons.check_circle,
            accent: ModuleAccents.habits,
            label: l10n.habits,
            valueLabel: '$doneHabits/${habits.length}',
            progress: habitProgress,
          ),
          ProgressRow(
            icon: Icons.checklist,
            accent: ModuleAccents.tasks,
            label: l10n.dueToday,
            valueLabel: '$doneTasks/${tasks.length}',
            progress: taskProgress,
          ),
        ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.quickActions,
          action: TextButton(
            onPressed: () => showQuickActionsSheet(context, ref),
            child: Text(l10n.navMore),
          ),
        ),
        AppCard(
          padding: const EdgeInsets.all(12),
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
        ),
      ],
    );
  }
}

/// Next alarm plus the next scheduled event for today.
class _Upcoming extends ConsumerWidget {
  const _Upcoming();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final events = ref.watch(allEventsProvider);
    final alarm = ref.watch(nextAlarmProvider);

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final todays =
        events.valueOrNull == null
            ? const <Event>[]
            : EventRepository.expand(events.valueOrNull!, start, end);

    final nextAlarm = alarm.valueOrNull;
    final nextEvent =
        todays.where((e) => e.startAt.isAfter(now)).isEmpty
            ? null
            : todays
                .where((e) => e.startAt.isAfter(now))
                .reduce((a, b) => a.startAt.isBefore(b.startAt) ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.upcomingReminders,
          action: TextButton.icon(
            key: const ValueKey('home_quick_add_alarm'),
            onPressed: () => showAlarmEditor(context, ref),
            icon: const Icon(Icons.add_alarm, size: 18),
            label: Text(l10n.newAlarm),
          ),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: softTint(context, ModuleAccents.alarm, 0.18),
                  child: const Icon(
                    Icons.alarm,
                    color: ModuleAccents.alarm,
                    size: 20,
                  ),
                ),
                title: Text(l10n.nextAlarm),
                subtitle: Text(
                  nextAlarm == null ? l10n.noUpcomingAlarms : l10n.alarms,
                ),
                trailing: Text(
                  nextAlarm == null
                      ? '—'
                      : AlarmTime.format(nextAlarm.hour, nextAlarm.minute),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () => context.push(AppRoutes.alarms),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: softTint(
                    context,
                    ModuleAccents.schedule,
                    0.18,
                  ),
                  child: const Icon(
                    Icons.event,
                    color: ModuleAccents.schedule,
                    size: 20,
                  ),
                ),
                title: Text(l10n.todaysEvents),
                subtitle: Text(
                  nextEvent == null ? l10n.emptyEvents : nextEvent.title,
                ),
                trailing:
                    nextEvent == null
                        ? null
                        : Text(
                          DateFormat.Hm().format(nextEvent.startAt),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                onTap: () => context.push(AppRoutes.schedule),
              ),
            ],
          ),
        ),
      ],
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
      data: (list) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: l10n.dueToday),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child:
                  list.isEmpty
                      ? _EmptyRow(
                        icon: Icons.task_alt,
                        message: l10n.emptyTasks,
                        actionLabel: l10n.quickAddTask,
                        onAction: () => showTaskEditor(context),
                      )
                      : Column(
                        children: [
                          for (final t in list.take(5))
                            CheckboxListTile(
                              dense: true,
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
          ],
        );
      },
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
        final doneToday = <int>{};
        for (final c in completions.valueOrNull ?? const []) {
          if (HabitStreak.normalize(c.day) == today) doneToday.add(c.habitId);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: l10n.habitChecklist),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child:
                  list.isEmpty
                      ? _EmptyRow(
                        icon: Icons.check_circle_outline,
                        message: l10n.emptyHabits,
                        actionLabel: l10n.habits,
                        onAction: () => context.push(AppRoutes.habits),
                      )
                      : Column(
                        children: [
                          for (final habit in list.take(5))
                            CheckboxListTile(
                              dense: true,
                              value: doneToday.contains(habit.id),
                              title: Text(habit.name),
                              onChanged:
                                  (v) => ref
                                      .read(habitRepositoryProvider)
                                      .setCompleted(
                                        habit.id,
                                        today,
                                        completed: v ?? false,
                                      ),
                            ),
                        ],
                      ),
            ),
          ],
        );
      },
    );
  }
}

/// The always-visible launcher of colourful module cards with live values.
class _ModulesGrid extends ConsumerWidget {
  const _ModulesGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cards = _moduleCards(context, ref, l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l10n.dashboard),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 900 ? 4 : (width >= 560 ? 3 : 2);
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.15,
              children: cards,
            );
          },
        ),
      ],
    );
  }
}

List<Widget> _moduleCards(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
) {
  final locale = Localizations.localeOf(context).toString();
  final events = ref.watch(allEventsProvider).valueOrNull ?? const [];
  final tasks = ref.watch(todayTasksProvider).valueOrNull ?? const [];
  final habits = ref.watch(activeHabitsProvider).valueOrNull ?? const [];
  final sessions = ref.watch(workoutSessionsProvider).valueOrNull ?? const [];
  final notes = ref.watch(allNotesProvider).valueOrNull ?? const [];
  final goals = ref.watch(savingsGoalsProvider).valueOrNull ?? const [];
  final recipes = ref.watch(recipesProvider).valueOrNull ?? const [];
  final tracks = ref.watch(musicTracksProvider).valueOrNull ?? const [];
  final courses = ref.watch(coursesProvider).valueOrNull ?? const [];
  final balance = ref.watch(totalBalanceProvider).valueOrNull;
  final alarm = ref.watch(nextAlarmProvider).valueOrNull;

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todaysEvents = EventRepository.expand(
    events,
    todayStart,
    todayStart.add(const Duration(days: 1)),
  );
  final openTasks = tasks.where((t) => !t.task.isCompleted).length;

  return [
    ModuleCard(
      module: DashboardModule.alarm,
      title: l10n.alarms,
      value:
          alarm == null
              ? l10n.none
              : AlarmTime.format(alarm.hour, alarm.minute),
      subtitle: l10n.nextAlarm,
      onTap: () => context.push(AppRoutes.alarms),
    ),
    ModuleCard(
      module: DashboardModule.schedule,
      title: l10n.navSchedule,
      value: '${todaysEvents.length}',
      subtitle: l10n.todaysEvents,
      onTap: () => context.push(AppRoutes.schedule),
    ),
    ModuleCard(
      module: DashboardModule.tasks,
      title: l10n.navTasks,
      value: '$openTasks',
      subtitle: l10n.dueToday,
      onTap: () => context.push(AppRoutes.tasks),
    ),
    ModuleCard(
      module: DashboardModule.fitness,
      title: l10n.fitness,
      value: '${sessions.length}',
      subtitle: l10n.workoutHistory,
      onTap: () => context.push(AppRoutes.fitness),
    ),
    ModuleCard(
      module: DashboardModule.habits,
      title: l10n.habits,
      value: '${habits.length}',
      subtitle: l10n.today,
      onTap: () => context.push(AppRoutes.habits),
    ),
    ModuleCard(
      module: DashboardModule.notes,
      title: l10n.notes,
      value: '${notes.length}',
      subtitle: l10n.notes,
      onTap: () => context.push(AppRoutes.notes),
    ),
    ModuleCard(
      module: DashboardModule.expenses,
      title: l10n.expenses,
      value: balance == null ? '—' : formatMoney(balance, locale),
      subtitle: l10n.totalBalance,
      onTap: () => context.push(AppRoutes.expenses),
    ),
    ModuleCard(
      module: DashboardModule.savings,
      title: l10n.savingsGoals,
      value: '${goals.length}',
      subtitle: l10n.savingsGoals,
      onTap: () => context.push(AppRoutes.savings),
    ),
    ModuleCard(
      module: DashboardModule.meals,
      title: l10n.meals,
      value: '${recipes.length}',
      subtitle: l10n.recipes,
      onTap: () => context.push(AppRoutes.meals),
    ),
    ModuleCard(
      module: DashboardModule.music,
      title: l10n.music,
      value: '${tracks.length}',
      subtitle: l10n.tracks,
      onTap: () => context.push(AppRoutes.music),
    ),
    ModuleCard(
      module: DashboardModule.learning,
      title: l10n.learnEnglish,
      value: '${courses.length}',
      subtitle: l10n.continueLearning,
      onTap: () => context.push(AppRoutes.learning),
    ),
  ];
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.outline),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
