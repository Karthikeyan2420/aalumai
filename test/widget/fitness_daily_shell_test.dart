import 'package:aalumai/core/widgets/motivation_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DayCounter shows plan progress copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DayCounter(day: 12, total: 30),
        ),
      ),
    );
    expect(find.text('Day 12 of 30'), findsOneWidget);
    expect(find.textContaining('through your plan'), findsOneWidget);
  });
}
