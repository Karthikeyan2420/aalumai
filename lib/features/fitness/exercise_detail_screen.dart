import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';
import 'data/fitness_repository.dart';
import 'domain/exercise_collections.dart';
import 'domain/exercise_format.dart';
import 'widgets/exercise_art.dart';
import 'widgets/exercise_gif.dart';

/// A full detail page for a single exercise: the animated demonstration, the
/// muscles it targets, the equipment it needs, the default prescription and the
/// dataset's own step-by-step instructions.
///
/// Nothing here is invented: instructions and muscles come from the dataset,
/// sets and reps are AALUMAI's own starting prescription, and the difficulty
/// chip is simply hidden when the dataset publishes none.
class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({super.key, required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final color = exerciseCategoryColor(exercise.category);
    final demoSize = (MediaQuery.sizeOf(context).width * 0.62).clamp(
      180.0,
      300.0,
    );
    return Scaffold(
      appBar: AppBar(title: Text(exercise.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: ExerciseGif(
              gifUrl: exercise.gifUrl,
              category: exercise.category,
              size: demoSize,
              borderRadius: 24,
              timed: exercise.isTimed,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            exercise.name,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(
                icon: Icons.sports_gymnastics,
                label: exerciseTypeLabel(l10n, exercise.exerciseType),
                color: color,
              ),
              if (exercise.equipment.isNotEmpty)
                _Chip(
                  icon: Icons.fitness_center,
                  label: equipmentLabel(exercise.equipment),
                  color: color,
                ),
              if (hasKnownDifficulty(exercise.difficulty))
                _Chip(
                  icon: Icons.signal_cellular_alt,
                  label: exerciseDifficultyLabel(l10n, exercise.difficulty),
                  color: color,
                ),
            ],
          ),
          const SizedBox(height: 20),
          _Section(
            title: l10n.targetMuscles,
            child: Text(
              exercise.targetMuscles.isEmpty
                  ? l10n.none
                  : exercise.targetMuscles,
              style: _bodyStyle(theme),
            ),
          ),
          _Section(
            title: '${l10n.sets} · ${l10n.reps}',
            child: Text(
              exercisePrescription(
                l10n: l10n,
                sets: exercise.defaultSets,
                reps: exercise.defaultReps,
                durationSec: exercise.defaultDurationSec,
              ),
              style: _bodyStyle(theme),
            ),
          ),
          _PersonalBests(exerciseId: exercise.id),
          _Section(
            title: l10n.howTo,
            child: _Instructions(
              text: exercise.instructions,
              emptyLabel: l10n.none,
            ),
          ),
          if (exercise.formTips.isNotEmpty)
            _Section(
              title: l10n.formTips,
              child: Text(exercise.formTips, style: _bodyStyle(theme)),
            ),
          if (exercise.commonMistakes.isNotEmpty)
            _Section(
              title: l10n.commonMistakes,
              child: Text(exercise.commonMistakes, style: _bodyStyle(theme)),
            ),
          if (exercise.safetyNotes.isNotEmpty)
            _Section(
              title: l10n.safetyNotes,
              child: Text(
                exercise.safetyNotes,
                style: _bodyStyle(
                  theme,
                ).copyWith(color: theme.colorScheme.error),
              ),
            ),
          if (exercise.contraindications.isNotEmpty)
            _Section(
              title: l10n.contraindications,
              child: Text(
                exercise.contraindications,
                style: _bodyStyle(
                  theme,
                ).copyWith(color: theme.colorScheme.error),
              ),
            ),
          _Section(
            title: l10n.safetyNotes,
            child: Text(l10n.safetyGuidanceBody, style: _bodyStyle(theme)),
          ),
        ],
      ),
    );
  }
}

TextStyle _bodyStyle(ThemeData theme) {
  return (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
    color: theme.colorScheme.onSurfaceVariant,
    height: 1.45,
  );
}

/// The dataset's instructions, one numbered step per line.
class _PersonalBests extends ConsumerWidget {
  const _PersonalBests({required this.exerciseId});

  final int exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final records = ref.watch(exerciseRecordsProvider(exerciseId));
    return records.maybeWhen(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        String? line(
          PersonalRecordKind kind,
          String Function(int value) format,
        ) {
          final values = [
            for (final record in list)
              if (record.recordType == kind.index) record.value,
          ];
          if (values.isEmpty) return null;
          final best = values.reduce((a, b) => a > b ? a : b);
          return format(best);
        }

        final lines =
            [
              line(
                PersonalRecordKind.weightGrams,
                (value) => '${(value / 1000).toStringAsFixed(1)} kg',
              ),
              line(PersonalRecordKind.reps, (value) => '$value ${l10n.reps}'),
              line(PersonalRecordKind.durationSec, (value) => '${value}s'),
            ].whereType<String>();
        if (lines.isEmpty) return const SizedBox.shrink();
        return _Section(
          title: l10n.personalBest,
          child: Text(lines.join('\n'), style: _bodyStyle(Theme.of(context))),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _Instructions extends StatelessWidget {
  const _Instructions({required this.text, required this.emptyLabel});

  final String text;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = _bodyStyle(theme);
    final steps = [
      for (final line in text.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
    if (steps.isEmpty) return Text(emptyLabel, style: style);
    if (steps.length == 1) return Text(steps.first, style: style);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 26,
                  child: Text(
                    '${i + 1}.',
                    style: style.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(child: Text(steps[i], style: style)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
