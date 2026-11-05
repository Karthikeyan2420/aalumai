import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/exercise_gif_cache.dart';
import '../data/fitness_media_settings.dart';
import 'exercise_art.dart';

/// Animated demonstration for a single exercise.
class ExerciseGif extends ConsumerWidget {
  const ExerciseGif({
    super.key,
    required this.gifUrl,
    required this.category,
    this.exerciseId,
    this.size = 56,
    this.borderRadius = 12,
    this.timed = false,
    this.expand = false,
  });

  final String gifUrl;
  final int category;
  final int? exerciseId;
  final double size;
  final double borderRadius;
  final bool timed;
  /// When true, fills the parent instead of a fixed square [size].
  final bool expand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = ExerciseArt(
      category: category,
      size: expand ? 120 : size,
      borderRadius: borderRadius,
      timed: timed,
    );
    if (gifUrl.trim().isEmpty) {
      return expand
          ? SizedBox.expand(child: fallback)
          : fallback;
    }

    final child = FutureBuilder<File?>(
      future: ref.read(exerciseGifCacheProvider).localFileForUrl(gifUrl),
      builder: (context, snap) {
        final local = snap.data;
        if (local != null) {
          return Image.file(
            local,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            width: expand ? double.infinity : size,
            height: expand ? double.infinity : size,
          );
        }
        final online = ref.watch(fitnessMediaOnlineProvider);
        if (!online) {
          return fallback;
        }
        return CachedNetworkImage(
          imageUrl: gifUrl.trim(),
          fit: BoxFit.cover,
          width: expand ? double.infinity : size,
          height: expand ? double.infinity : size,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder:
              (context, _) => _Placeholder(
                size: expand ? 120 : size,
                scheme: scheme,
                expand: expand,
              ),
          errorWidget: (context, _, __) => fallback,
        );
      },
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child:
          expand
              ? SizedBox.expand(child: child)
              : SizedBox(width: size, height: size, child: child),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.size,
    required this.scheme,
    this.expand = false,
  });

  final double size;
  final ColorScheme scheme;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: expand ? double.infinity : size,
      height: expand ? double.infinity : size,
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
