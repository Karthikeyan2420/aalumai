/// One online research result, with the attribution the UI must display.
class SearchResult {
  const SearchResult({
    required this.title,
    required this.summary,
    required this.sourceUrl,
    required this.sourceName,
  });

  /// Page/article title.
  final String title;

  /// A concise extract, already trimmed for display and speech.
  final String summary;

  /// Canonical URL the user can open.
  final String sourceUrl;

  /// Human-readable source name for attribution, e.g. "Wikipedia".
  final String sourceName;
}

/// Raised when an online lookup cannot be completed (offline, timeout, HTTP
/// error). The engine turns this into a friendly, honest message.
class WebSearchException implements Exception {
  const WebSearchException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Contract for the online research providers the engine can call.
abstract class WebSearchPort {
  /// Whether the device currently has a usable network connection.
  Future<bool> get isOnline;

  /// Looks up an encyclopedia summary for [query] (Wikipedia REST API).
  Future<SearchResult?> encyclopedia(String query, {String? language});

  /// Fetches a short weather forecast for [latitude],[longitude].
  Future<SearchResult?> weather(double latitude, double longitude);

  /// Returns recent earthquakes from the USGS feed.
  Future<List<SearchResult>> earthquakes({int limit = 3});
}
