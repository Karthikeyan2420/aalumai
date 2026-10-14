import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/utils/alarm_time.dart';
import '../../core/widgets/common.dart';
import 'data/alarm_repository.dart';

class AlarmsScreen extends ConsumerWidget {
  const AlarmsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final alarms = ref.watch(alarmsProvider);
    final next = ref.watch(nextAlarmProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.alarms)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAlarmEditor(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.newAlarm),
      ),
      body: Column(
        children: [
          if (next.valueOrNull != null)
            Card(
              margin: const EdgeInsets.all(12),
              child: ListTile(
                leading: const Icon(Icons.alarm_on),
                title: Text(l10n.nextAlarm),
                trailing: Text(
                  AlarmTime.format(
                    next.valueOrNull!.hour,
                    next.valueOrNull!.minute,
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          Expanded(
            child: alarms.when(
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
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final a = list[i];
                    return _AlarmTile(alarm: a);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AlarmTile extends ConsumerWidget {
  const _AlarmTile({required this.alarm});
  final Alarm alarm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Card(
      child: ListTile(
        title: Text(
          AlarmTime.format(alarm.hour, alarm.minute),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: alarm.isEnabled ? null : Colors.grey,
          ),
        ),
        subtitle: Text(
          _repeatLabel(context, alarm.repeatDaysMask) +
              (alarm.label.isEmpty ? '' : ' · ${alarm.label}'),
        ),
        trailing: Switch(
          value: alarm.isEnabled,
          onChanged:
              (v) => ref.read(alarmRepositoryProvider).setEnabled(alarm.id, v),
        ),
        onTap: () => showAlarmEditor(context, ref, alarm: alarm),
        onLongPress: () async {
          final ok = await confirmDialog(
            context,
            title: l10n.deleteConfirmTitle,
            body: l10n.deleteConfirmBody,
            confirmLabel: l10n.delete,
          );
          if (ok) await ref.read(alarmRepositoryProvider).delete(alarm.id);
        },
      ),
    );
  }

  String _repeatLabel(BuildContext context, int mask) {
    final l10n = context.l10n;
    if (mask == 0) return l10n.everyDay;
    final days = AlarmTime.weekdays(mask);
    if (days.length == 5 && days.every((d) => d <= 5)) return l10n.selectedDays;
    return days.map(_weekdayShort).join(' ');
  }

  String _weekdayShort(int isoWeekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(isoWeekday - 1) % 7];
  }
}

Future<void> showAlarmEditor(
  BuildContext context,
  WidgetRef ref, {
  Alarm? alarm,
}) async {
  final l10n = context.l10n;
  var hour = alarm?.hour ?? 7;
  var minute = alarm?.minute ?? 0;
  var label = alarm?.label ?? '';
  var mask = alarm?.repeatDaysMask ?? 0;
  var snooze = alarm?.snoozeMinutes ?? 5;
  var vibrate = alarm?.vibrate ?? true;
  var challenge = AlarmChallenge.fromIndex(alarm?.challengeType ?? 0);
  final labelCtrl = TextEditingController(text: label);

  final saved = await showDialog<bool>(
    context: context,
    builder:
        (context) => StatefulBuilder(
          builder:
              (context, setState) => AlertDialog(
                title: Text(alarm == null ? l10n.newAlarm : l10n.alarms),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(hour: hour, minute: minute),
                          );
                          if (picked != null) {
                            setState(() {
                              hour = picked.hour;
                              minute = picked.minute;
                            });
                          }
                        },
                        icon: const Icon(Icons.access_time),
                        label: Text(AlarmTime.format(hour, minute)),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (var i = 0; i < 7; i++)
                            FilterChip(
                              label: Text(
                                const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                              ),
                              selected: (mask & (1 << i)) != 0,
                              onSelected:
                                  (v) => setState(
                                    () =>
                                        mask =
                                            v
                                                ? (mask | (1 << i))
                                                : (mask & ~(1 << i)),
                                  ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: labelCtrl,
                        decoration: InputDecoration(labelText: l10n.alarmLabel),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: snooze,
                        decoration: InputDecoration(labelText: l10n.snooze),
                        items: [
                          for (final s in [0, 5, 10, 15])
                            DropdownMenuItem(value: s, child: Text('$s min')),
                        ],
                        onChanged: (v) => setState(() => snooze = v ?? 5),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<AlarmChallenge>(
                        value: challenge,
                        decoration: InputDecoration(labelText: l10n.challenge),
                        items: [
                          DropdownMenuItem(
                            value: AlarmChallenge.none,
                            child: Text(l10n.challengeNone),
                          ),
                          DropdownMenuItem(
                            value: AlarmChallenge.math,
                            child: Text(l10n.challengeMath),
                          ),
                          DropdownMenuItem(
                            value: AlarmChallenge.memory,
                            child: Text(l10n.challengeMemory),
                          ),
                          DropdownMenuItem(
                            value: AlarmChallenge.code,
                            child: Text(l10n.challengeCode),
                          ),
                        ],
                        onChanged:
                            (v) => setState(() => challenge = v ?? challenge),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Vibrate'),
                        value: vibrate,
                        onChanged: (v) => setState(() => vibrate = v),
                      ),
                    ],
                  ),
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
        ),
  );

  if (saved == true) {
    final repo = ref.read(alarmRepositoryProvider);
    if (alarm == null) {
      await repo.create(
        hour: hour,
        minute: minute,
        label: labelCtrl.text.trim(),
        repeatDaysMask: mask,
        snoozeMinutes: snooze,
        vibrate: vibrate,
        challenge: challenge,
      );
    } else {
      await repo.updateAlarm(
        alarm.copyWith(
          hour: hour,
          minute: minute,
          label: labelCtrl.text.trim(),
          repeatDaysMask: mask,
          snoozeMinutes: snooze,
          vibrate: vibrate,
          challengeType: challenge.index,
        ),
      );
    }
  }
}
