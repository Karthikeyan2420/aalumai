import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/widgets/common.dart';
import 'data/event_repository.dart';
import 'event_editor.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  DateTime _selected = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final eventsAsync = ref.watch(allEventsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSchedule)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'scheduleAddEvent',
        onPressed: () => showEventEditor(context, initialDate: _selected),
        icon: const Icon(Icons.add),
        label: Text(l10n.add),
      ),
      body: eventsAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (events) {
          final dayStart = DateTime(
            _selected.year,
            _selected.month,
            _selected.day,
          );
          final dayEnd = dayStart.add(const Duration(days: 1));
          final occurrences = EventRepository.expand(
            events,
            dayStart.subtract(const Duration(days: 366)),
            dayEnd.add(const Duration(days: 366)),
          );
          final forDay =
              occurrences
                  .where(
                    (e) =>
                        e.startAt.isBefore(dayEnd) && e.endAt.isAfter(dayStart),
                  )
                  .toList();

          return Column(
            children: [
              CalendarDatePicker(
                initialDate: _selected,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                onDateChanged: (d) => setState(() => _selected = d),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Text(
                      DateFormat.yMMMMEEEEd().format(_selected),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              Expanded(
                child:
                    forDay.isEmpty
                        ? EmptyState(
                          icon: Icons.event_available_outlined,
                          message: l10n.emptyEvents,
                          actionLabel: l10n.add,
                          onAction:
                              () => showEventEditor(
                                context,
                                initialDate: _selected,
                              ),
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                          itemCount: forDay.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final event = forDay[index];
                            return _EventTile(
                              event: event,
                              onTap:
                                  () => showEventEditor(context, event: event),
                              onDelete: () async {
                                final ok = await confirmDialog(
                                  context,
                                  title: l10n.deleteConfirmTitle,
                                  body: l10n.deleteConfirmBody,
                                  confirmLabel: l10n.delete,
                                );
                                if (ok) {
                                  await ref
                                      .read(eventRepositoryProvider)
                                      .delete(event.id);
                                }
                              },
                            );
                          },
                        ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.onTap,
    required this.onDelete,
  });

  final Event event;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeText =
        event.allDay
            ? context.l10n.allDay
            : '${DateFormat.jm().format(event.startAt)} – ${DateFormat.jm().format(event.endAt)}';
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 44,
                decoration: BoxDecoration(
                  color:
                      event.isBirthday
                          ? theme.colorScheme.tertiary
                          : theme.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(timeText, style: theme.textTheme.bodySmall),
                    if (event.location.isNotEmpty)
                      Text(
                        event.location,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
