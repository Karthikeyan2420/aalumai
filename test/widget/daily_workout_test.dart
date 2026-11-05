import 'package:aalumai/features/fitness/domain/geo.dart';
import 'package:aalumai/features/fitness/widgets/route_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/gif_test_helper.dart';

Future<void> _settle(WidgetTester tester, {int rounds = 10}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 60)),
  );
  await tester.pump();
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  setupGifTestEnvironment();

  group('RouteMapView', () {
    Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets('shows satellite map at initial center before fixes', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const RouteMapView(
            points: [],
            initialCenter: LatLng(12.9716, 77.5946),
            emptyHint: 'Waiting for GPS…',
          ),
        ),
      );
      await _settle(tester);

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('Waiting for GPS…'), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('paints the recorded track once fixes arrive', (tester) async {
      await tester.pumpWidget(
        wrap(
          const RouteMapView(
            points: [
              GeoPoint(latitude: 12.9716, longitude: 77.5946, timestampMs: 0),
              GeoPoint(
                latitude: 12.9726,
                longitude: 77.5956,
                timestampMs: 1000,
              ),
            ],
            active: true,
          ),
        ),
      );
      await _settle(tester);

      expect(find.byIcon(Icons.map_outlined), findsNothing);
      expect(find.byType(FlutterMap), findsOneWidget);

      await _teardown(tester);
    });
  });
}
