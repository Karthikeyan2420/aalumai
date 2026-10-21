import 'dart:convert';
import 'dart:io';

import 'package:aalumai/features/fitness/data/yoga_api_service.dart';
import 'package:aalumai/features/fitness/domain/indian_yoga.dart';
import 'package:aalumai/features/fitness/domain/yoga.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('YogaPose', () {
    test('slugify produces stable ASCII keys', () {
      expect(YogaPose.slugify('Downward-Facing Dog'), 'downward-facing-dog');
      expect(YogaPose.slugify("Child's Pose"), 'child-s-pose');
      expect(YogaPose.slugify('  Tree  '), 'tree');
    });

    test('normalize strips diacritics and spacing', () {
      expect(YogaPose.normalize('Vṛkṣasana'), YogaPose.normalize('Vrksasana'));
      expect(YogaPose.normalize('Adho Mukha'), 'adhomukha');
    });

    test('fromApiJson parses a record and prefers the PNG asset', () {
      final pose = YogaPose.fromApiJson({
        'id': 41,
        'english_name': 'Tree',
        'sanskrit_name_adapted': 'Vrksasana',
        'sanskrit_name': 'Vṛkṣasana',
        'translation_name': 'Tree Pose',
        'pose_description': 'A balancing pose.',
        'pose_benefits': 'Improves balance.',
        'url_svg': 'https://example.test/tree.svg',
        'url_png': 'https://example.test/tree.png',
        'difficulty_level': 'Beginner',
      });
      expect(pose, isNotNull);
      expect(pose!.englishName, 'Tree');
      expect(pose.key, 'tree');
      expect(pose.apiId, 41);
      expect(pose.imageUrl, 'https://example.test/tree.png');
      expect(pose.difficulty, YogaDifficulty.beginner);
      expect(pose.source, YogaPoseSource.api);
      // The dataset's benefits text is dropped: it carries unverified medical
      // claims ("therapeutic for…") that the app must not display.
      expect(pose.benefits, isEmpty);
    });

    test('fromApiJson rejects a record without an english name', () {
      expect(YogaPose.fromApiJson({'id': 1}), isNull);
    });
  });

  group('mergeYogaPoses', () {
    const curated = [
      YogaPose(
        key: 'vrikshasana',
        englishName: 'Tree Pose',
        sanskritName: 'Vrikshasana',
      ),
      YogaPose(
        key: 'bhujangasana',
        englishName: 'Cobra Pose',
        sanskritName: 'Bhujangasana',
      ),
    ];
    final api = [
      const YogaPose(
        key: 'tree',
        englishName: 'Tree',
        imageUrl: 'https://cdn.test/tree.png',
        description: 'Balance.',
        source: YogaPoseSource.api,
      ),
      const YogaPose(
        key: 'warrior-one',
        englishName: 'Warrior One',
        imageUrl: 'https://cdn.test/warrior.png',
        source: YogaPoseSource.api,
      ),
    ];

    test('copies a verified image onto the matching curated pose', () {
      final merged = mergeYogaPoses(curated: curated, apiPoses: api);
      final tree = merged.firstWhere((p) => p.key == 'vrikshasana');
      expect(tree.imageUrl, 'https://cdn.test/tree.png');
      expect(tree.englishName, 'Tree Pose');
    });

    test('keeps a curated pose without an image as a placeholder', () {
      final merged = mergeYogaPoses(curated: curated, apiPoses: api);
      final cobra = merged.firstWhere((p) => p.key == 'bhujangasana');
      expect(cobra.hasImage, isFalse);
    });

    test('appends unmatched API poses rather than dropping them', () {
      final merged = mergeYogaPoses(curated: curated, apiPoses: api);
      expect(merged.map((p) => p.key), contains('warrior-one'));
      expect(merged.length, curated.length + 1);
    });

    test('marks known-advanced API poses above beginner when appending', () {
      final merged = mergeYogaPoses(curated: const [], apiPoses: [
        const YogaPose(key: 'handstand', englishName: 'Handstand'),
        const YogaPose(key: 'wild-thing', englishName: 'Wild Thing'),
        const YogaPose(key: 'boat', englishName: 'Boat'),
      ]);
      expect(
        merged.firstWhere((p) => p.key == 'handstand').difficulty,
        YogaDifficulty.advanced,
      );
      expect(
        merged.firstWhere((p) => p.key == 'wild-thing').difficulty,
        YogaDifficulty.intermediate,
      );
      expect(
        merged.firstWhere((p) => p.key == 'boat').difficulty,
        YogaDifficulty.beginner,
      );
    });

    test('the bundled snapshot parses with no benefit claims anywhere', () {
      final rows =
          jsonDecode(File('assets/data/yoga_poses.json').readAsStringSync())
              as List<dynamic>;
      final claims = RegExp(
        'Therapeutic|cures? |high blood pressure|asthma|infertility|'
        'depression|obesity|menopause|insomnia|sinusitis|diabetes|thyroid|'
        'sciatica|osteoporosis',
        caseSensitive: false,
      );
      var parsed = 0;
      for (final row in rows) {
        final pose = YogaPose.fromApiJson((row as Map).cast<String, dynamic>());
        if (pose == null) continue;
        parsed++;
        expect(pose.benefits, isEmpty, reason: pose.englishName);
        expect(claims.hasMatch(pose.description), isFalse,
            reason: pose.englishName);
      }
      expect(parsed, greaterThan(0));
    });
  });

  group('YogaRoutineGenerator', () {
    test('builds a morning routine in protocol order', () {
      final routine = YogaRoutineGenerator.build(
        kind: YogaRoutineKind.morning,
        difficulty: YogaDifficulty.beginner,
        poses: kIndianYogaPoses,
      );
      expect(routine.isNotEmpty, isTrue);
      expect(routine.items.first.pose.key, 'sukhasana');
      expect(routine.items.last.pose.key, 'shavasana');
      expect(routine.totalSeconds, greaterThan(0));
    });

    test('never includes a pose above the requested difficulty', () {
      for (final difficulty in YogaDifficulty.values) {
        final routine = YogaRoutineGenerator.build(
          kind: YogaRoutineKind.long,
          difficulty: difficulty,
          poses: kIndianYogaPoses,
        );
        expect(
          routine.items.every(
            (item) => item.pose.difficulty.index <= difficulty.index,
          ),
          isTrue,
          reason: 'no pose may outrank $difficulty',
        );
      }
    });

    test('a beginner routine drops the intermediate chair pose', () {
      final routine = YogaRoutineGenerator.build(
        kind: YogaRoutineKind.long,
        difficulty: YogaDifficulty.beginner,
        poses: kIndianYogaPoses,
      );
      expect(routine.items.any((i) => i.pose.key == 'utkatasana'), isFalse);
    });

    test('skips poses that are not in the supplied catalogue', () {
      final only = kIndianYogaPoses
          .where((p) => p.key == 'tadasana')
          .toList();
      final routine = YogaRoutineGenerator.build(
        kind: YogaRoutineKind.standard,
        difficulty: YogaDifficulty.beginner,
        poses: only,
      );
      expect(routine.items.map((i) => i.pose.key).toList(), ['tadasana']);
    });

    test('keysFor returns the exact protocol sequence', () {
      final keys = YogaRoutineGenerator.keysFor(YogaRoutineKind.recovery);
      expect(keys.first, 'sukhasana');
      expect(keys, contains('setu-bandhasana'));
    });
  });

  group('dailyYogaRecommendation', () {
    test('maps weekdays to practical routines', () {
      expect(dailyYogaRecommendation(DateTime.monday), YogaRoutineKind.morning);
      expect(
        dailyYogaRecommendation(DateTime.thursday),
        YogaRoutineKind.recovery,
      );
      expect(dailyYogaRecommendation(DateTime.sunday), YogaRoutineKind.long);
    });
  });

  group('YogaApiService', () {
    test('parses the bare-array /poses payload', () async {
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/poses'));
        return http.Response(
          jsonEncode([
            {
              'id': 41,
              'english_name': 'Tree',
              'sanskrit_name_adapted': 'Vrksasana',
              'url_png': 'https://cdn.test/tree.png',
            },
            {'id': 99},
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final service = YogaApiService(
        client: client,
        baseUrl: 'https://example.test/v1',
      );
      final poses = await service.fetchPoses();
      expect(poses, hasLength(1));
      expect(poses.single.englishName, 'Tree');
    });

    test('throws YogaApiException on a non-200 response', () async {
      final client = MockClient((_) async => http.Response('nope', 503));
      final service = YogaApiService(
        client: client,
        baseUrl: 'https://example.test/v1',
      );
      expect(service.fetchPoses(), throwsA(isA<YogaApiException>()));
    });
  });
}
