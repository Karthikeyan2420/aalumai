import 'dart:convert';
import 'dart:math' as math;

/// A single recorded location fix on a run/walk route.
class GeoPoint {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
    required this.timestampMs,
  });

  final double latitude;
  final double longitude;
  final int timestampMs;

  Map<String, dynamic> toJson() => {
    'lat': latitude,
    'lng': longitude,
    't': timestampMs,
  };

  static GeoPoint? fromJson(Map<String, dynamic> json) {
    final lat = (json['lat'] as num?)?.toDouble();
    final lng = (json['lng'] as num?)?.toDouble();
    final t = (json['t'] as num?)?.toInt();
    if (lat == null || lng == null || t == null) return null;
    return GeoPoint(latitude: lat, longitude: lng, timestampMs: t);
  }
}

const double _earthRadiusMeters = 6371000;

/// Great-circle distance between two coordinates, in metres.
double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  final dLat = _radians(lat2 - lat1);
  final dLon = _radians(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_radians(lat1)) *
          math.cos(_radians(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return _earthRadiusMeters * c;
}

double _radians(double degrees) => degrees * math.pi / 180;

/// Total metres along [points], skipping jittery fixes closer than [minStepMeters].
double pathDistanceMeters(List<GeoPoint> points, {double minStepMeters = 1}) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1];
    final b = points[i];
    final step = haversineMeters(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
    if (step >= minStepMeters) total += step;
  }
  return total;
}

/// Average pace in seconds per kilometre, or 0 when distance is negligible.
int paceSecondsPerKm(int distanceMeters, int elapsedSeconds) {
  if (distanceMeters <= 0) return 0;
  return (elapsedSeconds / (distanceMeters / 1000)).round();
}

/// Formats metres as `X.XX km`.
String formatDistanceKm(double meters) =>
    '${(meters / 1000).toStringAsFixed(2)} km';

/// Formats a pace (seconds per km) as `m:ss /km`, or `--` when unknown.
String formatPace(int secondsPerKm) {
  if (secondsPerKm <= 0) return '--';
  final minutes = secondsPerKm ~/ 60;
  final seconds = secondsPerKm % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')} /km';
}

/// Decodes a route stored on a run/walk session. Returns an empty list when
/// the payload is missing or is not a list of points.
List<GeoPoint> decodeRoute(String routeJson) {
  if (routeJson.isEmpty) return const [];
  try {
    final raw = jsonDecode(routeJson);
    if (raw is! List) return const [];
    final points = <GeoPoint>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final point = GeoPoint.fromJson(Map<String, dynamic>.from(item));
      if (point != null) points.add(point);
    }
    return points;
  } catch (_) {
    return const [];
  }
}

/// Formats a duration as `h:mm:ss` (or `m:ss` under an hour).
String formatRunDuration(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final mm = minutes.toString().padLeft(hours > 0 ? 2 : 1, '0');
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}
