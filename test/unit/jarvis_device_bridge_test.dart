import 'package:aalumai/features/jarvis/data/device_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidDeviceBridge.channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'batteryStatus':
              return {'level': 76, 'charging': true};
            case 'openApp':
              return (call.arguments as Map)['package'] == 'com.example.app';
            case 'openSettings':
              return (call.arguments as Map)['page'] != 'nonsense';
            default:
              throw MissingPluginException(call.method);
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidDeviceBridge.channel, null);
  });

  test('batteryStatus parses the platform map', () async {
    const bridge = AndroidDeviceBridge();
    expect(bridge.isAvailable, isTrue);

    final battery = await bridge.batteryStatus();
    expect(battery.level, 76);
    expect(battery.charging, isTrue);
    expect(calls.single.method, 'batteryStatus');
  });

  test('batteryStatus without a live handler fails honestly', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidDeviceBridge.channel, null);
    const bridge = AndroidDeviceBridge();
    await expectLater(bridge.batteryStatus(), throwsA(isA<UnsupportedError>()));
  });

  test('openApp forwards the package and passes the answer through', () async {
    const bridge = AndroidDeviceBridge();
    expect(await bridge.openApp('com.example.app'), isTrue);
    expect(await bridge.openApp('com.missing.app'), isFalse);
    expect(calls, hasLength(2));
    expect(calls.first.arguments, {'package': 'com.example.app'});
  });

  test('openSettings forwards the page and passes the answer through',
      () async {
    const bridge = AndroidDeviceBridge();
    expect(await bridge.openSettings('notifications'), isTrue);
    expect(await bridge.openSettings('nonsense'), isFalse);
    expect(calls.first.arguments, {'page': 'notifications'});
  });

  test('a platform error degrades to false instead of throwing', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidDeviceBridge.channel, (call) async {
          throw PlatformException(code: 'nope');
        });
    const bridge = AndroidDeviceBridge();
    expect(await bridge.openApp('com.example.app'), isFalse);
    expect(await bridge.openSettings('wifi'), isFalse);
  });
}
