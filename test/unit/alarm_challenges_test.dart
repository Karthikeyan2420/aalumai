import 'dart:math';

import 'package:aalumai/features/alarms/alarm_challenges.dart';
import 'package:aalumai/features/alarms/data/alarm_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AlarmChallengeGenerator', () {
    test('none produces an empty challenge', () {
      final data = AlarmChallengeGenerator.generate(
        AlarmChallenge.none,
        Random(1),
      );
      expect(data.prompt, isEmpty);
      expect(data.answer, isEmpty);
      expect(data.matches(''), isTrue);
    });

    test('math challenge is self-consistent', () {
      for (var seed = 0; seed < 50; seed++) {
        final data = AlarmChallengeGenerator.generate(
          AlarmChallenge.math,
          Random(seed),
        );
        expect(data.answer, isNotEmpty);
        expect(data.matches(data.answer), isTrue);
        expect(int.tryParse(data.answer), isNotNull);
      }
    });

    test('memory challenge reveals five digits', () {
      final data = AlarmChallengeGenerator.generate(
        AlarmChallenge.memory,
        Random(3),
      );
      expect(data.prompt, hasLength(5));
      expect(int.tryParse(data.prompt), isNotNull);
      expect(data.answer, data.prompt);
    });

    test(
      'code challenge defaults to four characters and is case-insensitive',
      () {
        for (var seed = 0; seed < 20; seed++) {
          final data = AlarmChallengeGenerator.generate(
            AlarmChallenge.code,
            Random(seed),
          );
          expect(data.prompt, hasLength(4));
          expect(data.matches(data.answer.toLowerCase()), isTrue);
          expect(data.matches('XXXX'), isFalse);
        }
      },
    );

    test('code challenge honours a configured length', () {
      for (final length in [3, 6, 16]) {
        final data = AlarmChallengeGenerator.generate(
          AlarmChallenge.code,
          Random(7),
          codeLength: length,
        );
        expect(data.prompt, hasLength(length));
        expect(data.matches(data.answer), isTrue);
      }
    });

    test('matches trims surrounding whitespace', () {
      const data = AlarmChallengeData(prompt: '1 + 1', answer: '2');
      expect(data.matches('  2 '), isTrue);
      expect(data.matches('3'), isFalse);
    });
  });

  group('AlarmChallengeSettings', () {
    test('defaults to four characters for blank or legacy values', () {
      expect(AlarmChallengeSettings.decode('').codeLength, 4);
      expect(AlarmChallengeSettings.decode('bogus').codeLength, 4);
      expect(AlarmChallengeSettings.decode('codeLength=abc').codeLength, 4);
    });

    test('encode/decode round-trips the code length', () {
      const settings = AlarmChallengeSettings(codeLength: 8);
      expect(settings.encode(), 'codeLength=8');
      expect(AlarmChallengeSettings.decode(settings.encode()).codeLength, 8);
    });

    test('clamps the code length to the supported range', () {
      expect(AlarmChallengeSettings.decode('codeLength=1').codeLength, 3);
      expect(AlarmChallengeSettings.decode('codeLength=99').codeLength, 16);
    });
  });

  group('AlarmChallengeSequence', () {
    test('encode/decode round-trips an ordered sequence', () {
      const sequence = [
        AlarmChallenge.math,
        AlarmChallenge.memory,
        AlarmChallenge.code,
      ];
      final encoded = AlarmChallengeSequence.encode(sequence);
      expect(encoded, 'math,memory,code');
      expect(AlarmChallengeSequence.decode(encoded), sequence);
    });

    test('decode preserves repeats and ignores unknown/blank names', () {
      expect(AlarmChallengeSequence.decode('math,math, bogus , code '), [
        AlarmChallenge.math,
        AlarmChallenge.math,
        AlarmChallenge.code,
      ]);
      expect(AlarmChallengeSequence.decode(''), isEmpty);
      expect(AlarmChallengeSequence.decode('none'), isEmpty);
    });

    test('encode drops the none sentinel and caps at the max length', () {
      final encoded = AlarmChallengeSequence.encode([
        AlarmChallenge.none,
        AlarmChallenge.math,
        AlarmChallenge.math,
        AlarmChallenge.math,
        AlarmChallenge.math,
        AlarmChallenge.math,
      ]);
      expect(encoded, 'math,math,math,math');
      expect(encoded.split(','), hasLength(AlarmChallengeSequence.maxLength));
    });

    test('resolve prefers the stored sequence', () {
      expect(
        AlarmChallengeSequence.resolve(
          'code,math',
          AlarmChallenge.memory.index,
        ),
        [AlarmChallenge.code, AlarmChallenge.math],
      );
    });

    test('resolve falls back to the legacy type then to a default', () {
      expect(AlarmChallengeSequence.resolve('', AlarmChallenge.memory.index), [
        AlarmChallenge.memory,
      ]);
      expect(
        AlarmChallengeSequence.resolve('', AlarmChallenge.none.index),
        AlarmChallengeSequence.defaultSequence,
      );
    });

    test('normalize keeps at most the max length', () {
      final list = [
        AlarmChallenge.math,
        AlarmChallenge.memory,
        AlarmChallenge.code,
        AlarmChallenge.math,
        AlarmChallenge.code,
      ];
      expect(
        AlarmChallengeSequence.normalize(list),
        hasLength(AlarmChallengeSequence.maxLength),
      );
    });
  });
}
