import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/module_theme.dart';
import '../../../core/widgets/module_scaffold.dart';
import '../../../core/widgets/motivation_widgets.dart';
import '../../../core/widgets/dashboard_components.dart';
import '../../../core/db/database.dart';
import '../data/fitness_repository.dart';
import '../domain/daily_session_builder.dart';
import '../domain/gym_focus.dart';
import '../domain/onboarding_profile.dart';
import '../domain/workout_preferences.dart';
import '../domain/session_flow.dart';
import '../domain/weekly_planner.dart';
import '../workout_preferences_screen.dart';
import '../run_walk_screen.dart';
import '../yoga_screen.dart';
import 'day_workout_screen.dart';
import 'gym_theme.dart';

class GymDailyTab extends ConsumerWidget {
  const GymDailyTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = Theme.of(context).colorScheme.primary;
    final prefs = ref.watch(workoutPreferencesProvider).valueOrNull ??
        const WorkoutPreferences();
    final water = ref.watch(waterTodayProvider);
    final sessions = ref.watch(workoutSessionsProvider);
    final measurements = ref.watch(measurementsProvider);
    final now = DateTime.now();
    final planAnchor = DateTime(now.year, now.month, 1);
    final dayNum = DailySessionBuilder.dayNumberInPlan(now, planAnchor).clamp(1, 30);
    final snapped = DailySessionBuilder.snapSessionMinutes(prefs.sessionMinutes);
    final weekStart = WeekDates.startOfWeek(now);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        0,
        AppSpacing.screen,
        96,
      ),
      children: [
        ModuleHeader(
          title: 'Daily',
          subtitle: DailySessionBuilder.focusLabel(now.weekday),
          module: DashboardModule.fitness,
          trailing: IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WorkoutPreferencesScreen(),
                  ),
                ),
          ),
        ),
        DayCounter(day: dayNum, total: 30, accent: accent),
        const SizedBox(height: 12),
        MotivationLine(text: DailySessionBuilder.motivationLine(now.weekday)),
        const SizedBox(height: 8),
        StreakBadge(days: _estimateStreak(sessions)),
        const SizedBox(height: 12),
        _DurationChips(
          selected: snapped,
          onSelected: (m) => _setDuration(context, ref, m),
        ),
        const SizedBox(height: 12),
        _TodayWorkoutCard(date: now, dayNum: dayNum),
        const SizedBox(height: 12),
        _WeekStrip(selected: now),
        const SizedBox(height: 12),
        _MetricCard(
          icon: Icons.water_drop,
          iconColor: ModuleAccents.water,
          title: 'Water tracker',
          subtitle: 'Keep you healthy and help you lose weight.',
          actionLabel: 'Log',
          onAction: () => _addWater(context, ref),
          trailing: water.maybeWhen(
            data:
                (logs) => Text(
                  '${logs.fold<int>(0, (a, b) => a + b.amountMl)} ml',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
            orElse: () => null,
          ),
        ),
        _MetricCard(
          icon: Icons.monitor_weight_outlined,
          iconColor: Colors.orange,
          title: 'Weight',
          subtitle: 'Set your goal and witness your progress!',
          actionLabel: 'SET A GOAL',
          onAction: () => _logWeight(context, ref),
          trailing: measurements.maybeWhen(
            data: (m) {
              if (m.isEmpty) return null;
              final w = m.first.weightGrams;
              if (w <= 0) return null;
              return Text(
                '${OnboardingProfile.gramsToKg(w).toStringAsFixed(1)} kg',
                style: const TextStyle(fontWeight: FontWeight.w700),
              );
            },
            orElse: () => null,
          ),
        ),
        _WorkoutMinutesCard(sessions: sessions, weekStart: weekStart),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Yoga'),
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const YogaScreen()),
                  ),
            ),
            ActionChip(
              label: const Text('Run / Walk'),
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RunWalkScreen(),
                    ),
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _addWater(BuildContext context, WidgetRef ref) async {
    final ml = await showDialog<int>(
      context: context,
      builder:
          (ctx) => SimpleDialog(
            title: const Text('Add water'),
            children: [
              for (final v in [200, 250, 300, 500])
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, v),
                  child: Text('$v ml'),
                ),
            ],
          ),
    );
    if (ml == null) return;
    await ref.read(fitnessRepositoryProvider).addWater(ml);
  }

  Future<void> _logWeight(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Log weight (kg)'),
            content: TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save'),
              ),
            ],
          ),
    );
    if (ok != true) return;
    final kg = double.tryParse(ctrl.text.trim());
    if (kg == null || kg <= 0) return;
    await ref.read(fitnessRepositoryProvider).addMeasurement(
      date: DateTime.now(),
      weightGrams: OnboardingProfile.kgToGrams(kg),
    );
  }
}

