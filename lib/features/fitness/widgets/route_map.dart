import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/geo.dart';

/// Draws a recorded run/walk route on a self-contained canvas.
///
/// The app is offline-first, so this deliberately does not fetch map tiles:
/// it renders the recorded GPS track (the live polyline, a start marker and a
/// current-position marker) fitted to the available box. When no fixes have
/// been recorded yet it shows a small hint instead of an empty box.
class RouteMapView extends StatelessWidget {
  const RouteMapView({
    super.key,
    required this.points,
    this.active = false,
    this.emptyHint = 'Waiting for GPS…',
  });

  final List<GeoPoint> points;

  /// Whether a session is currently recording (controls the marker label).
  final bool active;

  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child:
            points.isEmpty
                ? _EmptyMap(hint: emptyHint, scheme: scheme)
                : CustomPaint(
                  painter: _RouteMapPainter(
                    points: points,
                    lineColor: scheme.primary,
                    gridColor: scheme.outlineVariant.withValues(alpha: 0.45),
                    startColor: scheme.tertiary,
                    markerColor: scheme.error,
                  ),
                  child: const SizedBox.expand(),
                ),
      ),
    );
  }
}

class _EmptyMap extends StatelessWidget {
  const _EmptyMap({required this.hint, required this.scheme});

  final String hint;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 40, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Paints the route fitted to the canvas, keeping the true north/ground aspect
/// ratio so the shape of the track is not distorted.
class _RouteMapPainter extends CustomPainter {
  _RouteMapPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
    required this.startColor,
    required this.markerColor,
  });

  final List<GeoPoint> points;
  final Color lineColor;
  final Color gridColor;
  final Color startColor;
  final Color markerColor;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);

    var minLat = points.first.latitude;
    var maxLat = minLat;
    var minLng = points.first.longitude;
    var maxLng = minLng;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    // Longitude degrees shrink with latitude; scale x so the track keeps its
    // real-world proportions.
    final midLat = (minLat + maxLat) / 2;
    final lngScale = math.cos(midLat * math.pi / 180).abs().clamp(0.05, 1.0);

    final spanX = ((maxLng - minLng) * lngScale).abs();
    final spanY = (maxLat - minLat).abs();
    const pad = 20.0;
    final availW = math.max(size.width - pad * 2, 1.0);
    final availH = math.max(size.height - pad * 2, 1.0);

    // A single fix (or a zero-span track) has no meaningful scale.
    final scale =
        (spanX <= 0 && spanY <= 0)
            ? 1.0
            : math.min(
              spanX > 0 ? availW / spanX : double.infinity,
              spanY > 0 ? availH / spanY : double.infinity,
            );

    final drawW = spanX * scale;
    final drawH = spanY * scale;
    final originX = pad + (availW - drawW) / 2;
    final originY = pad + (availH - drawH) / 2;

    Offset project(GeoPoint p) {
      final x = originX + (p.longitude - minLng) * lngScale * scale;
      final y = originY + (maxLat - p.latitude) * scale;
      return Offset(x, y);
    }

    if (points.length >= 2) {
      final shadow =
          Paint()
            ..color = lineColor.withValues(alpha: 0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round;
      final line =
          Paint()
            ..color = lineColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round;

      final path =
          Path()..moveTo(project(points.first).dx, project(points.first).dy);
      for (final p in points.skip(1)) {
        final o = project(p);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, shadow);
      canvas.drawPath(path, line);
    }

    _paintMarker(
      canvas,
      project(points.first),
      startColor,
      6,
      fill: Colors.white,
    );
    _paintMarker(
      canvas,
      project(points.last),
      markerColor,
      7,
      fill: Colors.white,
    );
  }

  void _paintGrid(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = gridColor
          ..strokeWidth = 1;
    const step = 40.0;
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintMarker(
    Canvas canvas,
    Offset center,
    Color color,
    double radius, {
    required Color fill,
  }) {
    canvas.drawCircle(center, radius + 2, Paint()..color = fill);
    canvas.drawCircle(center, radius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.startColor != startColor ||
      oldDelegate.markerColor != markerColor;
}
