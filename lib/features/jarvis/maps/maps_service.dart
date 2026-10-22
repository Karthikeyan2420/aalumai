import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// One place returned by a nearby search or geocoding lookup.
class PlaceResult {
  const PlaceResult({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.category = '',
    this.address = '',
  });

  final String name;
  final double latitude;
  final double longitude;

  /// OpenStreetMap category/type, e.g. "restaurant".
  final String category;
  final String address;

  LatLng get latLng => LatLng(latitude, longitude);

  /// Great-circle distance from [from] in metres.
  double distanceFrom(LatLng from) =>
      const Distance().as(LengthUnit.Meter, from, latLng);

  String describeDistanceFrom(LatLng from) {
    final metres = distanceFrom(from);
    if (metres < 1000) return '${metres.round()} m';
    return '${(metres / 1000).toStringAsFixed(1)} km';
  }
}

/// Why a location lookup could not proceed, so the UI can respond precisely.
enum LocationFailure { unavailable, permissionDenied, permissionDeniedForever }

class LocationException implements Exception {
  const LocationException(this.reason);

  final LocationFailure reason;

  String get message => switch (reason) {
    LocationFailure.unavailable =>
      'Location is turned off. Enable it in settings to find nearby places.',
    LocationFailure.permissionDenied =>
      'I need location permission to do that.',
    LocationFailure.permissionDeniedForever =>
      'Location permission is blocked. You can enable it in app settings.',
  };

  @override
  String toString() => message;
}

/// OpenStreetMap-backed maps & places service.
///
/// - Nearby search uses the Overpass API around the user's position.
/// - Forward geocoding uses Nominatim.
/// Both are public services; requests are throttled by a per-instance delay
/// and carry an identifying User-Agent per their usage policies. No bulk
/// download or tile scraping is performed.
class MapsService {
  MapsService({http.Client? client, this.minInterval = const Duration(seconds: 1)})
    : _client = client ?? http.Client();

  final http.Client _client;
  final Duration minInterval;
  String userAgent = 'AALUMAI/1.0 (personal assistant)';

  DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);

  /// Current position, requesting permission if needed.
  Future<Position> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(LocationFailure.unavailable);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(LocationFailure.permissionDeniedForever);
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(LocationFailure.permissionDenied);
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  /// Finds places matching [query] near [around], or near the user when
  /// [around] is null. Returns an empty list when nothing is found.
  Future<List<PlaceResult>> searchNearby(
    String query, {
    LatLng? around,
    int radiusMeters = 3000,
    int limit = 8,
  }) async {
    final centre = around ?? (await currentPosition()).letLatLng;
    await _throttle();
    final category = _categoryFilter(query);
    final body =
        '[out:json][timeout:15];'
        'nwr(around:$radiusMeters,${centre.latitude},${centre.longitude})'
        '$category;out center $limit;';
    final uri = Uri.parse('https://overpass-api.de/api/interpreter');
    try {
      final response = await _client
          .post(uri, headers: {'User-Agent': userAgent}, body: {'data': body})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const LocationException(LocationFailure.unavailable);
      }
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      final elements = (json['elements'] as List?) ?? const [];
      final results = <PlaceResult>[];
      for (final element in elements) {
        final place = _parseElement(element);
        if (place != null) results.add(place);
      }
      results.sort(
        (a, b) =>
            a.distanceFrom(centre).compareTo(b.distanceFrom(centre)),
      );
      return results.take(limit).toList();
    } on LocationException {
      rethrow;
    } catch (e) {
      debugPrint('Overpass search failed: $e');
      throw const LocationException(LocationFailure.unavailable);
    }
  }

  /// Forward-geocodes a place name / address to coordinates.
  Future<PlaceResult?> geocode(String query) async {
    await _throttle();
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeQueryComponent(query)}&format=json&limit=1',
    );
    try {
      final response = await _client
          .get(uri, headers: {'User-Agent': userAgent, 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final list = jsonDecode(utf8.decode(response.bodyBytes)) as List;
      if (list.isEmpty) return null;
      final first = list.first as Map<String, Object?>;
      final lat = double.tryParse('${first['lat']}');
      final lon = double.tryParse('${first['lon']}');
      if (lat == null || lon == null) return null;
      return PlaceResult(
        name: (first['display_name'] as String?) ?? query,
        latitude: lat,
        longitude: lon,
        address: (first['display_name'] as String?) ?? '',
      );
    } catch (e) {
      debugPrint('Nominatim geocode failed: $e');
      return null;
    }
  }

  /// Reverse-geocodes coordinates to a human-readable address.
  Future<String?> reverseGeocode(LatLng point) async {
    await _throttle();
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?lat=${point.latitude}&lon=${point.longitude}&format=json',
    );
    try {
      final response = await _client
          .get(uri, headers: {'User-Agent': userAgent, 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is Map && json['display_name'] is String) {
        return json['display_name'] as String;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _throttle() async {
    final elapsed = DateTime.now().difference(_lastRequest);
    if (elapsed < minInterval) {
      await Future<void>.delayed(minInterval - elapsed);
    }
    _lastRequest = DateTime.now();
  }

  PlaceResult? _parseElement(Object? element) {
    if (element is! Map) return null;
    final tags = element['tags'] as Map?;
    final name = (tags?['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;
    final lat = (element['lat'] as num?)?.toDouble() ??
        ((element['center']?['lat']) as num?)?.toDouble();
    final lon = (element['lon'] as num?)?.toDouble() ??
        ((element['center']?['lon']) as num?)?.toDouble();
    if (lat == null || lon == null) return null;
    final category = (tags?['amenity'] ?? tags?['shop'] ?? tags?['tourism'] ?? '')
        as String? ??
        '';
    final street = (tags?['addr:street'] as String?) ?? '';
    final number = (tags?['addr:housenumber'] as String?) ?? '';
    final address = number.isEmpty
        ? street
        : '$number $street'.trim();
    return PlaceResult(
      name: name,
      latitude: lat,
      longitude: lon,
      category: category,
      address: address,
    );
  }

  /// Maps a free-text query to an Overpass filter. Falls back to name-matching
  /// on any node/way/relation tagged with a matching name.
  String _categoryFilter(String query) {
    final q = query.toLowerCase();
    String amenity(String value) => '["amenity"="$value"]';
    if (q.contains('restaurant') || q.contains('eat') || q.contains('food')) {
      return amenity('restaurant');
    }
    if (q.contains('cafe') || q.contains('coffee')) return amenity('cafe');
    if (q.contains('hospital') || q.contains('clinic')) return amenity('hospital');
    if (q.contains('pharmacy') || q.contains('chemist')) return amenity('pharmacy');
    if (q.contains('atm') || q.contains('bank')) return amenity('bank');
    if (q.contains('fuel') || q.contains('petrol') || q.contains('gas')) {
      return amenity('fuel');
    }
    if (q.contains('hotel')) return '["tourism"="hotel"]';
    if (q.contains('park')) return '["leisure"="park"]';
    if (q.contains('school')) return amenity('school');
    if (q.contains('supermarket') || q.contains('grocery')) {
      return '["shop"="supermarket"]';
    }
    if (q.contains('mall')) return '["shop"="mall"]';
    // Generic: name contains the query (case-insensitive).
    final escaped = q.replaceAll('"', '');
    return '["name"~"$escaped",i]';
  }
}

extension on Position {
  LatLng get letLatLng => LatLng(latitude, longitude);
}