int _estimateStreak(AsyncValue<List<WorkoutSession>> sessions) {
  return sessions.maybeWhen(
    data: (list) {
      final days = <DateTime>{};
      for (final s in list) {
        if (s.endedAt == null) continue;
        final d = s.startedAt;
        days.add(DateTime(d.year, d.month, d.day));
      }
      var streak = 0;
      var cursor = DateTime.now();
      final today = DateTime(cursor.year, cursor.month, cursor.day);
      cursor = today;
      while (days.contains(cursor)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      }
      return streak;
    },
    orElse: () => 0,
  );
}

Future<void> _setDuration(
  BuildContext context,
  WidgetRef ref,
  int minutes,
) async {
  final repo = ref.read(fitnessRepositoryProvider);
  final prefs =
      ref.read(workoutPreferencesProvider).valueOrNull ??
      const WorkoutPreferences();
  await repo.savePreferences(prefs.copyWith(sessionMinutes: minutes));
  final anchor = DateTime(DateTime.now().year, DateTime.now().month, 1);
  await repo.generateThirtyDayPlan(startDate: anchor);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Workouts set to $minutes min — plan updated')),
    );
  }
}

Future<void> openScheduledDay(
  BuildContext context,
  WidgetRef ref, {
  required int dayNum,
  required DateTime date,
}) async {
  final repo = ref.read(fitnessRepositoryProvider);
  final entries = await repo.watchScheduleForDate(date).first;
  final entry = entries.isNotEmpty ? entries.first : null;
  if (entry?.planId == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Day $dayNum is not ready. Tap Regenerate on the Plan tab.',
          ),
        ),
      );
    }
    return;
  }
  final planId = entry!.planId!;
  final items = await ref.read(planItemsProvider(planId).future);
  final exercises = ref.read(exercisesProvider).valueOrNull ?? const [];
  final byId = {for (final e in exercises) e.id: e};
  final rows = <DayExerciseRow>[];
  for (final item in items) {
    final ex = byId[item.exerciseId];
    if (ex == null) continue;
    rows.add((
      exercise: ex,
      sets: item.sets,
      reps: item.reps,
      durationSec: item.durationSec,
      restSec: item.restSec,
    ));
  }
  if (rows.isEmpty || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder:
          (_) => DayWorkoutScreen(
            title: 'DAY $dayNum',
            exercises: rows,
            planId: planId,
            scheduledId: entry.id,
            motivation: DailySessionBuilder.motivationLine(date.weekday),
          ),
    ),
  );
}

class _DurationChips extends StatelessWidget {
  const _DurationChips({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const options = [30, 60, 90, 120];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Session length (includes 10 min stretch)',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: GymTheme.muted(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final m in options)
              ChoiceChip(
                label: Text('$m min'),
                selected: selected == m,
                selectedColor: GymTheme.accent(context).withValues(alpha: 0.35),
                onSelected: (_) => onSelected(m),
              ),
          ],
        ),
      ],
    );
  }
}

class _TodayWorkoutCard extends ConsumerWidget {
  const _TodayWorkoutCard({required this.date, required this.dayNum});

