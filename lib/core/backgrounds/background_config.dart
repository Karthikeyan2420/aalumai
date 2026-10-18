import 'package:flutter/foundation.dart';

/// How a customizable background is drawn behind a screen.
enum BackgroundKind {
  /// A single flat colour.
  solid,

  /// A vertical two-or-more stop gradient.
  gradient,

  /// A bundled image that ships with the app (offline-safe).
  asset,

  /// A user-selected image stored locally on the device.
  file,
}

/// An immutable description of the background used by a screen.
///
/// The configuration is intentionally small and JSON-serialisable so it can be
/// persisted in [SharedPreferences] and validated on read. Only the field(s)
/// relevant to [kind] are populated; [isValid] guards against corrupt or
/// hand-edited values.
@immutable
class BackgroundConfig {
  const BackgroundConfig({
    required this.kind,
    this.color,
    this.gradientColors = const <int>[],
    this.assetPath,
    this.filePath,
    this.dim = 0,
    this.label,
  });

  const BackgroundConfig.solid(int color, {String? label, double dim = 0})
    : this(kind: BackgroundKind.solid, color: color, label: label, dim: dim);

  const BackgroundConfig.gradient(
    List<int> colors, {
    String? label,
    double dim = 0,
  }) : this(
         kind: BackgroundKind.gradient,
         gradientColors: colors,
         label: label,
         dim: dim,
       );

  const BackgroundConfig.asset(String path, {String? label, double dim = 0.3})
    : this(kind: BackgroundKind.asset, assetPath: path, label: label, dim: dim);

  final BackgroundKind kind;

  /// Solid colour as a 32-bit ARGB value.
  final int? color;

  /// Gradient stops as 32-bit ARGB values (top to bottom), at least two.
  final List<int> gradientColors;

  /// Bundled asset path for [BackgroundKind.asset].
  final String? assetPath;

  /// Absolute local file path for [BackgroundKind.file].
  final String? filePath;

  /// Darkening/scrim strength (0..1) applied over image backgrounds so text
  /// stays readable. Ignored for solid and gradient backgrounds.
  final double dim;

  /// Optional human-readable label (e.g. a chosen image file name). Purely
  /// cosmetic; never required for rendering.
  final String? label;

  /// Whether the configuration has everything needed to render.
  bool get isValid => switch (kind) {
    BackgroundKind.solid => color != null,
    BackgroundKind.gradient => gradientColors.length >= 2,
    BackgroundKind.asset => (assetPath ?? '').isNotEmpty,
    BackgroundKind.file => (filePath ?? '').isNotEmpty,
  };

  /// Whether the background is an image (and therefore supports [dim]).
  bool get isImage =>
      kind == BackgroundKind.asset || kind == BackgroundKind.file;

  BackgroundConfig copyWith({
    BackgroundKind? kind,
    int? color,
    List<int>? gradientColors,
    String? assetPath,
    String? filePath,
    double? dim,
    String? label,
  }) {
    return BackgroundConfig(
      kind: kind ?? this.kind,
      color: color ?? this.color,
      gradientColors: gradientColors ?? this.gradientColors,
      assetPath: assetPath ?? this.assetPath,
      filePath: filePath ?? this.filePath,
      dim: dim ?? this.dim,
      label: label ?? this.label,
    );
  }

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    if (color != null) 'color': color,
    if (gradientColors.isNotEmpty) 'gradient': gradientColors,
    if (assetPath != null) 'asset': assetPath,
    if (filePath != null) 'file': filePath,
    if (dim != 0) 'dim': dim,
    if (label != null && label!.isNotEmpty) 'label': label,
  };

  /// Parses a stored configuration. Returns `null` when the value is missing
  /// or does not describe a valid background, so callers can fall back safely.
  static BackgroundConfig? tryParse(Object? value) {
    if (value is! Map) return null;
    final kindName = value['kind'];
    if (kindName is! String) return null;
    BackgroundKind? kind;
    for (final candidate in BackgroundKind.values) {
      if (candidate.name == kindName) {
        kind = candidate;
        break;
      }
    }
    if (kind == null) return null;

    final config = BackgroundConfig(
      kind: kind,
      color: (value['color'] as num?)?.toInt(),
      gradientColors:
          (value['gradient'] as List?)?.whereType<num>().map((e) {
            return e.toInt();
          }).toList() ??
          const <int>[],
      assetPath: value['asset'] as String?,
      filePath: value['file'] as String?,
      dim: ((value['dim'] as num?)?.toDouble() ?? 0).clamp(0, 1).toDouble(),
      label: value['label'] as String?,
    );
    return config.isValid ? config : null;
  }

  @override
  bool operator ==(Object other) {
    return other is BackgroundConfig &&
        other.kind == kind &&
        other.color == color &&
        listEquals(other.gradientColors, gradientColors) &&
        other.assetPath == assetPath &&
        other.filePath == filePath &&
        other.dim == dim &&
        other.label == label;
  }

  @override
  int get hashCode => Object.hash(
    kind,
    color,
    Object.hashAll(gradientColors),
    assetPath,
    filePath,
    dim,
    label,
  );
}
