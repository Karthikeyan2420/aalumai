/// Yoga domain model.
///
/// Everything here is pure Dart (no Flutter, no database, no network) so the
/// pose catalogue, routine generation and parsing can be unit-tested in
/// isolation. The live [YogaPose] data comes from the yoga API (metadata +
/// demonstration images); the written instructions and Indian-protocol routine
/// content live in `indian_yoga.dart` and are merged onto the API poses.
library;

/// Practitioner experience, aligned with the module's `FitnessLevel`.
enum YogaDifficulty { beginner, intermediate, advanced }

/// Where a [YogaPose] came from. Kept for honest provenance in the UI.
enum YogaPoseSource { bundled, api }

/// A single yoga posture.
class YogaPose {
  const YogaPose({
    required this.key,
    required this.englishName,
    this.sanskritName = '',
    this.translation = '',
    this.description = '',
    this.benefits = '',
    this.instructions = const [],
    this.breathing = '',
    this.contraindications = '',
    this.imageUrl = '',
    this.category = '',
    this.difficulty = YogaDifficulty.beginner,
    this.apiId,
    this.source = YogaPoseSource.bundled,
  });

  /// Stable identity across the bundled catalogue and the API.
  final String key;
  final String englishName;

  /// Sanskrit name when known. Empty when the source publishes none.
  final String sanskritName;

  /// Literal translation of the Sanskrit, when the source publishes it.
  final String translation;

  /// Free-text description, from the API when available.
  final String description;

  /// Optional benefit text. The curated catalogue publishes none, and the
  /// API's `pose_benefits` field is deliberately *not* imported because it
  /// carries unverified medical claims ("therapeutic for high blood
  /// pressure…") that the app will not reproduce.
  final String benefits;

  /// Step-by-step practice cues. Hand-authored (Indian protocol reference).
  final List<String> instructions;

  /// Breathing guidance. Hand-authored.
  final String breathing;

  /// Who should avoid or modify the pose. Hand-authored.
  final String contraindications;

  /// Demonstration image. Empty when no *verified* image is available; the UI
  /// must then show a written placeholder, never an unrelated picture.
  final String imageUrl;

  /// Broad class such as `Standing`, `Seated`, `Prone`, `Supine`, `Restorative`.
  final String category;

  final YogaDifficulty difficulty;

  /// Identifier on the yoga API, when this pose came from (or matched) it.
  final int? apiId;

  final YogaPoseSource source;

  bool get hasImage => imageUrl.trim().isNotEmpty;

  /// A display name: English, with Sanskrit appended when available.
  String get displayName =>
      sanskritName.isEmpty ? englishName : '$englishName ($sanskritName)';

  YogaPose copyWith({
    String? key,
    String? englishName,
    String? sanskritName,
    String? translation,
    String? description,
    String? benefits,
    List<String>? instructions,
    String? breathing,
    String? contraindications,
    String? imageUrl,
    String? category,
    YogaDifficulty? difficulty,
    int? apiId,
    YogaPoseSource? source,
  }) {
    return YogaPose(
      key: key ?? this.key,
      englishName: englishName ?? this.englishName,
      sanskritName: sanskritName ?? this.sanskritName,
      translation: translation ?? this.translation,
      description: description ?? this.description,
      benefits: benefits ?? this.benefits,
      instructions: instructions ?? this.instructions,
      breathing: breathing ?? this.breathing,
      contraindications: contraindications ?? this.contraindications,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      apiId: apiId ?? this.apiId,
      source: source ?? this.source,
    );
  }

  /// Parses one record from the yoga API `/v1/poses` response. Tolerates
  /// missing fields: a record without a usable english name is rejected by
  /// returning `null` so the caller can skip it.
  static YogaPose? fromApiJson(Map<String, dynamic> json) {
    final english = _string(json['english_name']);
    if (english.isEmpty) return null;
    final sanskrit =
        _string(json['sanskrit_name_adapted']).isNotEmpty
            ? _string(json['sanskrit_name_adapted'])
            : _string(json['sanskrit_name']);
    // `url_png` is the raster asset; `cached_network_image` cannot render the
    // SVG variant, so the PNG is the only image we accept.
    final image = _string(json['url_png']);
    return YogaPose(
      key: slugify(english),
      englishName: english,
      sanskritName: sanskrit,
      translation: _string(json['translation_name']),
      description: _string(json['pose_description']),
      // `pose_benefits` is dropped on purpose: the third-party dataset mixes
      // real benefits with medical claims the app must not display. The
      // mechanical `pose_description` text is kept.
      benefits: '',
      imageUrl: image,
      difficulty: _difficultyFromString(_string(json['difficulty_level'])),
      apiId: json['id'] is int ? json['id'] as int : null,
      source: YogaPoseSource.api,
    );
  }

