import 'package:aalumai/features/fitness/widgets/exercise_art.dart';
import 'package:aalumai/features/fitness/widgets/exercise_gif.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('an exercise with no media uses the illustration', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ExerciseGif(gifUrl: '', category: 2, timed: false),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ExerciseArt), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });
}
