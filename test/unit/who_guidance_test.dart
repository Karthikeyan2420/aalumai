import 'package:aalumai/features/fitness/domain/who_guidance.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fitness_fixtures.dart';

void main() {
  group('whoWeeklyProgress', () {
    // 2026-01-05 is a Monday.
    final monday = DateTime(2026, 1, 5, 8);

    test('sums aerobic minutes from run/walk sessions this week', () {
      final progress = whoWeeklyProgress([
        testSession(
          id: 1,
          type: 1,
          startedAt: DateTime(2026, 1, 6, 7),
          durationSec: 60 * 60,
        ),
        testSession(
          id: 2,
          type: 2,
          startedAt: DateTime(2026, 1, 7, 18),
          durationSec: 30 * 60,
        ),
      ], now: monday);
      expect(progress.aerobicMinutes, 90);
      expect(progress.meetsAerobic, isFalse);
    });

    test('counts only distinct calendar days for strength', () {
      final progress = whoWeeklyProgress([
        testSession(
          id: 1,
          type: 0,
          startedAt: DateTime(2026, 1, 5, 7),
          durationSec: 1800,
        ),
        testSession(
          id: 2,
          type: 0,
          startedAt: DateTime(2026, 1, 5, 19),
          durationSec: 1800,
        ),
        testSession(
          id: 3,
          type: 0,
          startedAt: DateTime(2026, 1, 8, 7),
          durationSec: 1800,
        ),
      ], now: monday);
      expect(progress.strengthDays, 2);
      expect(progress.meetsStrength, isTrue);
    });

    test('meets the aerobic target at 150 moderate minutes', () {
      final progress = whoWeeklyProgress([
        testSession(
          id: 1,
          type: 1,
          startedAt: DateTime(2026, 1, 6, 7),
          durationSec: 150 * 60,
        ),
      ], now: monday);
      expect(progress.meetsAerobic, isTrue);
      expect(progress.aerobicProgress, 1.0);
    });

    test('ignores sessions outside the current week and unfinished ones', () {
      final progress = whoWeeklyProgress([
        testSession(
          id: 1,
          type: 1,
          startedAt: DateTime(2025, 12, 30, 7),
          durationSec: 60 * 60,
        ), // previous week
        testSession(
          id: 2,
          type: 1,
          startedAt: DateTime(2026, 1, 6, 7),
          endedAt: DateTime(2026, 1, 6, 7),
        ), // zero duration
      ], now: monday);
      expect(progress.aerobicMinutes, 0);
      expect(progress.meetsAll, isFalse);
    });

    test('meetsAll requires both aerobic and strength targets', () {
      final progress = whoWeeklyProgress([
        testSession(
          id: 1,
          type: 1,
          startedAt: DateTime(2026, 1, 6, 7),
          durationSec: 160 * 60,
        ),
        testSession(
          id: 2,
          type: 0,
          startedAt: DateTime(2026, 1, 5, 7),
          durationSec: 1800,
        ),
        testSession(
          id: 3,
          type: 0,
          startedAt: DateTime(2026, 1, 7, 7),
          durationSec: 1800,
        ),
      ], now: monday);
      expect(progress.meetsAll, isTrue);
    });
  });
}
