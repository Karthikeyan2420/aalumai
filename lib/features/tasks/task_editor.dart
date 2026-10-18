import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/utils/recurrence.dart';
import 'data/task_repository.dart';

Future<void> showTaskEditor(BuildContext context, {Task? task, int? parentId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _TaskEditor(task: task, parentId: parentId),
        ),
  );
}

class _TaskEditor extends ConsumerStatefulWidget {
  const _TaskEditor({this.task, this.parentId});
  final Task? task;
  final int? parentId;

  @override
  ConsumerState<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends ConsumerState<_TaskEditor> {
  late final TextEditingController _title = TextEditingController(
    text: widget.task?.title ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.task?.notes ?? '',
  );
  DateTime? _due;
  int _minuteOfDay = -1;
  DateTime? _reminder;
  late TaskPriority _priority = TaskPriority.fromIndex(
    widget.task?.priority ?? 1,
  );
  late Recurrence _recurrence = Recurrence.parse(widget.task?.recurrenceRule);
  List<Task> _subtasks = [];

  @override
  void initState() {
    super.initState();
    _due = widget.task?.dueDate;
    _minuteOfDay = widget.task?.dueMinuteOfDay ?? -1;
    _reminder = widget.task?.reminderAt;
    if (widget.task != null) _loadSubtasks();
  }

  Future<void> _loadSubtasks() async {
    final subs = await ref
        .read(taskRepositoryProvider)
        .subtasksOf(widget.task!.id);
    if (mounted) setState(() => _subtasks = subs);
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final repo = ref.read(taskRepositoryProvider);
    if (widget.task == null) {
      await repo.create(
        title: title,
        notes: _notes.text.trim(),
        dueDate: _due,
        dueMinuteOfDay: _minuteOfDay,
        priority: _priority,
        parentId: widget.parentId,
        recurrence: _recurrence,
        reminderAt: _reminder,
      );
    } else {
      await repo.updateTask(
        widget.task!.copyWith(
          title: title,
          notes: _notes.text.trim(),
          dueDate: Value(_due),
          dueMinuteOfDay: _minuteOfDay,
          priority: _priority.index,
          recurrenceRule: _recurrence.encode(),
          reminderAt: Value(_reminder),
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.task == null ? l10n.newTask : l10n.edit,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.title,
              hintText: l10n.taskTitleHint,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: InputDecoration(labelText: l10n.notes),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text(l10n.priority)),
              SegmentedButton<TaskPriority>(
                segments: [
                  ButtonSegment(
                    value: TaskPriority.low,
                    label: Text(l10n.priorityLow),
                  ),
                  ButtonSegment(
                    value: TaskPriority.medium,
                    label: Text(l10n.priorityMedium),
                  ),
                  ButtonSegment(
                    value: TaskPriority.high,
                    label: Text(l10n.priorityHigh),
                  ),
                ],
                selected: {_priority},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _priority = s.first),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(l10n.taskDue),
            subtitle: Text(
              _due == null
                  ? l10n.none
                  : '${MaterialLocalizations.of(context).formatMediumDate(_due!)}${_minuteOfDay >= 0 ? ' · ${TimeOfDay(hour: _minuteOfDay ~/ 60, minute: _minuteOfDay % 60).format(context)}' : ''}',
            ),
            trailing:
                _due == null
                    ? null
                    : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed:
                          () => setState(() {
                            _due = null;
                            _minuteOfDay = -1;
                          }),
                    ),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _due ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (date == null) return;
              if (!context.mounted) return;
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              setState(() {
                _due = date;
                _minuteOfDay = time == null ? -1 : time.hour * 60 + time.minute;
              });
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_none),
            title: Text(l10n.reminder),
            subtitle: Text(
              _reminder == null
                  ? l10n.none
                  : '${MaterialLocalizations.of(context).formatMediumDate(_reminder!)} · ${TimeOfDay.fromDateTime(_reminder!).format(context)}',
            ),
            trailing:
                _reminder == null
                    ? null
                    : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _reminder = null),
                    ),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _reminder ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (date == null) return;
              if (!context.mounted) return;
              final time = await showTimePicker(
                context: context,
                initialTime:
                    _reminder == null
                        ? TimeOfDay.now()
                        : TimeOfDay.fromDateTime(_reminder!),
              );
              if (time == null) return;
              setState(() {
                _reminder = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
              });
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.repeat),
            title: Text(l10n.repeat),
            subtitle: Text(_recurrenceLabel(context, _recurrence)),
            onTap: () async {
              final chosen = await _pickRecurrence(context, _recurrence);
              if (chosen != null) setState(() => _recurrence = chosen);
            },
          ),
          if (widget.task != null) ...[
            const Divider(),
            Text(l10n.subtasks, style: Theme.of(context).textTheme.titleMedium),
            for (final sub in _subtasks)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: IconButton(
                  icon: Icon(
                    sub.isCompleted
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                  ),
                  onPressed: () async {
                    await ref
                        .read(taskRepositoryProvider)
                        .setCompleted(sub, !sub.isCompleted);
                    _loadSubtasks();
                  },
                ),
                title: Text(sub.title),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () async {
                    await ref.read(taskRepositoryProvider).delete(sub.id);
                    _loadSubtasks();
                  },
                ),
              ),
            TextButton.icon(
              onPressed: () async {
                await showTaskEditor(context, parentId: widget.task!.id);
                if (mounted) await _loadSubtasks();
              },
              icon: const Icon(Icons.add),
              label: Text(l10n.add),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(onPressed: _save, child: Text(l10n.save)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _recurrenceLabel(BuildContext context, Recurrence r) {
  final l10n = context.l10n;
  return switch (r.frequency) {
    RecurrenceFrequency.none => l10n.none,
    RecurrenceFrequency.daily => l10n.everyDay,
    RecurrenceFrequency.weekly => '${l10n.repeat} · 7d',
    RecurrenceFrequency.monthly => '${l10n.repeat} · 30d',
    RecurrenceFrequency.yearly => '${l10n.repeat} · 365d',
  };
}

Future<Recurrence?> _pickRecurrence(
  BuildContext context,
  Recurrence current,
) async {
  final options = <Recurrence>[
    Recurrence.none,
    const Recurrence(frequency: RecurrenceFrequency.daily),
    const Recurrence(frequency: RecurrenceFrequency.weekly),
    const Recurrence(frequency: RecurrenceFrequency.monthly),
    const Recurrence(frequency: RecurrenceFrequency.yearly),
  ];
  return showModalBottomSheet<Recurrence>(
    context: context,
    builder:
        (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final r in options)
                ListTile(
                  title: Text(_recurrenceLabel(context, r)),
                  trailing:
                      r.frequency == current.frequency
                          ? const Icon(Icons.check)
                          : null,
                  onTap: () => Navigator.pop(context, r),
                ),
            ],
          ),
        ),
  );
}
