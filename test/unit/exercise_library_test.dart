import 'package:aalumai/features/fitness/data/exercise_catalog.dart';
import 'package:aalumai/features/fitness/domain/exercise_collections.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bundled exercise dataset', () {
    late List<CatalogExercise> catalog;

    setUpAll(() async {
      catalog = await ExerciseCatalog().load();
    });

    test('loads a substantial, duplicate-free library', () {
      expect(catalog.length, greaterThanOrEqualTo(1000));
      final ids = catalog.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'ids are unique');
    });

    test('every record carries the fields the UI reads', () {
      for (final e in catalog) {
        expect(e.name.trim(), isNotEmpty);
        expect(e.muscle.trim(), isNotEmpty, reason: e.name);
        expect(e.equipment.trim(), isNotEmpty, reason: e.name);
        expect(e.category.trim(), isNotEmpty, reason: e.name);
      }
    });

    test('every published demonstration is an absolute GIF URL', () {
      for (final e in catalog) {
        if (e.gifUrl.isEmpty) continue;
        expect(Uri.tryParse(e.gifUrl)?.hasScheme, isTrue, reason: e.name);
        expect(e.gifUrl, endsWith('.gif'), reason: e.name);
      }
    });
  });

  group('workout collection classification', () {
    test('files a strength exercise by the equipment it needs', () {
      expect(
        workoutCollectionFor(equipment: 'dumbbell', sourceCategory: 'strength'),
        WorkoutCollection.dumbbell,
      );
      expect(
        workoutCollectionFor(equipment: 'band', sourceCategory: 'strength'),
        WorkoutCollection.band,
      );
      expect(
        workoutCollectionFor(
          equipment: 'bodyweight',
          sourceCategory: 'strength',
        ),
        WorkoutCollection.bodyweight,
      );
      for (final equipment in const ['barbell', 'cable', 'machine', 'lever']) {
        expect(
          workoutCollectionFor(
            equipment: equipment,
            sourceCategory: 'strength',
          ),
          WorkoutCollection.gym,
          reason: equipment,
        );
      }
    });

    test('stretching wins over the equipment it happens to use', () {
      for (final equipment in const ['dumbbell', 'band', 'bodyweight']) {
        expect(
          workoutCollectionFor(
            equipment: equipment,
            sourceCategory: 'stretching',
          ),
          WorkoutCollection.stretching,
          reason: equipment,
        );
      }
    });

    test('a row with unclassifiable metadata belongs to no collection', () {
      expect(workoutCollectionFor(equipment: '', sourceCategory: ''), isNull);
      expect(
        workoutCollectionFor(equipment: 'foam roller', sourceCategory: ''),
        isNull,
      );
    });
  });
}