  final DateTime date;
  final int dayNum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = Theme.of(context).colorScheme.primary;
    final cover = dailyFocusCoverAsset(date.weekday);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Image.asset(
            cover,
            height: 176,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 176,
              color: GymTheme.surfaceHigh(context),
            ),
          ),
          Container(
            height: 176,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.88),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: DayProgressRing(
              day: dayNum,
              total: 30,
              size: 48,
              strokeWidth: 4,
              accent: accent,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today · ${DailySessionBuilder.focusLabel(date.weekday)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  onPressed:
                      () => openScheduledDay(
                        context,
                        ref,
                        dayNum: dayNum,
                        date: date,
                      ),
                  child: const Text('Start today\'s workout'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GymPlanTab extends ConsumerWidget {
  const GymPlanTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final planAnchor = DateTime(now.year, now.month, 1);
    final today = DateTime(now.year, now.month, now.day);
    final completedDays = ref.watch(workoutSessionsProvider).maybeWhen(
      data: completedWorkoutDays,
      orElse: () => <DateTime>{},
    );
    final days = List.generate(30, (i) {
      return DateTime(planAnchor.year, planAnchor.month, planAnchor.day + i);
    });
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: ModuleHeader(
            title: '30-day plan',
            subtitle: 'Tap a day to open your session',
            module: DashboardModule.fitness,
            trailing: TextButton(
              onPressed: () async {
                await ref.read(fitnessRepositoryProvider).generateThirtyDayPlan(
                  startDate: planAnchor,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Plan refreshed')),
                  );
                }
              },
              child: const Text('Regenerate'),
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final date = days[index];
              final isToday = _sameDay(date, today);
              final past = date.isBefore(today);
              final completed = completedDays.contains(_dateOnly(date));
              return _PlanDayCell(
                dayNum: index + 1,
                today: isToday,
                past: past,
                completed: completed,
                onTap: () => _openDay(context, ref, index + 1, date),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openDay(
    BuildContext context,
    WidgetRef ref,
    int dayNum,
    DateTime date,
  ) async {
    await openScheduledDay(context, ref, dayNum: dayNum, date: date);
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Days the user actually finished a guided workout (completed or partial).
Set<DateTime> completedWorkoutDays(List<WorkoutSession> sessions) {
  final out = <DateTime>{};
  for (final s in sessions) {
    if (s.endedAt == null) continue;
    final outcome = s.outcome;
    if (outcome != SessionOutcome.completed.index &&
        outcome != SessionOutcome.partial.index) {
      continue;
    }
    out.add(_dateOnly(s.startedAt));
  }
  return out;
}

class _PlanDayCell extends StatelessWidget {
  const _PlanDayCell({
    required this.dayNum,
    required this.today,
    required this.past,
    required this.completed,
    required this.onTap,
  });

  final int dayNum;
  final bool today;
  final bool past;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final surface = GymTheme.surfaceHigh(context);
    final bg =
        today
            ? accent
            : completed
            ? accent.withValues(alpha: 0.45)
            : surface;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration:
              today
                  ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent, width: 2),
                  )
                  : null,
          child:
              completed
                  ? Icon(
                    Icons.check_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                  )
                  : Text(
                    '$dayNum',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color:
                          today
                              ? Colors.white
                              : past
                              ? GymTheme.muted(context)
                              : GymTheme.muted(context),
                    ),
                  ),
        ),
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.selected});
  final DateTime selected;

  @override
  Widget build(BuildContext context) {
    const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final start = selected.subtract(Duration(days: selected.weekday % 7));
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 7; i++)
          _DayBubble(
            label: labels[i],
            day: start.add(Duration(days: i)).day,
            selected: _sameDay(start.add(Duration(days: i)), selected),
          ),
      ],
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayBubble extends StatelessWidget {
  const _DayBubble({
    required this.label,
    required this.day,
    required this.selected,
  });

  final String label;
  final int day;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final muted = GymTheme.muted(context);
    return Column(
      children: [
        Text(label, style: TextStyle(color: muted)),
        const SizedBox(height: 4),
        CircleAvatar(
          radius: 18,
          backgroundColor: selected ? accent : GymTheme.surfaceHigh(context),
          child: Text(
            '$day',
            style: TextStyle(
              color: selected ? Colors.white : GymTheme.onSurface(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(height: 4),
                  trailing!,
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: accent,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
      ),
    );
  }
}

class _WorkoutMinutesCard extends StatelessWidget {
  const _WorkoutMinutesCard({required this.sessions, required this.weekStart});

  final AsyncValue<List<WorkoutSession>> sessions;
  final DateTime weekStart;

  @override
  Widget build(BuildContext context) {
    const teal = Color(kGymTeal);
    final mins = sessions.maybeWhen(
      data: (list) {
        final end = weekStart.add(const Duration(days: 7));
        return list
            .where(
              (s) =>
                  s.endedAt != null &&
                  !s.startedAt.isBefore(weekStart) &&
                  s.startedAt.isBefore(end),
            )
            .fold<int>(0, (a, s) => a + s.durationSec ~/ 60);
      },
      orElse: () => 0,
    );
    return Card(
      child: ListTile(
        leading: const Icon(Icons.timer_outlined, color: Colors.orange),
        title: const Text('Workout'),
        subtitle: Text('Weekly average · $mins min'),
        trailing: Text('$mins min', style: const TextStyle(color: teal)),
      ),
    );
  }
}
