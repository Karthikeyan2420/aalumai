import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/utils/recurrence.dart';
import 'data/event_repository.dart';

Future<void> showEventEditor(
  BuildContext context, {
  Event? event,
  DateTime? initialDate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _EventEditor(event: event, initialDate: initialDate),
        ),
  );
}

class _EventEditor extends ConsumerStatefulWidget {
  const _EventEditor({this.event, this.initialDate});
  final Event? event;
  final DateTime? initialDate;

  @override
  ConsumerState<_EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends ConsumerState<_EventEditor> {
  late final TextEditingController _title = TextEditingController(
    text: widget.event?.title ?? '',
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.event?.description ?? '',
  );
  late final TextEditingController _location = TextEditingController(
    text: widget.event?.location ?? '',
  );

  late DateTime _start;
  late DateTime _end;
  late bool _allDay = widget.event?.allDay ?? false;
  late bool _birthday = widget.event?.isBirthday ?? false;
  late final Recurrence _recurrence = Recurrence.parse(
    widget.event?.recurrenceRule,
  );
  int _reminderMinutes = -1;

  @override
  void initState() {
    super.initState();
    final base = widget.event?.startAt ?? widget.initialDate ?? DateTime.now();
    _start =
        widget.event?.startAt ??
        DateTime(base.year, base.month, base.day, 9, 0);
    _end = widget.event?.endAt ?? _start.add(const Duration(hours: 1));
    _reminderMinutes = widget.event?.reminderMinutes ?? -1;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final repo = ref.read(eventRepositoryProvider);
    if (widget.event == null) {
      await repo.create(
        title: title,
        description: _description.text.trim(),
        location: _location.text.trim(),
        startAt: _start,
        endAt: _end,
        allDay: _allDay,
        recurrence: _recurrence,
        reminderMinutes: _reminderMinutes,
        isBirthday: _birthday,
      );
    } else {
      await repo.updateEvent(
        widget.event!.copyWith(
          title: title,
          description: _description.text.trim(),
          location: _location.text.trim(),
          startAt: _start,
          endAt: _end,
          allDay: _allDay,
          recurrenceRule: _recurrence.encode(),
          reminderMinutes: _reminderMinutes,
          isBirthday: _birthday,
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDateTime(bool start) async {
    final initial = start ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    final result = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 0,
      time?.minute ?? 0,
    );
    setState(() {
      if (start) {
        final duration = _end.difference(_start);
        _start = result;
        _end = result.add(
          duration.isNegative ? const Duration(hours: 1) : duration,
        );
      } else {
        _end =
            result.isBefore(_start)
                ? _start.add(const Duration(hours: 1))
                : result;
      }
    });
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
            widget.event == null ? l10n.newEvent : l10n.edit,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.title),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 2,
            decoration: InputDecoration(labelText: l10n.description),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _location,
            decoration: InputDecoration(labelText: l10n.locationLabel),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.allDay),
            value: _allDay,
            onChanged: (v) => setState(() => _allDay = v),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.play_arrow),
            title: Text(l10n.eventStart),
            subtitle: Text(
              '${MaterialLocalizations.of(context).formatMediumDate(_start)} · ${TimeOfDay.fromDateTime(_start).format(context)}',
            ),
            onTap: () => _pickDateTime(true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.stop),
            title: Text(l10n.eventEnd),
            subtitle: Text(
              '${MaterialLocalizations.of(context).formatMediumDate(_end)} · ${TimeOfDay.fromDateTime(_end).format(context)}',
            ),
            onTap: () => _pickDateTime(false),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.birthday),
            value: _birthday,
            onChanged: (v) => setState(() => _birthday = v),
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
