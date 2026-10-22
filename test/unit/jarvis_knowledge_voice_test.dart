import 'package:aalumai/features/jarvis/knowledge/knowledge_base.dart';
import 'package:aalumai/features/jarvis/voice/wake_word.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('knowledge base', () {
    final kb = KnowledgeBase();

    test('matches an exact topic', () {
      final match = kb.match('what is gravity');
      expect(match, isNotNull);
      expect(match!.entry.id, 'gravity');
    });

    test('matches by synonym tag', () {
      final match = kb.match('tell me about h2o');
      expect(match, isNotNull);
      expect(match!.entry.id, 'water');
    });

    test('returns null for unrelated questions', () {
      expect(kb.match('what is the price of bitcoin tomorrow'), isNull);
    });

    test('entries have non-empty summaries', () {
      for (final entry in kb.entries) {
        expect(entry.summary.trim(), isNotEmpty, reason: entry.id);
      }
    });
  });

  group('wake word detector', () {
    const detector = WakeWordDetector();

    test('detects "hey jarvis"', () {
      expect(detector.containsWakeWord('Hey Jarvis'), isTrue);
      expect(detector.containsWakeWord('hey jarvis what is the time'), isTrue);
    });

    test('accepts common mis-hearings', () {
      expect(detector.containsWakeWord('hey jervis'), isTrue);
      expect(detector.containsWakeWord('ok jarvis'), isTrue);
    });

    test('ignores unrelated speech', () {
      expect(detector.containsWakeWord('what is the weather'), isFalse);
      expect(detector.containsWakeWord('hey there friend'), isFalse);
    });

    test('strips the wake phrase leaving the command', () {
      expect(
        detector.stripWakeWord('hey jarvis what is the time'),
        'what is the time',
      );
      expect(detector.stripWakeWord('hey jarvis'), '');
    });
  });
}
