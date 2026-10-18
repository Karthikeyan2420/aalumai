import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/db/database.dart';
import '../../core/localization/generated/app_localizations.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/widgets/common.dart';
import 'data/fitness_repository.dart';
import 'domain/exercise_format.dart';
import 'domain/session_flow.dart';
import 'domain/weekly_planner.dart';
import 'domain/workout_preferences.dart';
import 'workout_player_screen.dart';
import 'workout_preferences_screen.dart';

/// A Mon–Sun weekly planner. Users can generate a week from their
/// preferences, add sessions, reorder, move, duplicate, skip and remove days,
/// and browse past and future weeks. Warnings are advisory and never block.
class WeeklyPlannerScreen extends ConsumerStatefulWidget {
  const WeeklyPlannerScreen({super.key, this.initialWeek});

  final DateTime? initialWeek;

  @override
  ConsumerState<WeeklyPlannerScreen> createState() =>
      _WeeklyPlannerScreenState();
}

class _WeeklyPlannerScreenState extends ConsumerState<WeeklyPlannerScreen> {
  late DateTime _weekStart = WeekDates.startOfWeek(
    widget.initialWeek ?? DateTime.now(),
  );

  void _shift(int weeks) =>
      setState(() => _weekStart = WeekDates.shiftWeeks(_weekStart, weeks));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(scheduleWeekProvider(_weekStart));
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.weeklyPlanner),
        actions: [
          IconButton(
            tooltip: l10n.workoutPreferences,
            icon: const Icon(Icons.tune),
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WorkoutPreferencesScreen(),
                  ),
                ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') _confirmClear(l10n);
            },
            itemBuilder:
                (_) => [
                  PopupMenuItem(
                    value: 'clear',
                    child: Text(l10n.clearUnstarted),
                  ),
                ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'weeklyPlannerGenerate',
        onPressed: () => _generateWeek(l10n),
        icon: const Icon(Icons.auto_awesome),
        label: Text(l10n.generateWeek),
      ),
      body: async.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (week) {
          final warnings = _warningsFor(week, l10n);
          return Column(
            children: [
              _WeekHeader(
                start: _weekStart,
                onPrevious: () => _shift(-1),
                onNext: () => _shift(1),
                onToday:
                    () => setState(
                      () => _weekStart = WeekDates.startOfWeek(DateTime.now()),
                    ),
              ),
              if (warnings.isNotEmpty) _WarningsBanner(warnings: warnings),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  children: [
                    for (final day in WeekDates.weekOf(_weekStart))
                      _DayCard(
                        date: day,
                        entries:
                            week
                                .where((e) => WeekDates.isSameDay(e.date, day))
                                .toList(),
                        onStart: (entry) => _startEntry(entry, l10n),
                        onAdd: () => _addSession(day, l10n),
                        onEdit: (entry) => _editEntry(entry, l10n),
                        onMove: (entry) => _moveEntry(entry, l10n),
                        onMoveUp: (entry) => _moveWithinDay(entry, week, -1),
                        onMoveDown: (entry) => _moveWithinDay(entry, week, 1),
                        onDuplicate: (entry) => _duplicate(entry, l10n),
                        onSkip:
                            (entry) =>
                                _setStatus(entry, ScheduleStatus.skipped, l10n),
                        onRest:
                            (entry) =>
                                _setStatus(entry, ScheduleStatus.rest, l10n),
                        onRestore:
                            (entry) =>
                                _setStatus(entry, ScheduleStatus.planned, l10n),
                        onDelete: (entry) => _delete(entry, l10n),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _generateWeek(AppLocalizations l10n) async {
    final repo = ref.read(fitnessRepositoryProvider);
    final created = await repo.generateWeek(_weekStart);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.weekGenerated(created))));
  }

  Future<void> _confirmClear(AppLocalizations l10n) async {
    final ok = await confirmDialog(
      context,
      title: l10n.clearUnstarted,
      body: l10n.clearUnstartedBody,
      confirmLabel: l10n.clearUnstarted,
    );
    if (!ok) return;
    await ref.read(fitnessRepositoryProvider).clearPlannedWeek(_weekStart);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.weekCleared)));
  }

  Future<void> _startEntry(WorkoutSchedule entry, AppLocalizations l10n) async {
    final repo = ref.read(fitnessRepositoryProvider);
    final planId = entry.planId;
    if (planId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.emptyWorkoutExercises)));
      return;
    }
    final items = await repo.watchPlanItems(planId).first;
    final exercises = await ref.read(exercisesProvider.future);
    if (!mounted) return;
    final steps = SessionBuilder.buildSession(
      allExercises: exercises,
      items: items,
    );
    if (steps.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.emptyWorkoutExercises)));
      return;
    }
    final title = entry.title.isNotEmpty ? entry.title : _entrySubtitle(entry);
    final outcome = await Navigator.of(context).push<SessionOutcome>(
      MaterialPageRoute<SessionOutcome>(
        builder:
            (_) => WorkoutPlayerScreen(
              title: title,
              steps: steps,
              planId: planId,
              scheduledId: entry.id,
              checkReadiness: true,
            ),
      ),
    );
    if (!mounted) return;
    if (outcome == SessionOutcome.completed ||
        outcome == SessionOutcome.partial) {
      await repo.updateScheduleStatus(entry.id, ScheduleStatus.completed.index);
    } else if (outcome == SessionOutcome.cancelled) {
      await repo.updateScheduleStatus(entry.id, ScheduleStatus.skipped.index);
    }
  }

  Future<void> _addSession(DateTime day, AppLocalizations l10n) async {
    final plans = await ref.read(plansProvider.future);
    if (!mounted) return;
    if (plans.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.noPlansYet)));
      return;
    }
    final chosen = await showModalBottomSheet<WorkoutPlan>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.selectPlan,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final plan in plans)
                ListTile(
                  leading: const Icon(Icons.fitness_center),
                  title: Text(plan.name),
                  onTap: () => Navigator.pop(context, plan),
                ),
            ],
          ),
    );
    if (chosen == null || !mounted) return;
    await ref
        .read(fitnessRepositoryProvider)
        .addScheduleEntry(
          date: day,
          planId: chosen.id,
          title: chosen.name,
          muscleGroups: WorkoutPreferences.decodeInts(chosen.muscleGroups),
        );
  }

  Future<void> _editEntry(WorkoutSchedule entry, AppLocalizations l10n) async {
    final titleCtrl = TextEditingController(text: entry.title);
    final selected = {...WorkoutPreferences.decodeInts(entry.muscleGroups)};
    final saved = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setLocal) => AlertDialog(
                  title: Text(l10n.editSession),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: titleCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.sessionTitle,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(l10n.muscleGroupsLabel),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (var c = 0; c <= 7; c++)
                              FilterChip(
                                label: Text(exerciseCategoryLabel(l10n, c)),
                                selected: selected.contains(c),
                                onSelected:
                                    (v) => setLocal(() {
                                      if (v) {
                                        selected.add(c);
                                      } else {
                                        selected.remove(c);
                                      }
                                    }),
                              ),
                          ],
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
    if (saved != true || !mounted) return;
    await ref
        .read(fitnessRepositoryProvider)
        .updateScheduleMeta(
          entry.id,
          title: titleCtrl.text.trim(),
          muscleGroups: selected.toList()..sort(),
        );
  }

  Future<void> _moveEntry(WorkoutSchedule entry, AppLocalizations l10n) async {
    final days = WeekDates.weekOf(_weekStart);
    final target = await showDialog<DateTime>(
      context: context,
      builder:
          (context) => SimpleDialog(
            title: Text(l10n.moveToDay),
            children: [
              for (final day in days)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, day),
                  child: Text(_dayLabel(context, day)),
                ),
            ],
          ),
    );
    if (target == null || !mounted) return;
    await ref
        .read(fitnessRepositoryProvider)
        .moveScheduleEntry(entry.id, target);
  }

  Future<void> _moveWithinDay(
    WorkoutSchedule entry,
    List<WorkoutSchedule> week,
    int delta,
  ) async {
    final siblings =
        week.where((e) => WeekDates.isSameDay(e.date, entry.date)).toList()
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final index = siblings.indexWhere((e) => e.id == entry.id);
    final swap = index + delta;
    if (index < 0 || swap < 0 || swap >= siblings.length) return;
    final reordered = [...siblings];
    final tmp = reordered[index];
    reordered[index] = reordered[swap];
    reordered[swap] = tmp;
    await ref.read(fitnessRepositoryProvider).reorderScheduleEntries(reordered);
    if (mounted) setState(() {});
  }

  Future<void> _duplicate(WorkoutSchedule entry, AppLocalizations l10n) async {
    await ref.read(fitnessRepositoryProvider).duplicateScheduleEntry(entry.id);
    if (mounted) setState(() {});
  }

  Future<void> _setStatus(
    WorkoutSchedule entry,
    ScheduleStatus status,
    AppLocalizations l10n,
  ) async {
    await ref
        .read(fitnessRepositoryProvider)
        .updateScheduleStatus(entry.id, status.index);
  }

  Future<void> _delete(WorkoutSchedule entry, AppLocalizations l10n) async {
    final ok = await confirmDialog(
      context,
      title: l10n.delete,
      body: l10n.deleteSessionBody,
      confirmLabel: l10n.delete,
    );
    if (!ok) return;
    await ref.read(fitnessRepositoryProvider).deleteScheduleEntry(entry.id);
  }

  List<String> _warningsFor(List<WorkoutSchedule> week, AppLocalizations l10n) {
    final warnings = <String>[];
    var consecutive = 0;
    List<int>? previousGroups;
    for (final day in WeekDates.weekOf(_weekStart)) {
      final entries =
          week.where((e) => WeekDates.isSameDay(e.date, day)).toList();
      final training =
          entries.where((e) => e.status != ScheduleStatus.rest.index).toList();
      if (training.isEmpty) {
        consecutive = 0;
        previousGroups = null;
        continue;
      }
      consecutive++;
      final groups = <int>{
        for (final e in training)
          ...WorkoutPreferences.decodeInts(e.muscleGroups),
      };
      if (previousGroups != null &&
          groups.any(previousGroups.contains) &&
          !warnings.contains(l10n.warningConsecutiveSameMuscle)) {
        warnings.add(l10n.warningConsecutiveSameMuscle);
      }
      previousGroups = groups.toList();
      if (consecutive >= 4 && !warnings.contains(l10n.warningConsecutiveDays)) {
        warnings.add(l10n.warningConsecutiveDays);
      }
    }
    return warnings;
  }

  String _entrySubtitle(WorkoutSchedule entry) {
    final groups = WorkoutPreferences.decodeInts(entry.muscleGroups);
    return groups
        .map((g) => exerciseCategoryLabel(context.l10n, g))
        .join(' · ');
  }

  String _dayLabel(BuildContext context, DateTime day) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.EEEE(locale).format(day);
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({
    required this.start,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final DateTime start;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final end = DateTime(start.year, start.month, start.day + 6);
    final range =
        '${DateFormat.MMMd(locale).format(start)} – ${DateFormat.MMMd(locale).format(end)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
            tooltip: l10n.previous,
          ),
          Expanded(
            child: Center(
              child: Text(
                range,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            tooltip: l10n.next,
          ),
          TextButton(onPressed: onToday, child: Text(l10n.today)),
        ],
      ),
    );
  }
}

