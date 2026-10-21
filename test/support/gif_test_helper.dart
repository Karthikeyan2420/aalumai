import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 1×1 transparent GIF. Served to CachedNetworkImage in tests so the image
/// loads successfully and flutter_cache_manager does not leave pending retry
/// timers that fail the test invariant check.
final Uint8List _tinyGif = base64Decode(
  'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
);

/// HttpOverrides that returns a tiny valid GIF for every image request,
/// so CachedNetworkImage succeeds in tests without network access.
class _GifHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    return _MockImageClient(client);
  }
}

class _MockImageClient implements HttpClient {
  _MockImageClient(this._inner);
  final HttpClient _inner;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    if (url.host.contains('jsdelivr') ||
        url.host.contains('openstreetmap') ||
        url.host.contains('arcgisonline')) {
      return Future.value(_MockImageRequest());
    }
    return _inner.openUrl(method, url);
  }

  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockImageRequest implements HttpClientRequest {
  /// Response bytes handed back once the request is closed.
  final List<int> _response = _tinyGif.toList();

  /// Headers written to the outgoing request; empty for a plain GET.
  final Map<String, List<String>> _headers = {};

  @override
  HttpHeaders get headers => _MockHeaders(_headers);

  @override
  Future<HttpClientResponse> close() async => _MockImageResponse(_response);

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.drain<void>();
  }

  @override
  Future<HttpClientResponse> get done => close();

  @override
  Future<void> flush() async {}

  @override
  void add(List<int> data) {}

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}

  @override
  dynamic noSuchMethod(Invocation invocation) {}
}

class _MockImageResponse implements HttpClientResponse {
  _MockImageResponse(this._body);
  final List<int> _body;

  /// `content-type` is required: flutter_cache_manager derives the cache file
  /// extension from it, and the image decoder needs a recognisable suffix.
  final Map<String, List<String>> _headers = const {
    'content-type': ['image/gif'],
  };

  @override
  int get statusCode => 200;

  @override
  int get contentLength => _body.length;

  @override
  HttpHeaders get headers => _MockHeaders(_headers);

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => 'OK';

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_body]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) {
    return Stream<List<int>>.fromIterable([_body]).transform(streamTransformer);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {}
}

/// Just enough of `HttpHeaders` for `package:http` to iterate a response.
class _MockHeaders implements HttpHeaders {
  _MockHeaders(this._values);
  final Map<String, List<String>> _values;

  @override
  List<String>? operator [](String name) => _values[name];

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _values.forEach(action);
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name.toLowerCase()] = [value.toString()];
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    (_values[name.toLowerCase()] ??= []).add(value.toString());
  }

  @override
  String? value(String name, {bool preserveHeaderCase = false}) =>
      _values[name]?.join(',');

  @override
  dynamic noSuchMethod(Invocation invocation) {}
}

/// Call this in `setUpAll` (or at the top of `main`) for any test that pumps
/// widgets containing [CachedNetworkImage] or [FlutterMap]. It installs:
/// - A [HttpOverrides] that returns a tiny valid GIF for image requests.
/// - A path_provider mock so flutter_cache_manager can create its cache dir.
/// - A sqflite mock so flutter_cache_manager can open its metadata database.
void setupGifTestEnvironment() {
  TestWidgetsFlutterBinding.ensureInitialized();

  HttpOverrides.global = _GifHttpOverrides();

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async =>
            Directory.systemTemp.createTempSync('aalumai_test').path,
      );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('com.tekartik.sqflite'),
        (call) async {
          if (call.method == 'getDatabasesPath') {
            return Directory.systemTemp.createTempSync('aalumai_sqflite').path;
          }
          if (call.method == 'openDatabase') return 1;
          if (call.method == 'query') return <Map<String, Object?>>[];
          if (call.method == 'insert') return 0;
          if (call.method == 'update' || call.method == 'delete') return 0;
          if (call.method == 'execute') return null;
          if (call.method == 'close') return null;
          return null;
        },
      );
}

/// Call this in `tearDownAll` to restore the default HTTP overrides.
void teardownGifTestEnvironment() {
  HttpOverrides.global = null;
}
