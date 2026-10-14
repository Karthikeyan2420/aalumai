import 'package:aalumai/features/fitness/domain/geo.dart';
import 'package:flutter_test/flutter_test.dart';

GeoPoint _p(double lat, double lng, [int t = 0]) =>
    GeoPoint(latitude: lat, longitude: lng, timestampMs: t);

void main() {
  group('haversineMeters', () {
    test('is zero for identical points', () {
      expect(haversineMeters(12.0, 77.0, 12.0, 77.0), 0);
    });

    test('approximates one degree of longitude at the equator', () {
      final d = haversineMeters(0, 0, 0, 1);
      expect(d, closeTo(111195, 200));
    });

    test('approximates one degree of latitude', () {
      final d = haversineMeters(0, 0, 1, 0);
      expect(d, closeTo(111195, 200));
    });

    test('is symmetric', () {
      final a = haversineMeters(13.0827, 80.2707, 12.9716, 77.5946);
      final b = haversineMeters(12.9716, 77.5946, 13.0827, 80.2707);
      expect(a, closeTo(b, 0.001));
    });
  });

  group('pathDistanceMeters', () {
    test('sums segments and ignores sub-threshold jitter', () {
      final points = [
        _p(0, 0),
        _p(0, 0.000005), // ~0.55 m jitter, ignored at minStep=1
        _p(0, 0.001), // ~111 m from origin
        _p(0, 0.002), // another ~111 m
      ];
      final d = pathDistanceMeters(points);
      expect(d, closeTo(222.4, 1));
    });

    test('is zero for fewer than two points', () {
      expect(pathDistanceMeters(const []), 0);
      expect(pathDistanceMeters([_p(1, 1)]), 0);
    });
  });

  group('pace', () {
    test('computes seconds per kilometre', () {
      expect(paceSecondsPerKm(1000, 300), 300);
      expect(paceSecondsPerKm(5000, 1500), 300);
    });

    test('is zero when there is no distance', () {
      expect(paceSecondsPerKm(0, 300), 0);
    });
  });

  group('formatting', () {
    test('formats distance in kilometres', () {
      expect(formatDistanceKm(1234), '1.23 km');
      expect(formatDistanceKm(0), '0.00 km');
    });

    test('formats pace', () {
      expect(formatPace(300), '5:00 /km');
      expect(formatPace(65), '1:05 /km');
      expect(formatPace(0), '--');
    });

    test('formats duration', () {
      expect(formatRunDuration(65), '1:05');
      expect(formatRunDuration(3725), '1:02:05');
    });
  });

  group('GeoPoint json', () {
    test('round-trips', () {
      const point = GeoPoint(latitude: 12.5, longitude: 77.25, timestampMs: 99);
      final restored = GeoPoint.fromJson(point.toJson());
      expect(restored!.latitude, 12.5);
      expect(restored.longitude, 77.25);
      expect(restored.timestampMs, 99);
    });

    test('returns null for malformed json', () {
      expect(GeoPoint.fromJson({'lat': 1.0}), isNull);
    });
  });
}
