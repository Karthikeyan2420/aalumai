import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/module_theme.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_scaffold.dart';
import 'data/task_repository.dart';
import 'task_editor.dart';
import '../expenses/item_actions.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  int _filter = 0; // 0 today, 1 upcoming, 2 overdue, 3 completed, 4 all
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final repo = ref.watch(taskRepositoryProvider);
    final tasksAsync = ref.watch(allTasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navTasks),
        backgroundColor: softTint(context, DashboardModule.tasks.accent, 0.08),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'tasksAddTask',
        onPressed: () => showTaskEditor(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.add),
      ),
      body: Column(
        children: [
          ModuleFilterBar(
            labels: [
              l10n.taskDue,
              l10n.taskUpcoming,
              l10n.taskOverdue,
              l10n.taskCompleted,
              l10n.all,
            ],
            selectedIndex: _filter,
            onSelected: (i) => setState(() => _filter = i),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              8,
              AppSpacing.screen,
              0,
            ),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: tasksAsync.when(
              loading: () => const LoadingState(),
              error: (e, _) => ErrorState(message: e.toString()),
              data: (all) {
                final now = DateTime.now();
                final endOfToday = DateTime(
                  now.year,
                  now.month,
                  now.day,
                  23,
                  59,
                  59,
                );
                final startOfToday = DateTime(now.year, now.month, now.day);
                final filtered =
                    all.where((e) {
                      final t = e.task;
                      switch (_filter) {
                        case 0:
                          return !t.isCompleted &&
                              (t.dueDate == null ||
                                  !t.dueDate!.isAfter(endOfToday));
                        case 1:
                          return !t.isCompleted &&
                              (t.dueDate == null ||
                                  t.dueDate!.isAfter(endOfToday));
                        case 2:
                          return !t.isCompleted &&
                              t.dueDate != null &&
                              t.dueDate!.isBefore(startOfToday);
                        case 3:
                          return t.isCompleted;
                        default:
                          return true;
                      }
                    }).where((e) {
                      if (_query.isEmpty) return true;
                      return e.task.title.toLowerCase().contains(_query);
                    }).toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.checklist_rtl,
                    message: all.isEmpty ? l10n.emptyTasks : l10n.emptyTitle,
                    accent: DashboardModule.tasks.accent,
                    actionLabel: l10n.add,
                    onAction: () => showTaskEditor(context),
                  );
                }
                return ReorderableListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    8,
                    AppSpacing.screen,
                    96,
                  ),
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) newIndex--;
                    final ids = filtered.map((e) => e.task.id).toList();
                    final id = ids.removeAt(oldIndex);
                    ids.insert(newIndex, id);
                    await repo.reorderTasks(ids);
                  },
                  children: [
                    for (final entry in filtered)
                      KeyedSubtree(
                        key: ValueKey(entry.task.id),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
                          child: _TaskTile(
                            entry: entry,
                            onToggle: () => _toggle(repo, entry.task),
                            onTap: () => showTaskEditor(context, task: entry.task),
                            onLongPress: () => _menu(context, repo, entry.task),
                            onMore: () => _menu(context, repo, entry.task),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(TaskRepository repo, Task task) async {
    final l10n = context.l10n;
    await repo.setCompleted(task, !task.isCompleted);
    if (!mounted) return;
    if (!task.isCompleted) {
      final id = task.id;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.markComplete),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () async {
              final fresh = await repo.getById(id);
              if (fresh != null) await repo.setCompleted(fresh, false);
            },
          ),
        ),
      );
    }
  }

  Future<void> _menu(
    BuildContext context,
    TaskRepository repo,
    Task task,
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
                    showTaskEditor(context, task: task);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.skip_next_outlined),
                  title: Text(l10n.skip),
                  onTap: () {
                    Navigator.pop(context);
                    repo.skipOccurrence(task);
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
                    if (ok) await repo.delete(task.id);
                  },
                ),
              ],
            ),
          ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.entry,
    required this.onToggle,
    required this.onTap,
    required this.onLongPress,
    required this.onMore,
  });

  final TaskWithSubtasks entry;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = entry.task;
    final priority = TaskPriority.fromIndex(task.priority);
    final priorityColor = switch (priority) {
      TaskPriority.high => theme.colorScheme.error,
      TaskPriority.medium => theme.colorScheme.tertiary,
      TaskPriority.low => theme.colorScheme.outline,
    };
    return ModuleListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      trailing: itemMoreButton(onPressed: onMore),
      leading: SizedBox(
        width: 44,
        height: 44,
        child: IconButton(
          onPressed: onToggle,
          icon: Icon(
            task.isCompleted
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            color:
                task.isCompleted
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              decoration:
                  task.isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: priorityColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _subtitle(context, task),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (entry.subtasks.isNotEmpty) ...[
                Icon(
                  Icons.account_tree_outlined,
                  size: 14,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 2),
                Text(
                  '${entry.completedSubtasks}/${entry.subtasks.length}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (task.recurrenceRule.isNotEmpty) ...[
                const SizedBox(width: 8),
                const Icon(Icons.repeat, size: 14),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _subtitle(BuildContext context, Task task) {
    final l10n = context.l10n;
    if (task.dueDate == null) return l10n.none;
    final date = DateFormat.MMMd().format(task.dueDate!);
    if (task.dueMinuteOfDay >= 0) {
      final t = TimeOfDay(
        hour: task.dueMinuteOfDay ~/ 60,
        minute: task.dueMinuteOfDay % 60,
      );
      return '$date · ${t.format(context)}';
    }
    return date;
  }
}
