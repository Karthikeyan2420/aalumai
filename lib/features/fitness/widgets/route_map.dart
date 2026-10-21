import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../domain/geo.dart';

/// Satellite-style map (Esri World Imagery) with the GPS track drawn on top.
///
/// The map is shown even before the first fix when [initialCenter] is set.
/// During an active session, the camera follows the latest point.
class RouteMapView extends StatefulWidget {
  const RouteMapView({
    super.key,
    required this.points,
    this.active = false,
    this.emptyHint = 'Waiting for GPS…',
    this.initialCenter,
    this.initialZoom = 16,
  });

  final List<GeoPoint> points;
  final bool active;
  final String emptyHint;

  /// Where to center the map when [points] is still empty (e.g. current location).
  final LatLng? initialCenter;
  final double initialZoom;

  static const _satelliteTemplate =
      'https://server.arcgisonline.com/ArcGIS/rest/services/'
      'World_Imagery/MapServer/tile/{z}/{y}/{x}';

  @override
  State<RouteMapView> createState() => _RouteMapViewState();
}

class _RouteMapViewState extends State<RouteMapView> {
  final MapController _mapController = MapController();
  GeoPoint? _lastFollowed;

  @override
  void didUpdateWidget(RouteMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.points.isEmpty &&
        widget.initialCenter != null &&
        widget.initialCenter != oldWidget.initialCenter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.move(widget.initialCenter!, widget.initialZoom);
      });
    }
    _maybeFollowLatest();
  }

  void _maybeFollowLatest() {
    if (!widget.active || widget.points.isEmpty) return;
    final latest = widget.points.last;
    if (_lastFollowed?.latitude == latest.latitude &&
        _lastFollowed?.longitude == latest.longitude) {
      return;
    }
    _lastFollowed = latest;
    final target = LatLng(latest.latitude, latest.longitude);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final zoom = _mapController.camera.zoom;
      _mapController.move(target, zoom < 14 ? 16 : zoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final latLngs = [for (final p in widget.points) LatLng(p.latitude, p.longitude)];

    final hasTrack = latLngs.isNotEmpty;
    final center =
        hasTrack
            ? _centerOf(latLngs)
            : (widget.initialCenter ?? const LatLng(20, 0));
    final double zoom =
        hasTrack
            ? _fitZoom(latLngs)
            : (widget.initialCenter != null ? widget.initialZoom : 3.0);

    final showWaitingOverlay = !hasTrack && widget.initialCenter == null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: zoom,
              minZoom: 3,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: RouteMapView._satelliteTemplate,
                userAgentPackageName: 'com.aalumai.aalumai',
                maxNativeZoom: 19,
              ),
              if (latLngs.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: latLngs,
                      color: scheme.primary,
                      strokeWidth: 5,
                    ),
                  ],
                ),
              if (latLngs.isNotEmpty)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: latLngs.first,
                      width: 16,
                      height: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.tertiary,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                    if (latLngs.length > 1)
                      Marker(
                        point: latLngs.last,
                        width: 18,
                        height: 18,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.error,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                showFlutterMapAttribution: false,
                attributions: [
                  TextSourceAttribution(
                    'Esri',
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
          if (showWaitingOverlay)
            ColoredBox(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.85),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.satellite_alt_outlined,
                      size: 40,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        widget.emptyHint,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (!hasTrack)
            Positioned(
              left: 12,
              right: 12,
              bottom: 28,
              child: Material(
                color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.gps_fixed,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.emptyHint,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  LatLng _centerOf(List<LatLng> pts) {
    var minLat = pts.first.latitude;
    var maxLat = minLat;
    var minLng = pts.first.longitude;
    var maxLng = minLng;
    for (final p in pts) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    return LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
  }

  double _fitZoom(List<LatLng> pts) {
    var minLat = pts.first.latitude;
    var maxLat = minLat;
    var minLng = pts.first.longitude;
    var maxLng = minLng;
    for (final p in pts) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    final span = math.max((maxLat - minLat).abs(), (maxLng - minLng).abs());
    if (span < 0.001) return 16;
    if (span < 0.005) return 15;
    if (span < 0.01) return 14;
    if (span < 0.05) return 12;
    if (span < 0.1) return 11;
    if (span < 0.5) return 9;
    if (span < 1.0) return 8;
    return 7;
  }
}
