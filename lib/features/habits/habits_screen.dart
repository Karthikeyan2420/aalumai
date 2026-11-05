import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/module_theme.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_scaffold.dart';
import 'data/habit_repository.dart';
import 'domain/habit_streak.dart';
import 'habit_editor.dart';
import '../expenses/item_actions.dart';

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final habitsAsync = ref.watch(activeHabitsProvider);
    final completionsAsync = ref.watch(habitStreakCompletionsProvider);
    final today = HabitStreak.normalize(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.habitChecklist),
        backgroundColor: softTint(context, DashboardModule.habits.accent, 0.08),
        actions: [
          IconButton(
            tooltip: l10n.archivedHabits,
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: () => _showArchived(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'habitsAdd',
        onPressed: () => showHabitEditor(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.add),
      ),
      body: habitsAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (habits) {
          if (habits.isEmpty) {
            return EmptyState(
              icon: Icons.check_circle_outline,
              message: l10n.emptyHabits,
              accent: DashboardModule.habits.accent,
              actionLabel: l10n.add,
              onAction: () => showHabitEditor(context),
            );
          }
          final completions = completionsAsync.valueOrNull ?? const [];
          final byHabit = <int, Set<DateTime>>{};
          for (final c in completions) {
            byHabit
                .putIfAbsent(c.habitId, () => <DateTime>{})
                .add(HabitStreak.normalize(c.day));
          }
          return ReorderableListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              12,
              AppSpacing.screen,
              96,
            ),
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > oldIndex) newIndex--;
              final ids = habits.map((h) => h.id).toList();
              final moved = ids.removeAt(oldIndex);
              ids.insert(newIndex, moved);
              await ref.read(habitRepositoryProvider).reorderActive(ids);
            },
            buildDefaultDragHandles: false,
            children: [
              for (var index = 0; index < habits.length; index++)
                _habitListTile(
                  context,
                  ref,
                  listIndex: index,
                  key: ValueKey(habits[index].id),
                  habit: habits[index],
                  byHabit: byHabit,
                  today: today,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _habitListTile(
    BuildContext context,
    WidgetRef ref, {
    required Key key,
    required int listIndex,
    required Habit habit,
    required Map<int, Set<DateTime>> byHabit,
    required DateTime today,
  }) {
    final days = byHabit[habit.id] ?? const <DateTime>{};
    final done = days.contains(today);
    final schedule = HabitSchedule.fromIndex(habit.scheduleType);
    final eligible = HabitStreak.isEligibleDay(
      schedule: schedule,
      weekdaysMask: habit.weekdaysMask,
      date: today,
    );
    final streak = HabitStreak.currentStreak(
      schedule: schedule,
      weekdaysMask: habit.weekdaysMask,
      targetPerWeek: habit.targetPerWeek,
      completedDays: days,
      today: today,
    );
    return KeyedSubtree(
      key: key,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
        child: _HabitTile(
          listIndex: listIndex,
          habit: habit,
          completedToday: done,
          eligibleToday: eligible,
          streak: streak,
          weekly: schedule == HabitSchedule.weeklyTarget,
          weekDays: _weekDays(habit, days, today),
          onToggle:
              () => _toggleHabit(context, ref, habit, today, done, days),
          onDayTap:
              (day) => _toggleDay(context, ref, habit, day, days),
          onMore: () => _showActions(context, ref, habit),
          onTap: () => _showHeatmap(context, ref, habit),
        ),
      ),
    );
  }

  Future<void> _toggleHabit(
    BuildContext context,
    WidgetRef ref,
    Habit habit,
    DateTime today,
    bool done,
    Set<DateTime> days,
  ) async {
    final repo = ref.read(habitRepositoryProvider);
    if (done) {
      await repo.setCompleted(habit.id, today, completed: false);
      return;
    }
    if (habit.isMeasurable) {
      final value = await _promptMeasure(context, habit);
      if (value == null) return;
      await repo.setCompleted(
        habit.id,
        today,
        completed: true,
        value: value,
      );
      return;
    }
    await repo.setCompleted(habit.id, today, completed: true);
  }

  Future<void> _toggleDay(
    BuildContext context,
    WidgetRef ref,
    Habit habit,
    DateTime day,
    Set<DateTime> days,
  ) async {
    final normalized = HabitStreak.normalize(day);
    final schedule = HabitSchedule.fromIndex(habit.scheduleType);
    if (!HabitStreak.isEligibleDay(
      schedule: schedule,
      weekdaysMask: habit.weekdaysMask,
      date: normalized,
    )) {
      return;
    }
    final done = days.contains(normalized);
    await _toggleHabit(context, ref, habit, normalized, done, days);
  }

  Future<double?> _promptMeasure(BuildContext context, Habit habit) async {
    final l10n = context.l10n;
    final ctrl = TextEditingController(
      text: habit.goalValue > 0 ? habit.goalValue.toString() : '',
    );
    final result = await showDialog<double>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(habit.name),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.amount,
                suffixText: habit.unit.isEmpty ? null : habit.unit,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  final v = double.tryParse(ctrl.text.trim());
                  if (v != null && v > 0) Navigator.pop(ctx, v);
                },
                child: Text(l10n.save),
              ),
            ],
          ),
    );
    return result;
  }

  List<_DayDot> _weekDays(Habit habit, Set<DateTime> days, DateTime today) {
    final start = HabitStreak.startOfWeek(today);
    final schedule = HabitSchedule.fromIndex(habit.scheduleType);
    return List.generate(7, (i) {
      final day = start.add(Duration(days: i));
      final eligible = HabitStreak.isEligibleDay(
        schedule: schedule,
        weekdaysMask: habit.weekdaysMask,
        date: day,
      );
      return _DayDot(
        date: day,
        completed: days.contains(HabitStreak.normalize(day)),
        eligible: eligible,
        isToday: HabitStreak.normalize(day) == today,
      );
    });
  }

  Future<void> _showArchived(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (ctx) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.5,
            builder:
                (context, controller) => ref.watch(archivedHabitsProvider).when(
                  loading: () => const LoadingState(),
                  error: (e, _) => ErrorState(message: e.toString()),
                  data:
                      (habits) => ListView(
                        controller: controller,
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            l10n.archivedHabits,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          if (habits.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(l10n.emptyHabits),
                            ),
                          for (final h in habits)
                            ListTile(
                              title: Text(h.name),
                              trailing: TextButton(
                                onPressed: () {
                                  ref
                                      .read(habitRepositoryProvider)
                                      .setArchived(h.id, false);
                                },
                                child: Text(l10n.restore),
                              ),
                            ),
                        ],
                      ),
                ),
          ),
    );
  }

  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    Habit habit,
  ) async {
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(l10n.edit),
                  onTap: () {
                    Navigator.pop(context);
                    showHabitEditor(context, habit: habit);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.archive_outlined),
                  title: Text(l10n.habitArchived),
                  onTap: () {
                    ref
                        .read(habitRepositoryProvider)
                        .setArchived(habit.id, !habit.isArchived);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(l10n.delete),
                  onTap: () async {
                    Navigator.pop(context);
                    final ok = await confirmDialog(
                      context,
                      title: l10n.deleteConfirmTitle,
                      body: l10n.deleteConfirmBody,
                      confirmLabel: l10n.delete,
                    );
                    if (ok) {
                      await ref
                          .read(habitRepositoryProvider)
                          .deleteHabit(habit.id);
                    }
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _showHeatmap(
    BuildContext context,
    WidgetRef ref,
    Habit habit,
  ) async {
    final repo = ref.read(habitRepositoryProvider);
    final days = await repo.completedDays(habit.id);
    if (!context.mounted) return;
    final allDays = days.toList()..sort();
    final schedule = HabitSchedule.fromIndex(habit.scheduleType);
    final current = HabitStreak.currentStreak(
      schedule: schedule,
      weekdaysMask: habit.weekdaysMask,
      targetPerWeek: habit.targetPerWeek,
      completedDays: days,
      today: HabitStreak.normalize(DateTime.now()),
    );
    if (!context.mounted) return;
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(habit.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Stat(
                      label: l10n.habitStreak,
                      value: current.toString(),
                      icon: Icons.local_fire_department,
                    ),
                    const SizedBox(width: 24),
                    _Stat(
                      label: l10n.habitComplete,
                      value: days.length.toString(),
                      icon: Icons.check_circle_outline,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.lastModified,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final day in allDays.reversed.take(30))
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          DateFormat('d').format(day),
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          showHabitEditor(context, habit: habit);
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(l10n.edit),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          final ok = await confirmDialog(
                            context,
                            title: l10n.deleteConfirmTitle,
                            body: l10n.deleteConfirmBody,
                            confirmLabel: l10n.delete,
                          );
                          if (ok) {
                            await ref
                                .read(habitRepositoryProvider)
                                .deleteHabit(habit.id);
                          }
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: Text(l10n.delete),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}

class _DayDot {
  const _DayDot({
    required this.date,
    required this.completed,
    required this.eligible,
    required this.isToday,
  });
  final DateTime date;
  final bool completed;
  final bool eligible;
  final bool isToday;
}

class _HabitTile extends StatelessWidget {
  const _HabitTile({
    required this.listIndex,
    required this.habit,
    required this.completedToday,
    required this.eligibleToday,
    required this.streak,
    required this.weekDays,
    required this.onToggle,
    required this.onTap,
    required this.onMore,
    required this.onDayTap,
    this.weekly = false,
  });

  final int listIndex;
  final Habit habit;
  final bool completedToday;
  final bool eligibleToday;
  final int streak;
  final bool weekly;
  final List<_DayDot> weekDays;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onMore;
  final void Function(DateTime day) onDayTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final accent = DashboardModule.habits.accent;
    return ModuleListTile(
      onTap: onTap,
      trailing: itemMoreButton(onPressed: onMore),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReorderableDragStartListener(
            index: listIndex,
            child: Tooltip(
              message: l10n.reorder,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.drag_handle,
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              onPressed: eligibleToday ? onToggle : null,
              tooltip: l10n.habitComplete,
              icon: Icon(
                completedToday
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color:
                    completedToday
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                size: 28,
              ),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            habit.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final d in weekDays)
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: GestureDetector(
                    onTap: d.eligible ? () => onDayTap(d.date) : null,
                    child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          d.completed
                              ? accent
                              : d.eligible
                              ? theme.colorScheme.surfaceContainerHighest
                              : Colors.transparent,
                      border: Border.all(
                        color:
                            d.isToday
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant,
                        width: d.isToday ? 2.5 : 1,
                      ),
                    ),
                  ),
                ),
                ),
              const Spacer(),
              if (streak > 0)
                Row(
                  children: [
                    Icon(
                      weekly
                          ? Icons.calendar_view_week
                          : Icons.local_fire_department,
                      size: 16,
                      color: theme.colorScheme.tertiary,
                    ),
                    const SizedBox(width: 2),
                    Text(weekly ? '${streak}w' : '$streak'),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
