import 'dart:math';

import 'data/alarm_repository.dart';

/// A generated dismissal challenge: a [prompt] shown to the user and the
/// [answer] they must reproduce to dismiss the alarm.
class AlarmChallengeData {
  const AlarmChallengeData({required this.prompt, required this.answer});

  final String prompt;
  final String answer;

  /// Whether [input] matches the expected answer (trimmed, case-insensitive).
  bool matches(String input) =>
      input.trim().toUpperCase() == answer.toUpperCase();

  static const empty = AlarmChallengeData(prompt: '', answer: '');
}

/// Logic for an alarm's ordered list of dismissal challenges.
///
/// An alarm must pass **every** challenge in its sequence (1–4 items) before it
/// stops. Types may repeat (e.g. "math,math,code"). Kept pure and separate so
/// ordering/parsing is unit-testable without a device.
class AlarmChallengeSequence {
  const AlarmChallengeSequence._();

  static const int maxLength = 4;
  static const int minLength = 1;

  /// The kinds a user can add (the `none` sentinel is never part of a sequence).
  static const List<AlarmChallenge> selectable = [
    AlarmChallenge.math,
    AlarmChallenge.memory,
    AlarmChallenge.code,
  ];

  static const List<AlarmChallenge> defaultSequence = [AlarmChallenge.math];

  /// Decodes a persisted `"math,memory"` string into kinds, ignoring unknown
  /// names and the `none` sentinel. Duplicates are preserved on purpose.
  static List<AlarmChallenge> decode(String raw) {
    if (raw.trim().isEmpty) return const [];
    final result = <AlarmChallenge>[];
    for (final part in raw.split(',')) {
      final name = part.trim();
      if (name.isEmpty) continue;
      for (final candidate in AlarmChallenge.values) {
        if (candidate != AlarmChallenge.none && candidate.name == name) {
          result.add(candidate);
          break;
        }
      }
    }
    return result;
  }

  /// Encodes [sequence] for storage (bounded to [maxLength], `none` dropped).
  static String encode(List<AlarmChallenge> sequence) => sequence
      .where((c) => c != AlarmChallenge.none)
      .take(maxLength)
      .map((c) => c.name)
      .join(',');

  /// Parses a raw editor/drag reorder into a stored value.
  static List<AlarmChallenge> normalize(List<AlarmChallenge> sequence) {
    final cleaned = sequence.where((c) => c != AlarmChallenge.none).toList();
    if (cleaned.length > maxLength) return cleaned.sublist(0, maxLength);
    return cleaned;
  }

  /// The effective ordered challenges for an alarm.
  ///
  /// Always returns 1–[maxLength] items so the ringing flow is always
  /// completable: a persisted sequence wins, otherwise the legacy
  /// [legacyType] is used, otherwise a default single math challenge.
  static List<AlarmChallenge> resolve(String raw, int legacyType) {
    var sequence = decode(raw);
    if (sequence.isEmpty && legacyType != AlarmChallenge.none.index) {
      final legacy = AlarmChallenge.fromIndex(legacyType);
      if (legacy != AlarmChallenge.none) sequence = [legacy];
    }
    if (sequence.isEmpty) sequence = List.of(defaultSequence);
    if (sequence.length > maxLength) sequence = sequence.sublist(0, maxLength);
    return sequence;
  }
}

/// User-adjustable knobs for the generated challenges, persisted on the alarm
/// as a compact `challengeParam` string (e.g. `"codeLength=4"`). Kept pure so
/// it can be unit-tested without a device.
class AlarmChallengeSettings {
  const AlarmChallengeSettings({this.codeLength = defaultCodeLength});

  /// How many characters the "type a code" challenge shows. Kept small enough
  /// to retype while sleepy, but the user can raise it up to [maxCodeLength].
  static const int defaultCodeLength = 4;
  static const int minCodeLength = 3;
  static const int maxCodeLength = 16;

  /// The preset lengths offered in the alarm editor.
  static const List<int> codeLengthPresets = [4, 5, 6, 8, 12, 16];

  final int codeLength;

  static int clampCodeLength(int value) =>
      value.clamp(minCodeLength, maxCodeLength);

  /// Parses a stored `challengeParam` string, falling back to defaults for
  /// blank/legacy or malformed values.
  static AlarmChallengeSettings decode(String raw) {
    var length = defaultCodeLength;
    for (final part in raw.split(';')) {
      final kv = part.split('=');
      if (kv.length != 2) continue;
      if (kv[0].trim() == 'codeLength') {
        final parsed = int.tryParse(kv[1].trim());
        if (parsed != null) length = clampCodeLength(parsed);
      }
    }
    return AlarmChallengeSettings(codeLength: length);
  }

  String encode() => 'codeLength=$codeLength';

  AlarmChallengeSettings copyWith({int? codeLength}) =>
      AlarmChallengeSettings(codeLength: codeLength ?? this.codeLength);
}

/// Deterministic-if-seeded generators for the alarm dismissal challenges.
/// Kept pure so they can be unit-tested without a device.
class AlarmChallengeGenerator {
  static AlarmChallengeData generate(
    AlarmChallenge kind,
    Random random, {
    int codeLength = AlarmChallengeSettings.defaultCodeLength,
  }) {
    switch (kind) {
      case AlarmChallenge.none:
        return AlarmChallengeData.empty;
      case AlarmChallenge.math:
        return _math(random);
      case AlarmChallenge.memory:
        return _memory(random);
      case AlarmChallenge.code:
        return _code(random, codeLength);
    }
  }

  static AlarmChallengeData _math(Random random) {
    if (random.nextBool()) {
      final x = 3 + random.nextInt(9);
      final y = 3 + random.nextInt(9);
      return AlarmChallengeData(prompt: '$x × $y', answer: '${x * y}');
    }
    final a = 11 + random.nextInt(40);
    final b = 7 + random.nextInt(30);
    return AlarmChallengeData(prompt: '$a + $b', answer: '${a + b}');
  }

  static AlarmChallengeData _memory(Random random) {
    final digits = List.generate(5, (_) => random.nextInt(10)).join();
    return AlarmChallengeData(prompt: digits, answer: digits);
  }

  static AlarmChallengeData _code(Random random, int codeLength) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final length = AlarmChallengeSettings.clampCodeLength(codeLength);
    final code =
        List.generate(
          length,
          (_) => chars[random.nextInt(chars.length)],
        ).join();
    return AlarmChallengeData(prompt: code, answer: code);
  }
}
