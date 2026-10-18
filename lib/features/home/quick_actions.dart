import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/l10n_extension.dart';
import '../../core/preferences/app_preferences.dart';
import '../../core/providers/providers.dart';
import '../../core/router/app_router.dart';
import '../expenses/expenses_screen.dart';
import '../fitness/data/fitness_repository.dart';
import '../fitness/fitness_screen.dart';
import '../habits/data/habit_repository.dart';
import '../habits/habit_editor.dart';
import '../notes/note_editor.dart';
import '../tasks/task_editor.dart';

/// The set of one-tap actions available from the dashboard.
enum QuickAction { expense, task, water, note, habit, workout, learn }

extension QuickActionX on QuickAction {
  IconData get icon => switch (this) {
    QuickAction.expense => Icons.payments_outlined,
    QuickAction.task => Icons.add_task,
    QuickAction.water => Icons.water_drop_outlined,
    QuickAction.note => Icons.edit_note,
    QuickAction.habit => Icons.check_circle_outline,
    QuickAction.workout => Icons.fitness_center,
    QuickAction.learn => Icons.school_outlined,
  };
}

String quickActionLabel(BuildContext context, QuickAction action) {
  final l10n = context.l10n;
  return switch (action) {
    QuickAction.expense => l10n.quickAddExpense,
    QuickAction.task => l10n.quickAddTask,
    QuickAction.water => l10n.quickWater,
    QuickAction.note => l10n.quickNote,
    QuickAction.habit => l10n.habits,
    QuickAction.workout => l10n.startWorkout,
    QuickAction.learn => l10n.quickLearn,
  };
}

/// Orders [QuickAction.values] so the most-recently-used appear first.
List<QuickAction> orderedQuickActions(AppPreferences prefs) {
  final recent = prefs.recentQuickActions;
  final ordered = <QuickAction>[];
  for (final key in recent) {
    final match = QuickAction.values.where((a) => a.name == key).firstOrNull;
    if (match != null && !ordered.contains(match)) ordered.add(match);
  }
  for (final action in QuickAction.values) {
    if (!ordered.contains(action)) ordered.add(action);
  }
  return ordered;
}

Future<void> _recordRecent(WidgetRef ref, QuickAction action) async {
  final prefs = ref.read(appPreferencesProvider);
  final recent = [
    action.name,
    ...prefs.recentQuickActions.where((k) => k != action.name),
  ];
  await prefs.setRecentQuickActions(recent.take(7).toList());
}

/// Performs a real, data-persisting quick action.
Future<void> runQuickAction(
  BuildContext context,
  WidgetRef ref,
  QuickAction action,
) async {
  await _recordRecent(ref, action);
  if (!context.mounted) return;
  switch (action) {
    case QuickAction.expense:
      await showTransactionEditor(context, ref);
    case QuickAction.task:
      await showTaskEditor(context);
    case QuickAction.water:
      await _addWater(context, ref);
    case QuickAction.note:
      await _addNote(context, ref);
    case QuickAction.habit:
      await _completeHabit(context, ref);
    case QuickAction.workout:
      await _startWorkout(context, ref);
    case QuickAction.learn:
      if (context.mounted) context.push(AppRoutes.learning);
  }
}

/// Bottom sheet presenting every quick action in a compact grid. Returns the
/// chosen action so the caller can run it with its own (still-mounted) context.
Future<void> showQuickActionsSheet(BuildContext context, WidgetRef ref) async {
  final action = await showModalBottomSheet<QuickAction>(
    context: context,
    showDragHandle: true,
    builder:
        (context) => _QuickActionsSheet(
          ordered: orderedQuickActions(ref.read(appPreferencesProvider)),
        ),
  );
  if (action != null && context.mounted) {
    await runQuickAction(context, ref, action);
  }
}

class _QuickActionsSheet extends StatelessWidget {
  const _QuickActionsSheet({required this.ordered});
  final List<QuickAction> ordered;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.quickActions,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final action in ordered)
                  _QuickActionTile(
                    action: action,
                    onTap: () => Navigator.pop(context, action),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action, required this.onTap});
  final QuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 104,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              children: [
                Icon(action.icon, color: theme.colorScheme.primary),
                const SizedBox(height: 8),
                Text(
                  quickActionLabel(context, action),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _addWater(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final prefs = ref.read(appPreferencesProvider);
  final presets = <int>{150, 250, 500, prefs.quickWaterMl}.toList()..sort();
  final amount = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder:
        (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.addWater,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final ml in presets)
                      ChoiceChip(
                        label: Text('$ml ml'),
                        selected: ml == prefs.quickWaterMl,
                        onSelected: (_) => Navigator.pop(context, ml),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.tune, size: 18),
                      label: Text(l10n.amount),
                      onPressed: () async {
                        final custom = await _promptAmount(context);
                        if (context.mounted) Navigator.pop(context, custom);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
  );
  if (amount == null || amount <= 0) return;
  final id = await ref.read(fitnessRepositoryProvider).addWater(amount);
  await prefs.setQuickWaterMl(amount);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('+$amount ml'),
      action: SnackBarAction(
        label: l10n.undo,
        onPressed: () => ref.read(fitnessRepositoryProvider).deleteWaterLog(id),
      ),
    ),
  );
}

Future<int?> _promptAmount(BuildContext context) async {
  final l10n = context.l10n;
  final ctrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: Text(l10n.addWater),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(suffixText: 'ml'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.save),
            ),
          ],
        ),
  );
  if (ok != true) return null;
  return int.tryParse(ctrl.text.trim());
}

Future<void> _addNote(BuildContext context, WidgetRef ref) async {
  await showNoteEditor(context);
}

Future<void> _startWorkout(BuildContext context, WidgetRef ref) {
  return startQuickWorkout(context, ref);
}

Future<void> _completeHabit(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _HabitQuickSheet(),
  );
}

class _HabitQuickSheet extends ConsumerWidget {
  const _HabitQuickSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final habits = ref.watch(activeHabitsProvider);
    final completions = ref.watch(weekHabitCompletionsProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: habits.when(
          loading:
              () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
          error:
              (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.errorTitle),
              ),
          data: (list) {
            if (list.isEmpty) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.emptyHabits),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      showHabitEditor(context);
                    },
                    icon: const Icon(Icons.add),
                    label: Text(l10n.habits),
                  ),
                ],
              );
            }
            final today = _today();
            final done = <int>{
              for (final c in completions.valueOrNull ?? const [])
                if (_sameDay(c.day, today)) c.habitId,
            };
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.habitChecklist,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final habit in list)
                        CheckboxListTile(
                          value: done.contains(habit.id),
                          title: Text(habit.name),
                          onChanged:
                              (value) => ref
                                  .read(habitRepositoryProvider)
                                  .setCompleted(
                                    habit.id,
                                    today,
                                    completed: value ?? false,
                                  ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
