import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/module_theme.dart';
import '../../../core/widgets/module_scaffold.dart';
import '../data/exercise_gif_cache.dart';
import '../data/fitness_repository.dart';
import '../domain/equipment_filter.dart';
import '../domain/gym_focus.dart';
import '../domain/workout_preferences.dart';
import 'day_workout_screen.dart';
import 'gym_shell_widgets.dart';
import 'gym_theme.dart';

class GymWorkoutTab extends ConsumerStatefulWidget {
  const GymWorkoutTab({super.key});

  @override
  ConsumerState<GymWorkoutTab> createState() => _GymWorkoutTabState();
}

class _GymWorkoutTabState extends ConsumerState<GymWorkoutTab> {
  WorkoutMode _mode = WorkoutMode.dumbbell;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(fitnessRepositoryProvider).seedExercises();
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final prefs = ref.watch(workoutPreferencesProvider).valueOrNull;
    final progress = ref.watch(gifDownloadProgressProvider);
    final order = resolveFocusOrder(
      prefs ?? const WorkoutPreferences(),
      _mode,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            8,
            AppSpacing.screen,
            0,
          ),
          child: ModuleHeader(
            title: 'Workout',
            subtitle: 'Pick a focus area and level',
            module: DashboardModule.fitness,
            trailing:
                progress != null && progress.done < progress.total
                    ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                        value:
                            progress.total == 0
                                ? null
                                : progress.done / progress.total,
                      ),
                    )
                    : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Material(
            color: GymTheme.surfaceHigh(context),
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: _ModeChip(
                      label: 'Dumbbell',
                      selected: _mode == WorkoutMode.dumbbell,
                      onTap:
                          () => setState(() => _mode = WorkoutMode.dumbbell),
                    ),
                  ),
                  Expanded(
                    child: _ModeChip(
                      label: 'Bodyweight',
                      selected: _mode == WorkoutMode.bodyweight,
                      onTap:
                          () => setState(() => _mode = WorkoutMode.bodyweight),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: order.length,
            itemBuilder: (context, index) {
              final focus = order[index];
              return _FocusCard(
                key: ValueKey('${focus.storageKey}_${_mode.name}'),
                focus: focus,
                mode: _mode,
                onTap: () => _openLevels(context, focus),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            onPressed: () => _reorderAreas(context, order),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Adjust the order'),
          ),
        ),
      ],
    );
  }

  Future<void> _openLevels(BuildContext context, GymFocusKey focus) async {
    final accent = Theme.of(context).colorScheme.primary;
    // Ensure catalogue is loaded before building Level 1–3.
    await ref.read(fitnessRepositoryProvider).seedExercises();
    List<Exercise> all = const [];
    try {
      all = await ref.read(exercisesProvider.future);
    } catch (_) {
      all = ref.read(exercisesProvider).valueOrNull ?? const [];
    }
    if (!context.mounted) return;

    final levelCounts = [
      for (var i = 0; i < 3; i++)
        pickFocusExercises(
          all: all,
          focus: focus,
          mode: _mode,
          levelIndex: i,
          count: 10 + i * 2,
        ).length,
    ];

    final level = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final sheetTheme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  focus.title,
                  style: sheetTheme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _mode == WorkoutMode.dumbbell
                      ? 'Dumbbell · choose a level'
                      : 'Bodyweight · choose a level',
                  style: sheetTheme.textTheme.bodyMedium?.copyWith(
                    color: sheetTheme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: levelCounts[i] == 0
                              ? sheetTheme.colorScheme.errorContainer
                              : sheetTheme.colorScheme.outlineVariant,
                        ),
                      ),
                      tileColor: sheetTheme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      leading: CircleAvatar(
                        backgroundColor: accent.withValues(alpha: 0.15),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(
                        'Level ${i + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        levelCounts[i] == 0
                            ? 'No exercises yet'
                            : '${levelCounts[i]} exercises',
                      ),
                      trailing: Icon(Icons.chevron_right, color: accent),
                      onTap:
                          levelCounts[i] == 0
                              ? null
                              : () => Navigator.pop(ctx, i),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (level == null || !context.mounted) return;

    final picked = pickFocusExercises(
      all: all,
      focus: focus,
      mode: _mode,
      levelIndex: level,
      count: 10 + level * 2,
    );
    if (picked.isEmpty || !context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No exercises found. Try Bodyweight or reinstall.'),
        ),
      );
      return;
    }
    final rows = [
      for (final e in picked)
        (
          exercise: e,
          sets: 3,
          reps: e.isTimed ? 0 : (e.defaultReps > 0 ? e.defaultReps : 12),
          durationSec: e.isTimed
              ? (e.defaultDurationSec > 0 ? e.defaultDurationSec : 30)
              : 0,
          restSec: 60,
        ),
    ];
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => DayWorkoutScreen(
              title: '${focus.title} · L${level + 1}',
              exercises: rows,
            ),
      ),
    );
  }

  Future<void> _reorderAreas(
    BuildContext context,
    List<GymFocusKey> order,
  ) async {
    final updated = [...order];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: ReorderableListView(
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = updated.removeAt(oldIndex);
                updated.insert(newIndex, item);
              });
            },
            children: [
              for (final f in updated)
                ListTile(
                  key: ValueKey(f.storageKey),
                  title: Text(f.title),
                  trailing: const Icon(Icons.drag_handle),
                ),
            ],
          ),
        );
      },
    );
    final prefs = ref.read(workoutPreferencesProvider).valueOrNull;
    if (prefs == null) return;
    await ref.read(fitnessRepositoryProvider).savePreferences(
      prefs.copyWith(
        focusAreaOrder: updated.map((e) => e.storageKey).toList(),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: selected ? accent : Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({
    super.key,
    required this.focus,
    required this.mode,
    required this.onTap,
  });

  final GymFocusKey focus;
  final WorkoutMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final asset = focus.coverAsset(mode);
    final frame = focus.coverFrame(mode);
    return Material(
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(16),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Transform.scale(
              scale: frame.scale,
              alignment: frame.alignment,
              child: Image.asset(
                asset,
                fit: BoxFit.cover,
                alignment: frame.alignment,
                errorBuilder: (_, __, ___) => gymCoverFallback(),
              ),
            ),
            // Light gradient only — covers already include text in reference
            // crops; keep our labels readable on top.
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    focus.subtitle(mode == WorkoutMode.dumbbell),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    focus.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        mode == WorkoutMode.dumbbell
                            ? Icons.fitness_center
                            : Icons.block,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        mode == WorkoutMode.dumbbell
                            ? 'Dumbbell'
                            : 'No equipment',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