  static String _string(Object? value) => value is String ? value.trim() : '';

  static YogaDifficulty _difficultyFromString(String value) {
    return switch (value.trim().toLowerCase()) {
      'advanced' => YogaDifficulty.advanced,
      'intermediate' => YogaDifficulty.intermediate,
      _ => YogaDifficulty.beginner,
    };
  }

  /// A stable, ASCII key from a pose name: lowercase, diacritics stripped,
  /// non-alphanumerics collapsed to single hyphens.
  static String slugify(String value) {
    final buffer = StringBuffer();
    var lastHyphen = false;
    for (final rune in value.toLowerCase().runes) {
      final isWord = (rune >= 0x61 && rune <= 0x7a) || (rune >= 0x30 && rune <= 0x39);
      if (isWord) {
        buffer.writeCharCode(rune);
        lastHyphen = false;
      } else if (!lastHyphen && buffer.isNotEmpty) {
        buffer.write('-');
        lastHyphen = true;
      }
    }
    final out = buffer.toString();
    return out.endsWith('-') ? out.substring(0, out.length - 1) : out;
  }

  /// Common Sanskrit diacritics mapped to their base Latin letters, so
  /// `Vṛkṣasana` and `Vrksasana` collapse to the same token.
  static const Map<int, int> _diacritics = {
    0x0101: 0x61, // ā -> a
    0x012B: 0x69, // ī -> i
    0x016B: 0x75, // ū -> u
    0x1E5B: 0x72, // ṛ -> r
    0x1E5D: 0x72, // ṝ -> r
    0x1E37: 0x6C, // ḷ -> l
    0x1E6D: 0x74, // ṭ -> t
    0x1E0D: 0x64, // ḍ -> d
    0x1E47: 0x6E, // ṇ -> n
    0x015B: 0x73, // ś -> s
    0x1E63: 0x73, // ṣ -> s
    0x1E45: 0x6E, // ṅ -> n
    0x00F1: 0x6E, // ñ -> n
    0x1E43: 0x6D, // ṃ -> m
    0x1E41: 0x6D, // ṁ -> m
    0x1E25: 0x68, // ḥ -> h
  };

  /// Normalises a name for matching: lowercase ASCII letters only, with common
  /// diacritics folded to their base letter.
  static String normalize(String value) {
    final buffer = StringBuffer();
    for (final rune in value.toLowerCase().runes) {
      final base = _diacritics[rune];
      if (base != null) {
        buffer.writeCharCode(base);
      } else if (rune >= 0x61 && rune <= 0x7a) {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }
}

/// One pose inside a routine, with the time to hold or flow through it.
class YogaPlanItem {
  const YogaPlanItem({required this.pose, required this.durationSec});

  final YogaPose pose;
  final int durationSec;

  YogaPlanItem copyWith({int? durationSec}) =>
      YogaPlanItem(pose: pose, durationSec: durationSec ?? this.durationSec);
}

/// The recommended routines a user can start from the Yoga screen.
///
/// Names are sourced from the Ministry of AYUSH *Common Yoga Protocol* concept
/// (morning/evening/flexibility/recovery) and from practical time budgets.
enum YogaRoutineKind {
  morning,
  evening,
  flexibility,
  beginner,
  recovery,
  balanceMobility,
  breathing,
  short,
  standard,
  long,
}

/// A generated, ordered yoga practice.
class YogaRoutine {
  const YogaRoutine({
    required this.kind,
    required this.difficulty,
    required this.items,
  });

  final YogaRoutineKind kind;
  final YogaDifficulty difficulty;
  final List<YogaPlanItem> items;

  int get poseCount => items.length;

  int get totalSeconds =>
      items.fold<int>(0, (sum, item) => sum + item.durationSec);

  int get totalMinutes => (totalSeconds / 60).round();

  bool get isNotEmpty => items.isNotEmpty;
}

/// How an individual pose in a yoga session was left.
enum YogaPoseOutcome { completed, skipped }

/// How a yoga session as a whole ended.
enum YogaSessionOutcome { completed, partial, cancelled }
