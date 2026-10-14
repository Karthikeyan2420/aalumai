import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/widgets/common.dart';
import 'data/habit_repository.dart';
import 'domain/habit_streak.dart';
import 'habit_editor.dart';

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final habitsAsync = ref.watch(activeHabitsProvider);
    final completionsAsync = ref.watch(weekHabitCompletionsProvider);
    final today = HabitStreak.normalize(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: Text(l10n.habitChecklist)),
      floatingActionButton: FloatingActionButton.extended(
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
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            itemCount: habits.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final habit = habits[index];
              final days = byHabit[habit.id] ?? const <DateTime>{};
              final done = days.contains(today);
              final schedule = HabitSchedule.fromIndex(habit.scheduleType);
              final eligible = HabitStreak.isEligibleDay(
                schedule: schedule,
                weekdaysMask: habit.weekdaysMask,
                date: today,
              );
              final streak = HabitStreak.currentDayStreak(
                schedule: schedule,
                weekdaysMask: habit.weekdaysMask,
                completedDays: days,
                today: today,
              );
              return _HabitTile(
                habit: habit,
                completedToday: done,
                eligibleToday: eligible,
                streak: streak,
                weekDays: _weekDays(habit, days, today),
                onToggle:
                    () => ref
                        .read(habitRepositoryProvider)
                        .setCompleted(habit.id, today, completed: !done),
                onLongPress: () => _showActions(context, ref, habit),
                onTap: () => _showHeatmap(context, ref, habit),
              );
            },
          );
        },
      ),
    );
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
    final current = HabitStreak.currentDayStreak(
      schedule: schedule,
      weekdaysMask: habit.weekdaysMask,
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
    required this.habit,
    required this.completedToday,
    required this.eligibleToday,
    required this.streak,
    required this.weekDays,
    required this.onToggle,
    required this.onLongPress,
    required this.onTap,
  });

  final Habit habit;
  final bool completedToday;
  final bool eligibleToday;
  final int streak;
  final List<_DayDot> weekDays;
  final VoidCallback onToggle;
  final VoidCallback onLongPress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: eligibleToday ? onToggle : null,
                tooltip: context.l10n.habitComplete,
                icon: Icon(
                  completedToday
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color:
                      completedToday
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.outline,
                  size: 30,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (final d in weekDays)
                          Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    d.completed
                                        ? theme.colorScheme.secondary
                                        : d.eligible
                                        ? theme
                                            .colorScheme
                                            .surfaceContainerHighest
                                        : Colors.transparent,
                                border: Border.all(
                                  color:
                                      d.isToday
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.outlineVariant,
                                  width: d.isToday ? 2 : 1,
                                ),
                              ),
                            ),
                          ),
                        const Spacer(),
                        if (streak > 0)
                          Row(
                            children: [
                              Icon(
                                Icons.local_fire_department,
                                size: 16,
                                color: theme.colorScheme.tertiary,
                              ),
                              const SizedBox(width: 2),
                              Text('$streak'),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
