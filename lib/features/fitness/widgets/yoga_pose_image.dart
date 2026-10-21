import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Demonstration image for a single yoga pose.
///
/// The yoga API publishes raster PNGs on a CDN, so `cached_network_image` is
/// used for on-disk caching. When a pose has **no verified image** — which is
/// the honest state for poses the API does not describe — a labelled
/// placeholder is shown instead of borrowing a picture of a different pose.
class YogaPoseImage extends StatelessWidget {
  const YogaPoseImage({
    super.key,
    required this.imageUrl,
    this.size = 120,
    this.borderRadius = 16,
    this.noImageLabel,
  });

  /// Verified demonstration image. Empty when none is available.
  final String imageUrl;

  final double size;
  final double borderRadius;

  /// Caption shown inside the placeholder. Falls back to a generic icon when
  /// null, which is fine for small thumbnails.
  final String? noImageLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (imageUrl.trim().isEmpty) {
      return _Placeholder(
        size: size,
        borderRadius: borderRadius,
        scheme: scheme,
        label: noImageLabel,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: CachedNetworkImage(
            imageUrl: imageUrl.trim(),
            fit: BoxFit.contain,
            fadeInDuration: const Duration(milliseconds: 150),
            placeholder:
                (context, _) =>
                    _Placeholder(size: size, borderRadius: 0, scheme: scheme),
            errorWidget:
                (context, _, __) => _Placeholder(
                  size: size,
                  borderRadius: 0,
                  scheme: scheme,
                  label: noImageLabel,
                ),
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.size,
    required this.borderRadius,
    required this.scheme,
    this.label,
  });

  final double size;
  final double borderRadius;
  final ColorScheme scheme;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.self_improvement,
            size: size * 0.3,
            color: scheme.primary.withValues(alpha: 0.6),
          ),
          if (label != null) ...[
            const SizedBox(height: 8),
            Text(
              label!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
