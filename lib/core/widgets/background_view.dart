import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../backgrounds/background_config.dart';
import '../backgrounds/background_presets.dart';
import '../backgrounds/background_providers.dart';

/// Renders a [BackgroundConfig] behind [child].
///
/// Image backgrounds are darkened by a scrim so text stays readable on any
/// image; the scrim uses [overlayColor] (defaults to the theme surface) tinted
/// to [BackgroundConfig.dim], never dropping below [minOverlay]. Missing or
/// deleted custom images (or unknown bundle assets) fall back to [fallback],
/// and finally to the theme surface, without throwing.
class BackgroundView extends StatelessWidget {
  const BackgroundView({
    super.key,
    required this.config,
    required this.child,
    this.overlayColor,
    this.fallback,
    this.minOverlay = 0,
  });

  final BackgroundConfig config;
  final Widget child;

  /// Base colour for the readability scrim. Defaults to the theme surface so
  /// text keeps its normal (light/dark) contrast.
  final Color? overlayColor;

  /// Used when the configured image cannot be loaded.
  final BackgroundConfig? fallback;

  /// Lower bound for the image scrim opacity, so text is always legible.
  final double minOverlay;

  /// Key placed on the fallback layer, exposed for tests.
  static const fallbackKey = ValueKey('background-fallback');

  @override
  Widget build(BuildContext context) {
    final overlayBase = overlayColor ?? Theme.of(context).colorScheme.surface;
    final opacity = _overlayOpacity;
    return Stack(
      fit: StackFit.expand,
      children: [
        _layer(context, config),
        if (opacity > 0)
          IgnorePointer(
            child: ColoredBox(color: overlayBase.withValues(alpha: opacity)),
          ),
        child,
      ],
    );
  }

  bool get _rendersImage {
    if (!config.isImage) return false;
    if (config.kind == BackgroundKind.file) {
      final path = config.filePath ?? '';
      return path.isNotEmpty && File(path).existsSync();
    }
    return true;
  }

  double get _overlayOpacity {
    if (!_rendersImage) return 0;
    final effective = config.dim < minOverlay ? minOverlay : config.dim;
    return effective.clamp(0.0, 0.9);
  }

  Widget _layer(BuildContext context, BackgroundConfig cfg) {
    switch (cfg.kind) {
      case BackgroundKind.solid:
        return ColoredBox(color: Color(cfg.color ?? 0xFF000000));
      case BackgroundKind.gradient:
        final colors = cfg.gradientColors.map(Color.new).toList();
        if (colors.length < 2) {
          return ColoredBox(
            color:
                colors.isEmpty
                    ? Theme.of(context).colorScheme.surface
                    : colors.first,
          );
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
          ),
          child: const SizedBox.expand(),
        );
      case BackgroundKind.asset:
        final path = cfg.assetPath ?? '';
        if (path.isEmpty) return _fallbackLayer(context);
        return Image.asset(
          path,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallbackLayer(context),
        );
      case BackgroundKind.file:
        final path = cfg.filePath ?? '';
        // Check synchronously so a deleted/moved custom image falls back to the
        // default immediately instead of flashing an empty background while the
        // (async) image load fails.
        if (path.isEmpty || !File(path).existsSync()) {
          return _fallbackLayer(context);
        }
        return Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallbackLayer(context),
        );
    }
  }

  Widget _fallbackLayer(BuildContext context) {
    final fb = fallback;
    final layer =
        (fb != null && !fb.isImage)
            ? _layer(context, fb)
            : ColoredBox(color: Theme.of(context).colorScheme.surface);
    return KeyedSubtree(key: fallbackKey, child: layer);
  }
}

/// Convenience wrapper that resolves the stored background for [slot] and
/// renders it behind [child]. Used by the Home screen (and ready to wrap the
/// alarm ringing screen).
class CustomBackground extends ConsumerWidget {
  const CustomBackground({
    super.key,
    required this.slot,
    required this.child,
    this.overlayColor,
    this.minOverlay = 0,
  });

  final BackgroundSlot slot;
  final Widget child;
  final Color? overlayColor;
  final double minOverlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = ref.watch(backgroundProviderFor(slot));
    final brightness = Theme.of(context).brightness;
    // The built-in default is brightness-aware; a stored config that still
    // equals the legacy (light) default is treated as "not customised" so dark
    // mode gets the dark wash instead of a washed-out white one.
    final legacyDefault = BackgroundPresets.defaultFor(slot);
    final themedDefault = BackgroundPresets.defaultFor(
      slot,
      brightness: brightness,
    );
    final config = stored == legacyDefault ? themedDefault : stored;
    return BackgroundView(
      config: config,
      fallback: themedDefault,
      overlayColor: overlayColor,
      minOverlay: minOverlay,
      child: child,
    );
  }
}
