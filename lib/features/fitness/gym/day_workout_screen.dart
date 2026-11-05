import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../domain/session_flow.dart';
import '../widgets/exercise_gif.dart';
import '../workout_player_screen.dart';
import 'gym_theme.dart';

typedef DayExerciseRow = ({
  Exercise exercise,
  int sets,
  int reps,
  int durationSec,
  int restSec,
});

/// Timeline day list (DAY N) with pinned Start, matching the gym screenshots.
class DayWorkoutScreen extends ConsumerWidget {
  const DayWorkoutScreen({
    super.key,
    required this.title,
    required this.exercises,
    this.planId,
    this.scheduledId,
    this.motivation,
  });

  final String title;
  final List<DayExerciseRow> exercises;
  final int? planId;
  final int? scheduledId;
  final String? motivation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
            onPressed: () => _start(context, ref),
            child: const Text('Start', style: TextStyle(fontSize: 18)),
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: exercises.length + (motivation != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (motivation != null && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                motivation!,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: GymTheme.accent(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }
          final rowIndex = motivation != null ? index - 1 : index;
          final row = exercises[rowIndex];
          final badge = _badgeFor(row);
          return _TimelineTile(
            isFirst: rowIndex == 0,
            isLast: rowIndex == exercises.length - 1,
            title: row.exercise.name,
            badge: badge,
            exercise: row.exercise,
            timed: row.durationSec > 0,
            theme: theme,
            accent: accent,
          );
        },
      ),
    );
  }

  String _badgeFor(DayExerciseRow row) {
    if (row.durationSec > 0) {
      return '${row.sets}× ${_formatDuration(row.durationSec)} · ${row.restSec}s rest';
    }
    return '${row.sets}×${row.reps} · ${row.restSec}s rest';
  }

  String _formatDuration(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final items = [
      for (var i = 0; i < exercises.length; i++)
        WorkoutPlanItem(
          id: i,
          planId: planId ?? 0,
          exerciseId: exercises[i].exercise.id,
          orderIndex: i,
          sets: exercises[i].sets,
          reps: exercises[i].reps,
          durationSec: exercises[i].durationSec,
          restSec: exercises[i].restSec,
        ),
    ];
    final steps = SessionBuilder.buildSession(
      allExercises: exercises.map((e) => e.exercise).toList(),
      items: items,
      warmUpCount: 0,
      coolDownCount: 0,
    );
    if (steps.isEmpty || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => WorkoutPlayerScreen(
              title: title,
              steps: steps,
              planId: planId,
              scheduledId: scheduledId,
              checkReadiness: false,
            ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.isFirst,
    required this.isLast,
    required this.title,
    required this.badge,
    required this.exercise,
    required this.timed,
    required this.theme,
    required this.accent,
  });

  final bool isFirst;
  final bool isLast;
  final String title;
  final String badge;
  final Exercise exercise;
  final bool timed;
  final ThemeData theme;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: CustomPaint(
                      painter: _DashPainter(color: GymTheme.surfaceHigh(context)),
                      size: const Size(2, double.infinity),
                    ),
                  ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                ),
                if (!isLast)
                  Expanded(
                    child: CustomPaint(
                      painter: _DashPainter(color: GymTheme.surfaceHigh(context)),
                      size: const Size(2, double.infinity),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: GymTheme.onSurface(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return ExerciseGif(
                              gifUrl: exercise.gifUrl,
                              category: exercise.category,
                              size: constraints.maxWidth,
                              borderRadius: 16,
                              timed: timed,
                              expand: true,
                            );
                          },
                        ),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const dash = 4.0;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + dash),
        paint,
      );
      y += dash * 2;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
