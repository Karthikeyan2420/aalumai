import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';
import 'data/habit_repository.dart';
import 'domain/habit_streak.dart';

Future<void> showHabitEditor(BuildContext context, {Habit? habit}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _HabitEditor(habit: habit),
        ),
  );
}

class _HabitEditor extends ConsumerStatefulWidget {
  const _HabitEditor({this.habit});
  final Habit? habit;

  @override
  ConsumerState<_HabitEditor> createState() => _HabitEditorState();
}

class _HabitEditorState extends ConsumerState<_HabitEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.habit?.name ?? '',
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.habit?.note ?? '',
  );
  late final TextEditingController _goal = TextEditingController(
    text:
        (widget.habit?.goalValue ?? 0) == 0
            ? ''
            : widget.habit!.goalValue.toString(),
  );
  late final TextEditingController _unit = TextEditingController(
    text: widget.habit?.unit ?? '',
  );

  late HabitSchedule _schedule = HabitSchedule.fromIndex(
    widget.habit?.scheduleType ?? 0,
  );
  late int _mask = widget.habit?.weekdaysMask ?? 0;
  late int _targetPerWeek = widget.habit?.targetPerWeek ?? 7;
  late bool _measurable = widget.habit?.isMeasurable ?? false;
  int _reminderMinute = -1;

  @override
  void initState() {
    super.initState();
    _reminderMinute = widget.habit?.reminderMinuteOfDay ?? -1;
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    _goal.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final repo = ref.read(habitRepositoryProvider);
    final goal = double.tryParse(_goal.text.trim()) ?? 0;
    if (widget.habit == null) {
      await repo.create(
        name: name,
        note: _note.text.trim(),
        schedule: _schedule,
        weekdaysMask: _mask,
        targetPerWeek: _targetPerWeek,
        isMeasurable: _measurable,
        goalValue: goal,
        unit: _unit.text.trim(),
        reminderMinuteOfDay: _reminderMinute,
      );
    } else {
      await repo.updateHabit(
        widget.habit!.copyWith(
          name: name,
          note: _note.text.trim(),
          scheduleType: _schedule.index,
          weekdaysMask: _mask,
          targetPerWeek: _targetPerWeek,
          isMeasurable: _measurable,
          goalValue: goal,
          unit: _unit.text.trim(),
          reminderMinuteOfDay: _reminderMinute,
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final weekdayLabels = [
      MaterialLocalizations.of(context).narrowWeekdays[1],
      MaterialLocalizations.of(context).narrowWeekdays[2],
      MaterialLocalizations.of(context).narrowWeekdays[3],
      MaterialLocalizations.of(context).narrowWeekdays[4],
      MaterialLocalizations.of(context).narrowWeekdays[5],
      MaterialLocalizations.of(context).narrowWeekdays[6],
      MaterialLocalizations.of(context).narrowWeekdays[0],
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.habit == null ? l10n.add : l10n.edit,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.name),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: InputDecoration(labelText: l10n.notes),
          ),
          const SizedBox(height: 16),
          SegmentedButton<HabitSchedule>(
            segments: [
              ButtonSegment(
                value: HabitSchedule.daily,
                label: Text(l10n.everyDay),
              ),
              ButtonSegment(
                value: HabitSchedule.selectedWeekdays,
                label: Text(l10n.selectedDays),
              ),
              ButtonSegment(
                value: HabitSchedule.weeklyTarget,
                label: Text(l10n.timesPerWeek),
              ),
            ],
            selected: {_schedule},
            onSelectionChanged: (s) => setState(() => _schedule = s.first),
          ),
          if (_schedule == HabitSchedule.selectedWeekdays) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < 7; i++)
                  FilterChip(
                    label: Text(weekdayLabels[i]),
                    selected: (_mask & (1 << i)) != 0,
                    onSelected:
                        (v) => setState(() {
                          if (v) {
                            _mask |= 1 << i;
                          } else {
                            _mask &= ~(1 << i);
                          }
                        }),
                  ),
              ],
            ),
          ],
          if (_schedule == HabitSchedule.weeklyTarget) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text('${l10n.timesPerWeek}: $_targetPerWeek'),
                const Spacer(),
                IconButton(
                  onPressed:
                      _targetPerWeek > 1
                          ? () => setState(() => _targetPerWeek--)
                          : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                IconButton(
                  onPressed:
                      _targetPerWeek < 7
                          ? () => setState(() => _targetPerWeek++)
                          : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.habitGoal),
            value: _measurable,
            onChanged: (v) => setState(() => _measurable = v),
          ),
          if (_measurable)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _goal,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.targetAmount),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _unit,
                    decoration: InputDecoration(labelText: l10n.unit),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.alarm),
            title: Text(l10n.reminder),
            subtitle: Text(
              _reminderMinute < 0
                  ? l10n.none
                  : TimeOfDay(
                    hour: _reminderMinute ~/ 60,
                    minute: _reminderMinute % 60,
                  ).format(context),
            ),
            trailing:
                _reminderMinute < 0
                    ? null
                    : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _reminderMinute = -1),
                    ),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (picked != null) {
                setState(
                  () => _reminderMinute = picked.hour * 60 + picked.minute,
                );
              }
            },
          ),
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
