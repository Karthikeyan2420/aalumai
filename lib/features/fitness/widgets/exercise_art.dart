import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Category indexes used by the bundled exercise library.
class ExerciseCategory {
  const ExerciseCategory._();
  static const arms = 0;
  static const shoulders = 1;
  static const chest = 2;
  static const back = 3;
  static const legs = 4;
  static const core = 5;
  static const cardio = 6;
  static const yoga = 7;
  static const warmUp = 8;

  static const count = 9;
}

/// Accent colour per muscle group, used to tint the illustration and chips.
Color exerciseCategoryColor(int category) {
  return switch (category.clamp(0, ExerciseCategory.count - 1)) {
    ExerciseCategory.arms => const Color(0xFF5C6BC0),
    ExerciseCategory.shoulders => const Color(0xFF26A69A),
    ExerciseCategory.chest => const Color(0xFFEF5350),
    ExerciseCategory.back => const Color(0xFF8D6E63),
    ExerciseCategory.legs => const Color(0xFF66BB6A),
    ExerciseCategory.core => const Color(0xFFAB47BC),
    ExerciseCategory.cardio => const Color(0xFFFF7043),
    ExerciseCategory.yoga => const Color(0xFF29B6F6),
    _ => const Color(0xFFEC407A),
  };
}

/// An original, consistent illustration for an exercise. It draws a stylised
/// human figure and highlights the trained region, so every exercise has a
/// purposeful image without shipping third-party photographs.
class ExerciseArt extends StatelessWidget {
  const ExerciseArt({
    super.key,
    required this.category,
    this.size = 72,
    this.highlightName = true,
    this.borderRadius = 16,
    this.timed = false,
  });

  final int category;
  final double size;
  final bool highlightName;
  final double borderRadius;
  final bool timed;

  @override
  Widget build(BuildContext context) {
    final color = exerciseCategoryColor(category);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.28),
            scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: CustomPaint(
        painter: _BodyPainter(
          category: category.clamp(0, ExerciseCategory.count - 1),
          accent: color,
          figure: scheme.onSurface.withValues(alpha: 0.72),
          timed: timed,
        ),
      ),
    );
  }
}

class _BodyPainter extends CustomPainter {
  _BodyPainter({
    required this.category,
    required this.accent,
    required this.figure,
    required this.timed,
  });

  final int category;
  final Color accent;
  final Color figure;
  final bool timed;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = w * 0.075;
    final paint =
        Paint()
          ..color = figure
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

    final cx = w / 2;
    final headR = w * 0.085;
    final headY = h * 0.20;

    // Head.
    canvas.drawCircle(
      Offset(cx, headY),
      headR,
      paint..style = PaintingStyle.fill,
    );
    paint.style = PaintingStyle.stroke;

    final neck = Offset(cx, headY + headR);
    final hip = Offset(cx, h * 0.60);
    final shoulderY = h * 0.32;
    final shoulderL = Offset(cx - w * 0.13, shoulderY);
    final shoulderR = Offset(cx + w * 0.13, shoulderY);

    // Torso.
    canvas.drawLine(neck, hip, paint);
    // Arms.
    final handL = Offset(cx - w * 0.24, h * 0.52);
    final handR = Offset(cx + w * 0.24, h * 0.52);
    canvas.drawLine(shoulderL, handL, paint);
    canvas.drawLine(shoulderR, handR, paint);
    // Legs.
    final footL = Offset(cx - w * 0.11, h * 0.84);
    final footR = Offset(cx + w * 0.11, h * 0.84);
    canvas.drawLine(hip, footL, paint);
    canvas.drawLine(hip, footR, paint);
    // Shoulders bar.
    canvas.drawLine(shoulderL, shoulderR, paint);

    // Highlight the trained region.
    final highlight =
        Paint()
          ..color = accent.withValues(alpha: 0.55)
          ..strokeWidth = stroke * 1.5
          ..strokeCap = StrokeCap.round;

    switch (category) {
      case ExerciseCategory.arms:
        canvas.drawLine(shoulderL, handL, highlight);
        canvas.drawLine(shoulderR, handR, highlight);
      case ExerciseCategory.shoulders:
        canvas.drawLine(shoulderL, shoulderR, highlight);
        canvas.drawCircle(
          shoulderL,
          stroke,
          highlight..style = PaintingStyle.fill,
        );
        canvas.drawCircle(shoulderR, stroke, highlight);
        highlight.style = PaintingStyle.stroke;
      case ExerciseCategory.chest:
      case ExerciseCategory.back:
        canvas.drawLine(
          Offset(cx - w * 0.09, h * 0.36),
          Offset(cx + w * 0.09, h * 0.36),
          highlight,
        );
      case ExerciseCategory.core:
        canvas.drawLine(Offset(cx, h * 0.42), Offset(cx, h * 0.56), highlight);
      case ExerciseCategory.legs:
        canvas.drawLine(hip, footL, highlight);
        canvas.drawLine(hip, footR, highlight);
      default:
        // Yoga / cardio / warm-up: a friendly motion ring instead.
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, h * 0.5), radius: w * 0.30),
          -math.pi * 0.75,
          math.pi * 1.5,
          false,
          highlight,
        );
    }

    if (timed) {
      final badge = Paint()..color = accent;
      canvas.drawCircle(Offset(w * 0.80, h * 0.20), w * 0.09, badge);
    }
  }

  @override
  bool shouldRepaint(covariant _BodyPainter old) =>
      old.category != category || old.accent != accent || old.timed != timed;
}
