import 'package:aalumai/features/learning/data/curriculum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('kTamilEnglishCourse', () {
    test('has 30 sequential lessons', () {
      expect(kTamilEnglishCourse.length, 30);
      for (var i = 0; i < kTamilEnglishCourse.length; i++) {
        expect(kTamilEnglishCourse[i].day, i + 1);
      }
    });

    test('every lesson has complete content', () {
      for (final lesson in kTamilEnglishCourse) {
        expect(lesson.title.trim(), isNotEmpty);
        expect(lesson.grammarTitle.trim(), isNotEmpty);
        expect(lesson.grammarTa.trim(), isNotEmpty);
        expect(lesson.words, isNotEmpty);
        for (final word in lesson.words) {
          expect(word.word.trim(), isNotEmpty);
          expect(word.meaningTa.trim(), isNotEmpty);
          expect(word.pron.trim(), isNotEmpty);
          expect(word.exampleEn.trim(), isNotEmpty);
          expect(word.exampleTa.trim(), isNotEmpty);
        }
      }
    });
  });

  group('learningGrammar', () {
    test('returns null for empty input', () {
      expect(learningGrammar(''), isNull);
    });

    test('returns null for malformed json', () {
      expect(learningGrammar('{not json'), isNull);
    });

    test('decodes a valid payload', () {
      const json =
          '{"title":"Present tense","explanationTa":"விளக்கம்",'
          '"sentencesEn":["I go"],"sentencesTa":["நான் செல்கிறேன்"]}';
      final info = learningGrammar(json);
      expect(info, isNotNull);
      expect(info!.title, 'Present tense');
      expect(info.sentencesEn, ['I go']);
      expect(info.sentencesTa, ['நான் செல்கிறேன்']);
    });
  });
}
