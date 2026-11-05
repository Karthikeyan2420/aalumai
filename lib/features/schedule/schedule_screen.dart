import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/module_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_scaffold.dart';
import 'data/event_repository.dart';
import 'event_editor.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  DateTime _selected = DateTime.now();
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  DateTime get _dayStart =>
      DateTime(_selected.year, _selected.month, _selected.day);

  DateTime _startOfWeek(DateTime d) =>
      _dayStart.subtract(Duration(days: d.weekday - 1));

  void _shiftDay(int delta) {
    setState(() => _selected = _selected.add(Duration(days: delta)));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selected = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final eventsAsync = ref.watch(allEventsProvider);
    final accent = DashboardModule.schedule.accent;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navSchedule),
        backgroundColor: softTint(context, accent, 0.08),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final q = await showDialog<String>(
                context: context,
                builder:
                    (ctx) {
                      final c = TextEditingController(text: _query);
                      return AlertDialog(
                        title: Text(l10n.searchEvents),
                        content: TextField(
                          controller: c,
                          autofocus: true,
                          decoration: InputDecoration(hintText: l10n.search),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, ''),
                            child: Text(l10n.clear),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, c.text),
                            child: Text(l10n.search),
                          ),
                        ],
                      );
                    },
              );
              if (q != null) setState(() => _query = q.trim().toLowerCase());
            },
          ),
        ],
      ),
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
          final dayStart = _dayStart;
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
                  .where(
                    (e) =>
                        _query.isEmpty ||
                        e.title.toLowerCase().contains(_query),
                  )
                  .toList()
                ..sort((a, b) => a.startAt.compareTo(b.startAt));

          final weekStart = _startOfWeek(_selected);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  12,
                  AppSpacing.screen,
                  8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous day',
                      onPressed: () => _shiftDay(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            DateFormat.yMMMM().format(_selected),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            DateFormat.yMMMMEEEEd().format(_selected),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next day',
                      onPressed: () => _shiftDay(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                    IconButton(
                      tooltip: 'Pick date',
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screen,
                  ),
                  itemCount: 7,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final day = weekStart.add(Duration(days: index));
                    final isSelected =
                        day.year == _selected.year &&
                        day.month == _selected.month &&
                        day.day == _selected.day;
                    final isToday =
                        day.year == DateTime.now().year &&
                        day.month == DateTime.now().month &&
                        day.day == DateTime.now().day;
                    return _WeekDayChip(
                      day: day,
                      selected: isSelected,
                      isToday: isToday,
                      accent: accent,
                      onTap: () => setState(() => _selected = day),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child:
                    forDay.isEmpty
                        ? EmptyState(
                          icon: Icons.event_available_outlined,
                          message: l10n.emptyEvents,
                          accent: accent,
                          actionLabel: l10n.add,
                          onAction:
                              () => showEventEditor(
                                context,
                                initialDate: _selected,
                              ),
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screen,
                            8,
                            AppSpacing.screen,
                            96,
                          ),
                          itemCount: forDay.length,
                          separatorBuilder:
                              (_, __) =>
                                  const SizedBox(height: AppSpacing.cardGap),
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

class _WeekDayChip extends StatelessWidget {
  const _WeekDayChip({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.accent,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool isToday;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg =
        selected
            ? accent.withValues(alpha: 0.18)
            : theme.colorScheme.surface;
    final borderSide =
        isToday && !selected
            ? BorderSide(color: accent, width: 1.5)
            : BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            );
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: borderSide,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat.E().format(day),
                style: theme.textTheme.labelSmall?.copyWith(
                  color:
                      selected
                          ? accent
                          : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${day.day}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: selected ? accent : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
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
    final accent = DashboardModule.schedule.accent;
    final timeText =
        event.allDay
            ? context.l10n.allDay
            : '${DateFormat.jm().format(event.startAt)} – ${DateFormat.jm().format(event.endAt)}';
    return ModuleListTile(
      onTap: onTap,
      leading: Container(
        width: 4,
        height: 44,
        decoration: BoxDecoration(
          color:
              event.isBirthday ? theme.colorScheme.tertiary : accent,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 22),
        onPressed: onDelete,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(timeText, style: theme.textTheme.bodySmall),
          if (event.location.isNotEmpty)
            Text(
              event.location,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