class _WarningsBanner extends StatelessWidget {
  const _WarningsBanner({required this.warnings});
  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: theme.colorScheme.tertiary,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.planWarnings,
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final w in warnings)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('• $w', style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.date,
    required this.entries,
    required this.onStart,
    required this.onAdd,
    required this.onEdit,
    required this.onMove,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDuplicate,
    required this.onSkip,
    required this.onRest,
    required this.onRestore,
    required this.onDelete,
  });

  final DateTime date;
  final List<WorkoutSchedule> entries;
  final ValueChanged<WorkoutSchedule> onStart;
  final VoidCallback onAdd;
  final ValueChanged<WorkoutSchedule> onEdit;
  final ValueChanged<WorkoutSchedule> onMove;
  final ValueChanged<WorkoutSchedule> onMoveUp;
  final ValueChanged<WorkoutSchedule> onMoveDown;
  final ValueChanged<WorkoutSchedule> onDuplicate;
  final ValueChanged<WorkoutSchedule> onSkip;
  final ValueChanged<WorkoutSchedule> onRest;
  final ValueChanged<WorkoutSchedule> onRestore;
  final ValueChanged<WorkoutSchedule> onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final isToday = WeekDates.isSameDay(date, DateTime.now());
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  DateFormat.EEEE(locale).format(date),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isToday ? theme.colorScheme.primary : null,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat.MMMd(locale).format(date),
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                IconButton(
                  tooltip: l10n.addSession,
                  icon: const Icon(Icons.add),
                  onPressed: onAdd,
                ),
              ],
            ),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l10n.noSessionsThisWeek,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final entry in entries)
                _EntryTile(
                  entry: entry,
                  onTap:
                      entry.status == ScheduleStatus.planned.index &&
                              entry.planId != null
                          ? () => onStart(entry)
                          : null,
                  onStart: () => onStart(entry),
                  onEdit: () => onEdit(entry),
                  onMove: () => onMove(entry),
                  onMoveUp: () => onMoveUp(entry),
                  onMoveDown: () => onMoveDown(entry),
                  onDuplicate: () => onDuplicate(entry),
                  onSkip: () => onSkip(entry),
                  onRest: () => onRest(entry),
                  onRestore: () => onRestore(entry),
                  onDelete: () => onDelete(entry),
                ),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.onTap,
    required this.onStart,
    required this.onEdit,
    required this.onMove,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDuplicate,
    required this.onSkip,
    required this.onRest,
    required this.onRestore,
    required this.onDelete,
  });

  final WorkoutSchedule entry;
  final VoidCallback? onTap;
  final VoidCallback onStart;
  final VoidCallback onEdit;
  final VoidCallback onMove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDuplicate;
  final VoidCallback onSkip;
  final VoidCallback onRest;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final status = scheduleStatusFromIndex(entry.status);
    final isRest = status == ScheduleStatus.rest;
    final groups = WorkoutPreferences.decodeInts(entry.muscleGroups);
    final title =
        isRest
            ? l10n.restDayLabel
            : (entry.title.isNotEmpty
                ? entry.title
                : groups
                    .map((g) => exerciseCategoryLabel(l10n, g))
                    .join(' · '));
    final done = status == ScheduleStatus.completed;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor:
            done
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          isRest
              ? Icons.self_improvement
              : done
              ? Icons.check
              : Icons.fitness_center,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          decoration:
              status == ScheduleStatus.skipped ||
                      status == ScheduleStatus.missed
                  ? TextDecoration.lineThrough
                  : null,
        ),
      ),
      subtitle: Text(_statusLabel(l10n, status)),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'start':
              onStart();
            case 'edit':
              onEdit();
            case 'move':
              onMove();
            case 'up':
              onMoveUp();
            case 'down':
              onMoveDown();
            case 'duplicate':
              onDuplicate();
            case 'skip':
              onSkip();
            case 'rest':
              onRest();
            case 'restore':
              onRestore();
            case 'delete':
              onDelete();
          }
        },
        itemBuilder:
            (_) => [
              if (entry.planId != null)
                PopupMenuItem(value: 'start', child: Text(l10n.start)),
              PopupMenuItem(value: 'edit', child: Text(l10n.editSession)),
              PopupMenuItem(value: 'move', child: Text(l10n.moveToDay)),
              PopupMenuItem(value: 'up', child: Text(l10n.moveUp)),
              PopupMenuItem(value: 'down', child: Text(l10n.moveDown)),
              PopupMenuItem(value: 'duplicate', child: Text(l10n.duplicate)),
              if (!isRest)
                PopupMenuItem(value: 'rest', child: Text(l10n.markRestDay)),
              if (status != ScheduleStatus.planned)
                PopupMenuItem(value: 'restore', child: Text(l10n.restore)),
              if (!done && !isRest)
                PopupMenuItem(value: 'skip', child: Text(l10n.skip)),
              PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
            ],
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n, ScheduleStatus status) =>
      switch (status) {
        ScheduleStatus.planned => l10n.statusPlanned,
        ScheduleStatus.completed => l10n.statusCompleted,
        ScheduleStatus.skipped => l10n.statusSkipped,
        ScheduleStatus.rest => l10n.restDayLabel,
        ScheduleStatus.missed => l10n.statusMissed,
      };
}
