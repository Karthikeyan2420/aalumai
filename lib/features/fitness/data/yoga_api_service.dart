import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/yoga.dart';

/// Raised when the yoga API cannot be reached or returns something unexpected.
class YogaApiException implements Exception {
  const YogaApiException(this.message);

  final String message;

  @override
  String toString() => 'YogaApiException: $message';
}

/// Thin client for the public yoga API
/// (`https://yoga-api-nzy4.onrender.com/v1`).
///
/// Only the endpoints the app needs are wrapped. The client is injectable so
/// tests can supply a stub instead of hitting the network.
class YogaApiService {
  YogaApiService({
    http.Client? client,
    this.baseUrl = defaultBaseUrl,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client();

  static const defaultBaseUrl = 'https://yoga-api-nzy4.onrender.com/v1';

  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  /// Fetches every pose the API publishes.
  ///
  /// `/v1/poses` returns a bare JSON array. `/v1/poses?level=` returns an
  /// object with a `poses` array, which is handled too in case the endpoint
  /// changes shape.
  Future<List<YogaPose>> fetchPoses() async {
    final decoded = await _getJson('/poses');
    final rows = switch (decoded) {
      List<Object?> list => list,
      Map<String, Object?> map when map['poses'] is List =>
        map['poses'] as List<Object?>,
      _ => throw const YogaApiException('Unexpected /poses payload'),
    };
    final poses = <YogaPose>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final pose = YogaPose.fromApiJson(row.cast<String, dynamic>());
      if (pose != null) poses.add(pose);
    }
    return List.unmodifiable(poses);
  }

  Future<Object?> _getJson(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(timeout);
    } on Exception catch (error) {
      throw YogaApiException('Request to $uri failed: $error');
    }
    if (response.statusCode != 200) {
      throw YogaApiException('$uri returned HTTP ${response.statusCode}');
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (error) {
      throw YogaApiException('$uri returned invalid JSON: $error');
    }
  }

  void dispose() => _client.close();
}
