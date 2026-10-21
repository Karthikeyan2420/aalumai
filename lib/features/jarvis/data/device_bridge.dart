import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'tool_executor.dart';

/// [JarvisDeviceBridge] backed by the `aalumai/jarvis_actions` MethodChannel
/// implemented in `JarvisActionsPlugin.kt`.
///
/// Platform failures degrade honestly: launching/opening answers `false`,
/// battery status throws so the executor's catch-all reports the failure to
/// the model instead of inventing a reading.
class AndroidDeviceBridge implements JarvisDeviceBridge {
  const AndroidDeviceBridge();

  /// Channel name; visible so tests can install a mock handler.
  @visibleForTesting
  static const MethodChannel channel = MethodChannel('aalumai/jarvis_actions');

  @override
  bool get isAvailable => true;

  @override
  Future<({int level, bool charging})> batteryStatus() async {
    try {
      final status =
          await channel.invokeMapMethod<String, Object?>('batteryStatus');
      final level = (status?['level'] as num?)?.toInt();
      if (level == null || level < 0) {
        throw PlatformException(code: 'unavailable');
      }
      return (level: level, charging: status?['charging'] as bool? ?? false);
    } on MissingPluginException {
      throw UnsupportedError('device bridge unavailable');
    }
  }

  @override
  Future<bool> openApp(String package) async {
    try {
      return await channel.invokeMethod<bool>('openApp', {'package': package}) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> openSettings(String page) async {
    try {
      return await channel.invokeMethod<bool>('openSettings', {'page': page}) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
