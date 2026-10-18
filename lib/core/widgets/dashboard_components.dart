import 'package:flutter/material.dart';

import '../theme/module_theme.dart';

/// A rounded surface used by every dashboard card, so radius, border and
/// padding stay consistent across the app.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color:
            borderColor ??
            theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
    );
    final content = Padding(padding: padding, child: child);
    return Material(
      color: color ?? theme.colorScheme.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child:
          onTap == null
              ? content
              : InkWell(
                onTap: onTap,
                child: Semantics(
                  button: true,
                  label: semanticLabel,
                  child: content,
                ),
              ),
    );
  }
}

/// A heading used above a group of dashboard content.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// A colourful, tappable card representing one feature module. Shows a live
/// value/summary line drawn from real app data.
class ModuleCard extends StatelessWidget {
  const ModuleCard({
    super.key,
    required this.module,
    required this.title,
    required this.value,
    this.subtitle,
    this.onTap,
  });

  final DashboardModule module;
  final String title;
  final String value;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = module.accent;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      semanticLabel: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: softTint(context, accent, 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(module.icon, size: 21, color: accent),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A compact stat pill used inside the daily summary / progress strip.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: softTint(context, accent, 0.18),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: accent),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
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

/// A labelled progress bar used in the "today" summary card.
class ProgressRow extends StatelessWidget {
  const ProgressRow({
    super.key,
    required this.icon,
    required this.label,
    required this.valueLabel,
    required this.progress,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String valueLabel;
  final double progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      valueLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0, 1),
                    minHeight: 7,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A responsive, restrained scenic background: a bundled image with a colour
/// fallback and a soft scrim so overlaid widgets keep readable contrast.
class ScenicBackground extends StatelessWidget {
  const ScenicBackground({
    super.key,
    required this.asset,
    required this.child,
    this.overlayColors,
    this.fallbackColor,
  });

  final String asset;
  final Widget child;

  /// Scrim colours drawn over the image. Defaults to the theme surface so the
  /// backdrop stays readable in both light and dark mode.
  final List<Color>? overlayColors;

  /// Colour shown behind the image while it loads / if it is missing. Defaults
  /// to the theme surface.
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final overlays =
        overlayColors ??
        [surface.withValues(alpha: 0.9), surface.withValues(alpha: 0.8)];
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: fallbackColor ?? surface),
        Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: overlays,
              stops: const [0.0, 1.0],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
