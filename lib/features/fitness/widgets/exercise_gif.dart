import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'exercise_art.dart';

/// Animated demonstration for a single exercise.
///
/// The GIF is streamed from the dataset's CDN and cached on disk and in memory
/// by `cached_network_image`, so a demonstration is downloaded at most once.
/// While it loads a soft placeholder is shown; if the exercise has no media,
/// or the download fails, the built-in [ExerciseArt] illustration takes over
/// so a tile is never left blank.
class ExerciseGif extends StatelessWidget {
  const ExerciseGif({
    super.key,
    required this.gifUrl,
    required this.category,
    this.size = 56,
    this.borderRadius = 12,
    this.timed = false,
  });

  /// Remote demonstration from the dataset. Empty when none was published.
  final String gifUrl;

  /// Muscle-group index, used to tint the placeholder and the fallback.
  final int category;

  final double size;
  final double borderRadius;
  final bool timed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = ExerciseArt(
      category: category,
      size: size,
      borderRadius: borderRadius,
      timed: timed,
    );
    if (gifUrl.trim().isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: CachedNetworkImage(
          imageUrl: gifUrl.trim(),
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (context, _) => _Placeholder(size: size, scheme: scheme),
          errorWidget: (context, _, __) => fallback,
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.size, required this.scheme});

  final double size;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: SizedBox(
        width: size * 0.28,
        height: size * 0.28,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: scheme.primary.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
