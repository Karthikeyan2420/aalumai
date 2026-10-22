import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'search_result.dart';

/// [WebSearchPort] backed by free public APIs:
/// - Wikipedia REST for encyclopedia summaries and attribution,
/// - Open-Meteo for weather (no API key),
/// - USGS earthquake GeoJSON feed.
///
/// Responses are cached in memory for [cacheTtl] so repeated questions do
/// not re-hit the network. Every call has a timeout and maps failures to
/// [WebSearchException] rather than inventing data.
class HttpWebSearch implements WebSearchPort {
  HttpWebSearch({http.Client? client, this.cacheTtl = const Duration(minutes: 10)})
    : _client = client ?? http.Client();

  final http.Client _client;
  final Duration cacheTtl;

  /// Set by the engine so attribution can include the app name.
  String userAgent = 'AALUMAI/1.0 (personal assistant)';

  final Map<String, _CacheEntry> _cache = {};

  @override
  Future<bool> get isOnline async {
    // A lightweight connectivity probe; failure means "treat as offline".
    try {
      await _client
          .head(Uri.parse('https://en.wikipedia.org/'))
          .timeout(const Duration(seconds: 4));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<SearchResult?> encyclopedia(String query, {String? language}) async {
    final lang = _wikiLang(language);
    final slug = Uri.encodeComponent(query.trim().replaceAll(' ', '_'));
    final uri = Uri.parse('https://$lang.wikipedia.org/api/rest_v1/page/summary/$slug');
    final json = await _getJson(uri, tag: 'wiki:$lang:$slug');
    if (json == null) return null;
    final extract = (json['extract'] as String?)?.trim();
    final title = (json['title'] as String?)?.trim();
    if (extract == null || extract.isEmpty) return null;
    final contentUrls = json['content_urls'];
    String? pageUrl;
    if (contentUrls is Map) {
      final desktop = contentUrls['desktop'];
      if (desktop is Map && desktop['page'] is String) {
        pageUrl = desktop['page'] as String;
      }
    }
    final url = pageUrl?.trim() ?? 'https://$lang.wikipedia.org/wiki/$slug';
    return SearchResult(
      title: title?.isNotEmpty == true ? title! : query,
      summary: extract,
      sourceUrl: url,
      sourceName: 'Wikipedia',
    );
  }

  @override
  Future<SearchResult?> weather(double latitude, double longitude) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$latitude&longitude=$longitude'
      '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code'
      '&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max'
      '&timezone=auto&forecast_days=1',
    );
    final json = await _getJson(uri, tag: 'weather:$latitude,$longitude');
    if (json == null) return null;
    final current = json['current'] as Map<String, Object?>?;
    if (current == null) return null;
    final temp = (current['temperature_2m'] as num?)?.round();
    final humidity = (current['relative_humidity_2m'] as num?)?.round();
    final wind = (current['wind_speed_10m'] as num?)?.round();
    final code = (current['weather_code'] as num?)?.toInt();
    if (temp == null) return null;

    final daily = json['daily'] as Map<String, Object?>?;
    int? high;
    int? low;
    int? rainChance;
    if (daily != null) {
      high = _firstInt(daily['temperature_2m_max']);
      low = _firstInt(daily['temperature_2m_min']);
      rainChance = _firstInt(daily['precipitation_probability_max']);
    }

    final buffer = StringBuffer('It is currently $temp degrees Celsius');
    buffer.write(' and ${describeWeatherCode(code)}');
    if (high != null && low != null) {
      buffer.write('. Today: high $high, low $low degrees');
    }
    if (rainChance != null) {
      buffer.write(', with a $rainChance percent chance of precipitation');
    }
    if (humidity != null && wind != null) {
      buffer.write('. Humidity $humidity percent, wind $wind kilometres per hour');
    }
    buffer.write('.');

    return SearchResult(
      title: 'Current weather',
      summary: buffer.toString(),
      sourceUrl: 'https://open-meteo.com/',
      sourceName: 'Open-Meteo',
    );
  }

  @override
  Future<List<SearchResult>> earthquakes({int limit = 3}) async {
    final uri = Uri.parse(
      'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/'
      'significant_month.geojson',
    );
    final json = await _getJson(uri, tag: 'quakes');
    if (json == null) return const [];
    final features = (json['features'] as List?) ?? const [];
    final results = <SearchResult>[];
    for (final feature in features.take(limit)) {
      final props = feature['properties'] as Map<String, Object?>?;
      if (props == null) continue;
      final place = (props['place'] as String?)?.trim() ?? 'Unknown location';
      final mag = (props['mag'] as num?)?.toStringAsFixed(1) ?? '?';
      final url = (props['url'] as String?)?.trim();
      results.add(
        SearchResult(
          title: 'Magnitude $mag earthquake near $place',
          summary: 'Magnitude $mag earthquake reported near $place.',
          sourceUrl: url ?? 'https://earthquake.usgs.gov/',
          sourceName: 'USGS',
        ),
      );
    }
    return results;
  }

  // ------------------------------------------------------------------ internals

  Future<Map<String, Object?>?> _getJson(Uri uri, {required String tag}) async {
    final cached = _readCache(tag);
    if (cached != null) return cached;
    try {
      final response = await _client
          .get(uri, headers: {'User-Agent': userAgent, 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 404) return null;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw WebSearchException('The source answered with ${response.statusCode}.');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, Object?>) {
        throw const WebSearchException('Unexpected response from the source.');
      }
      _writeCache(tag, decoded);
      return decoded;
    } on TimeoutException {
      throw const WebSearchException('The lookup timed out. Please try again.');
    } on WebSearchException {
      rethrow;
    } catch (e) {
      debugPrint('WebSearch failed for $tag: $e');
      throw const WebSearchException(
        'I could not reach the internet for that. Check your connection.',
      );
    }
  }

  Map<String, Object?>? _readCache(String tag) {
    final entry = _cache[tag];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.storedAt) > cacheTtl) {
      _cache.remove(tag);
      return null;
    }
    return entry.json;
  }

  void _writeCache(String tag, Map<String, Object?> json) {
    _cache[tag] = _CacheEntry(json, DateTime.now());
  }

  String _wikiLang(String? language) {
    if (language == null || language.isEmpty) return 'en';
    final primary = language.split(RegExp(r'[-_]')).first.toLowerCase();
    return RegExp(r'^[a-z]{2,3}$').hasMatch(primary) ? primary : 'en';
  }

  int? _firstInt(Object? list) {
    if (list is List && list.isNotEmpty) {
      final value = list.first;
      if (value is num) return value.round();
    }
    return null;
  }

  /// Maps WMO weather interpretation codes to a short description.
  String describeWeatherCode(int? code) {
    if (code == null) return 'with an unknown sky';
    if (code == 0) return 'clear';
    if (code <= 3) return 'partly cloudy';
    if (code == 45 || code == 48) return 'foggy';
    if (code >= 51 && code <= 57) return 'drizzling';
    if (code >= 61 && code <= 67) return 'raining';
    if (code >= 71 && code <= 77) return 'snowing';
    if (code >= 80 && code <= 82) return 'showery';
    if (code >= 85 && code <= 86) return 'snow showery';
    if (code >= 95) return 'thundery';
    return 'with an uncertain sky';
  }
}

class _CacheEntry {
  _CacheEntry(this.json, this.storedAt);

  final Map<String, Object?> json;
  final DateTime storedAt;
}
