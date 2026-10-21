/// Indian yoga pose catalogue and routine generator.
///
/// The sequences and written cues are modelled on the Ministry of AYUSH
/// *Common Yoga Protocol* concept (standing → seated → prone → supine →
/// relaxation). This content is *informed by* that protocol; it is not a
/// verbatim reproduction and it is not government-approved or AYUSH-certified.
///
/// Pose **images** are not declared here beyond the verified demonstration URLs
/// that the yoga API publishes; when a pose has no verified image the UI shows
/// a written placeholder. The live API metadata is merged onto these poses by
/// the repository.
library;

import 'yoga.dart';

/// The distinct practices offered on the Yoga screen.
extension YogaRoutineKindInfo on YogaRoutineKind {
  /// Target length in minutes, used to size generated routines.
  int get targetMinutes => switch (this) {
    YogaRoutineKind.morning => 20,
    YogaRoutineKind.evening => 18,
    YogaRoutineKind.flexibility => 18,
    YogaRoutineKind.beginner => 15,
    YogaRoutineKind.recovery => 18,
    YogaRoutineKind.balanceMobility => 20,
    YogaRoutineKind.breathing => 10,
    YogaRoutineKind.short => 8,
    YogaRoutineKind.standard => 18,
    YogaRoutineKind.long => 40,
  };

  String get label => switch (this) {
    YogaRoutineKind.morning => 'Morning yoga',
    YogaRoutineKind.evening => 'Evening relaxation',
    YogaRoutineKind.flexibility => 'Full-body flexibility',
    YogaRoutineKind.beginner => 'Beginner yoga',
    YogaRoutineKind.recovery => 'Recovery-day yoga',
    YogaRoutineKind.balanceMobility => 'Balance & mobility',
    YogaRoutineKind.breathing => 'Breathing & relaxation',
    YogaRoutineKind.short => 'Short routine (5–10 min)',
    YogaRoutineKind.standard => 'Standard routine (15–20 min)',
    YogaRoutineKind.long => 'Long routine (30–45 min)',
  };

  String get summary => switch (this) {
    YogaRoutineKind.morning => 'Gentle standing and seated poses to start the day.',
    YogaRoutineKind.evening => 'Calming forward bends, twists and relaxation.',
    YogaRoutineKind.flexibility => 'Stretch hips, hamstrings and spine.',
    YogaRoutineKind.beginner => 'Accessible poses with simple modifications.',
    YogaRoutineKind.recovery => 'Soft mobility and relaxation for a rest day.',
    YogaRoutineKind.balanceMobility => 'Standing balance and range-of-motion work.',
    YogaRoutineKind.breathing => 'Comfortable breathing and stillness.',
    YogaRoutineKind.short => 'A quick practice when time is short.',
    YogaRoutineKind.standard => 'A balanced daily practice.',
    YogaRoutineKind.long => 'A complete, unhurried practice.',
  };
}

/// A recommended kind for each weekday (`DateTime.monday` … `sunday`).
///
/// Sunday and the mid-week slot lean restorative; the remaining days alternate
/// between an energising morning flow and a calming evening flow.
YogaRoutineKind dailyYogaRecommendation(int weekday) => switch (weekday) {
  DateTime.monday => YogaRoutineKind.morning,
  DateTime.tuesday => YogaRoutineKind.evening,
  DateTime.wednesday => YogaRoutineKind.flexibility,
  DateTime.thursday => YogaRoutineKind.recovery,
  DateTime.friday => YogaRoutineKind.balanceMobility,
  DateTime.saturday => YogaRoutineKind.standard,
  _ => YogaRoutineKind.long,
};

/// The curated Indian yoga poses.
///
/// Each pose declares `apiMatch` names (normalised) used by the repository to
/// pull the demonstration image and API metadata from the yoga API. Poses with
/// no `apiMatch` ship without an image and render a written placeholder.
const List<YogaPose> kIndianYogaPoses = [
  YogaPose(
    key: 'tadasana',
    englishName: 'Mountain Pose',
    sanskritName: 'Tadasana',
    category: 'Standing',
    difficulty: YogaDifficulty.beginner,
    instructions: [
      'Stand with the feet together or hip-width apart, arms beside the body.',
      'Ground all four corners of both feet and lengthen the spine upward.',
      'Roll the shoulders back and down; let the breath be steady.',
    ],
    breathing: 'Inhale to lengthen, exhale to settle the shoulders.',
    contraindications: 'Avoid prolonged standing if you feel faint or dizzy.',
  ),
  YogaPose(
    key: 'vrikshasana',
    englishName: 'Tree Pose',
    sanskritName: 'Vrikshasana',
    category: 'Standing',
    difficulty: YogaDifficulty.beginner,
    imageUrl:
        'https://res.cloudinary.com/dko1be2jy/image/upload/fl_sanitize/v1676483094/yoga-api/41_veknug.png',
    instructions: [
      'From standing, shift the weight onto the left foot.',
      'Place the right foot on the inner calf or thigh — never on the knee.',
      'Bring the hands together at the chest; use a wall or chair for support.',
    ],
    breathing: 'Breathe slowly and evenly as you find balance.',
    contraindications: 'Use support for balance issues; skip on an injured knee.',
  ),
  YogaPose(
    key: 'padahastasana',
    englishName: 'Standing Forward Bend',
    sanskritName: 'Padahastasana',
    category: 'Standing',
    difficulty: YogaDifficulty.beginner,
    imageUrl:
        'https://res.cloudinary.com/dko1be2jy/image/upload/fl_sanitize/v1676483093/yoga-api/38_yb3thk.png',
    instructions: [
      'From standing, hinge at the hips and fold forward.',
      'Let the head hang and bend the knees as much as you need.',
      'Rest the hands on the shins, the floor, or hold the elbows.',
    ],
    breathing: 'Exhale as you fold; breathe calmly in the pose.',
    contraindications: 'Avoid deep folds with a recent back injury or vertigo.',
  ),
  YogaPose(
    key: 'trikonasana',
    englishName: 'Triangle Pose',
    sanskritName: 'Trikonasana',
    category: 'Standing',
    difficulty: YogaDifficulty.beginner,
    imageUrl:
        'https://res.cloudinary.com/dko1be2jy/image/upload/fl_sanitize/v1676483096/yoga-api/42_jawxqw.png',
    instructions: [
      'Step the feet apart; turn the right foot out and the left foot in.',
      'Reach the right hand down toward the shin and the left arm up.',
      'Keep both sides of the waist long and the gaze forward or up.',
    ],
    breathing: 'Inhale to reach, exhale to lengthen through the side body.',
    contraindications: 'Avoid with a recent neck or low-back injury.',
  ),
  YogaPose(
    key: 'virabhadrasana-two',
    englishName: 'Warrior Two',
    sanskritName: 'Virabhadrasana II',
    category: 'Standing',
    difficulty: YogaDifficulty.beginner,
    imageUrl:
        'https://res.cloudinary.com/dko1be2jy/image/upload/fl_sanitize/v1676483096/yoga-api/45_ehimr1.png',
    instructions: [
      'Step the feet wide; turn the right toes out and bend the right knee.',
      'Extend the arms parallel to the floor and gaze over the front hand.',
      'Keep the knee tracking over the ankle, not past the toes.',
    ],
    breathing: 'Steady, even breaths while you hold.',
    contraindications: 'Skip on a knee, hip or groin injury.',
  ),
  YogaPose(
    key: 'utkatasana',
    englishName: 'Chair Pose',
    sanskritName: 'Utkatasana',
    category: 'Standing',
    difficulty: YogaDifficulty.intermediate,
    imageUrl:
        'https://res.cloudinary.com/dko1be2jy/image/upload/fl_sanitize/v1676483078/yoga-api/9_ewvoun.png',
    instructions: [
      'Stand with the feet together or hip-width apart.',
      'Bend the knees and shift the hips back as if sitting into a chair.',
      'Raise the arms forward or overhead, keeping the spine long.',
    ],
    breathing: 'Inhale to reach up, exhale to sit a little deeper.',
    contraindications: 'Avoid with knee pain or low-back strain.',
  ),
  YogaPose(
    key: 'sukhasana',
    englishName: 'Easy Pose',
    sanskritName: 'Sukhasana',
    category: 'Seated',
    difficulty: YogaDifficulty.beginner,
    instructions: [
      'Sit cross-legged on a mat or cushion with the hips slightly raised.',
      'Rest the hands on the knees and lengthen the spine.',
      'Relax the jaw and let the breath become smooth.',
    ],
    breathing: 'Breathe gently through the nose, letting the exhale be longer.',
    contraindications: 'Sit on a cushion if the hips are tight or knees complain.',
  ),
  YogaPose(
    key: 'vajrasana',
    englishName: 'Thunderbolt Pose',
    sanskritName: 'Vajrasana',
    category: 'Seated',
    difficulty: YogaDifficulty.beginner,
    instructions: [
      'Kneel and sit back on the heels with the knees together.',
      'Keep the spine upright and the hands on the thighs.',
      'Place a folded blanket under the shins if the ankles are stiff.',
    ],
    breathing: 'Slow abdominal breathing; keep the face relaxed.',
    contraindications: 'Avoid with a recent knee or ankle injury.',
  ),
  YogaPose(
    key: 'marjaryasana',
    englishName: 'Cat Pose',
    sanskritName: 'Marjaryasana',
    category: 'All fours',
    difficulty: YogaDifficulty.beginner,
    imageUrl:
        'https://res.cloudinary.com/dko1be2jy/image/upload/fl_sanitize/v1676483075/yoga-api/7_a6aspg.png',
    instructions: [
      'Come onto hands and knees with a flat back.',
      'Exhale, round the spine up and tuck the chin.',
      'Move slowly and keep the wrists under the shoulders.',
    ],
    breathing: 'Exhale as you round; inhale as you return to a neutral spine.',
    contraindications: 'Pad the knees or wrists if they are sensitive.',
  ),
  YogaPose(
    key: 'bitilasana',
    englishName: 'Cow Pose',
    sanskritName: 'Bitilasana',
    category: 'All fours',
    difficulty: YogaDifficulty.beginner,
    imageUrl:
        'https://res.cloudinary.com/dko1be2jy/image/upload/fl_sanitize/v1676483077/yoga-api/8_wi10sn.png',
    instructions: [
      'From hands and knees, inhale and drop the belly gently.',
      'Lift the chest and the tailbone, gaze slightly down or forward.',
      'Keep the neck long rather than craning.',
    ],
    breathing: 'Inhale to open the chest; exhale back to neutral.',
    contraindications: 'Avoid deep extension with a recent back injury.',
  ),
  YogaPose(
    key: 'adho-mukha-svanasana',
    englishName: 'Downward-Facing Dog',
    sanskritName: 'Adho Mukha Svanasana',
    category: 'Standing',
    difficulty: YogaDifficulty.intermediate,
    imageUrl:
        'https://res.cloudinary.com/dko1be2jy/image/upload/fl_sanitize/v1676483081/yoga-api/15_vkviqn.png',
    instructions: [
      'From hands and knees, lift the hips up and back.',
      'Press the hands down and bend the knees if the hamstrings are tight.',
      'Lengthen the spine and relax the neck.',
    ],
    breathing: 'Breathe steadily; hold for a few comfortable breaths.',
    contraindications: 'Avoid with wrist problems or uncontrolled blood pressure.',
  ),
  YogaPose(
    key: 'baddha-konasana',
    englishName: 'Butterfly Pose',
    sanskritName: 'Baddha Konasana',
    category: 'Seated',
    difficulty: YogaDifficulty.beginner,
    imageUrl:
        'https://res.cloudinary.com/dko1be2jy/image/upload/fl_sanitize/v1676483074/yoga-api/5_i64gif.png',
    instructions: [
      'Sit tall and bring the soles of the feet together.',
      'Let the knees fall out to the sides, supporting them if needed.',
      'Hold the feet and keep the spine long.',
    ],
    breathing: 'Exhale to soften the hips; never force the knees down.',
    contraindications: 'Support the knees or skip with a groin injury.',
  ),
  YogaPose(
    key: 'paschimottanasana',
    englishName: 'Seated Forward Bend',
    sanskritName: 'Paschimottanasana',
    category: 'Seated',
    difficulty: YogaDifficulty.beginner,
    imageUrl:
        'https://res.cloudinary.com/dko1be2jy/image/upload/fl_sanitize/v1676483091/yoga-api/30_gumpl3.png',
    instructions: [
      'Sit with the legs extended and the spine tall.',
      'Hinge forward from the hips, bending the knees as needed.',
      'Reach toward the shins or feet without rounding the upper back.',
    ],
    breathing: 'Inhale to lengthen, exhale to fold a little further.',
    contraindications: 'Avoid deep folds with a slipped disc or sciatica.',
  ),
  YogaPose(
    key: 'ardha-matsyendrasana',
    englishName: 'Half Lord of the Fishes',
    sanskritName: 'Ardha Matsyendrasana',
    category: 'Seated',
    difficulty: YogaDifficulty.intermediate,
    imageUrl:
        'https://res.cloudinary.com/dko1be2jy/image/upload/fl_sanitize/v1676483091/yoga-api/32_hafoa0.png',
    instructions: [
      'Sit with one knee bent and the opposite foot placed outside it.',
      'Gently twist toward the bent knee, keeping the spine tall.',
      'Move slowly and keep the breath even.',
    ],
    breathing: 'Inhale to grow tall, exhale to twist a little more.',
    contraindications: 'Avoid deep twists during pregnancy or with a disc injury.',
  ),
  YogaPose(
    key: 'malasana',
    englishName: 'Garland Pose',
    sanskritName: 'Malasana',
    category: 'Squat',
    difficulty: YogaDifficulty.beginner,
    imageUrl:
        'https://res.cloudinary.com/dko1be2jy/image/upload/fl_sanitize/v1676483093/yoga-api/37_moh7ii.png',
    instructions: [
      'Squat with the feet slightly wider than the hips.',
      'Bring the hands together at the chest and press the elbows outward.',
      'Sit on a block if the heels do not reach the floor.',
    ],
    breathing: 'Breathe into the belly; keep the jaw soft.',
    contraindications: 'Support with a block or skip on a knee injury.',
  ),
  YogaPose(
    key: 'anjaneyasana',
    englishName: 'Low Lunge',
    sanskritName: 'Anjaneyasana',
    category: 'Standing',
    difficulty: YogaDifficulty.beginner,
    imageUrl:
        'https://res.cloudinary.com/dko1be2jy/image/upload/fl_sanitize/v1676483086/yoga-api/23_k2jccj.png',
    instructions: [
      'Step one foot forward and lower the back knee.',
      'Sink the hips gently forward until you feel a stretch in the hip.',
      'Keep the front knee over the ankle; support the back knee.',
    ],
    breathing: 'Breathe into the front of the hip.',
    contraindications: 'Pad the back knee or shorten the stance as needed.',
  ),
  YogaPose(
    key: 'bhujangasana',
    englishName: 'Cobra Pose',
    sanskritName: 'Bhujangasana',
    category: 'Prone',
    difficulty: YogaDifficulty.beginner,
    instructions: [
      'Lie on the belly with the hands under the shoulders.',
      'Press the tops of the feet down and lift the chest, keeping it gentle.',
      'Keep the elbows soft and the shoulders away from the ears.',
    ],
    breathing: 'Inhale to lift; keep the neck long.',
    contraindications:
        'Avoid deep backbends during pregnancy or with a recent back injury.',
  ),
  YogaPose(
    key: 'sphinx',
    englishName: 'Sphinx Pose',
    sanskritName: 'Salamba Bhujangasana',
    category: 'Prone',
    difficulty: YogaDifficulty.beginner,
    imageUrl:
        'https://res.cloudinary.com/dko1be2jy/image/upload/fl_sanitize/v1676483092/yoga-api/35_dytwvz.png',
    instructions: [
      'Lie on the belly and place the forearms on the mat.',
      'Lift the chest gently, keeping the hips on the floor.',
      'Relax the legs and lengthen the lower back.',
    ],
    breathing: 'Slow breaths into the upper chest.',
    contraindications: 'Keep the backbend small with a sensitive lower back.',
  ),
  YogaPose(
    key: 'dhanurasana',
    englishName: 'Bow Pose',
    sanskritName: 'Dhanurasana',
    category: 'Prone',
    difficulty: YogaDifficulty.intermediate,
    imageUrl:
        'https://res.cloudinary.com/dko1be2jy/image/upload/fl_sanitize/v1676483072/yoga-api/3_aa0fgk.png',
    instructions: [
      'Lie on the belly and bend both knees, reaching back for the ankles.',
      'Gently kick the feet into the hands to lift the chest.',
      'Keep the breath steady and the gaze down.',
    ],
    breathing: 'Breathe slowly; do not strain the lower back.',
    contraindications: 'Avoid during pregnancy or with a back/neck injury.',
  ),
  YogaPose(
    key: 'ustrasana',
    englishName: 'Camel Pose',
    sanskritName: 'Ustrasana',
    category: 'Kneeling',
    difficulty: YogaDifficulty.intermediate,
    imageUrl:
        'https://res.cloudinary.com/dko1be2jy/image/upload/fl_sanitize/v1676483075/yoga-api/6_ri1w0e.png',
    instructions: [
      'Kneel with the knees hip-width apart and the toes tucked or flat.',
      'Place the hands on the lower back and lift the chest.',
      'Reach back for the heels only if the back stays comfortable.',
    ],
    breathing: 'Inhale to lift the chest; keep the neck relaxed.',
    contraindications: 'Avoid with a neck or low-back injury.',
  ),
  YogaPose(
    key: 'setu-bandhasana',
    englishName: 'Bridge Pose',
    sanskritName: 'Setu Bandhasana',
    category: 'Supine',
    difficulty: YogaDifficulty.beginner,
    imageUrl:
        'https://res.cloudinary.com/dko1be2jy/image/upload/fl_sanitize/v1676483074/yoga-api/4_qq6nxw.png',
    instructions: [
      'Lie on the back with the knees bent and the feet under the knees.',
      'Press the feet down and lift the hips, keeping the knees in line.',
      'Support the lower back with the hands if comfortable.',
    ],
    breathing: 'Inhale to lift, exhale to lower slowly.',
    contraindications: 'Avoid with a recent neck injury.',
  ),
  YogaPose(
    key: 'pawanmuktasana',
    englishName: 'Wind-Relieving Pose',
    sanskritName: 'Pawanmuktasana',
    category: 'Supine',
    difficulty: YogaDifficulty.beginner,
    instructions: [
      'Lie on the back and draw one or both knees toward the chest.',
      'Wrap the arms around the shins and relax the shoulders.',
      'Keep the neck and jaw soft.',
    ],
    breathing: 'Exhale as you hug the knees in.',
    contraindications: 'Avoid after recent abdominal surgery.',
  ),
  YogaPose(
    key: 'shashankasana',
    englishName: "Child's Pose",
    sanskritName: 'Shashankasana',
    category: 'Restorative',
    difficulty: YogaDifficulty.beginner,
    imageUrl:
        'https://res.cloudinary.com/dko1be2jy/image/upload/fl_sanitize/v1676483079/yoga-api/10_wzpo85.png',
    instructions: [
      'Kneel and sit back on the heels, folding forward.',
      'Rest the forehead on the mat and extend the arms or rest them back.',
      'Place a cushion under the hips or forehead for comfort.',
    ],
    breathing: 'Let the breath be slow and quiet.',
    contraindications: 'Use a cushion or skip with a knee injury or pregnancy.',
  ),
  YogaPose(
    key: 'shavasana',
    englishName: 'Corpse Pose',
    sanskritName: 'Shavasana',
    category: 'Restorative',
    difficulty: YogaDifficulty.beginner,
    imageUrl:
        'https://res.cloudinary.com/dko1be2jy/image/upload/fl_sanitize/v1676483078/yoga-api/11_dczyrp.png',
    instructions: [
      'Lie on the back with the legs and arms relaxed and slightly apart.',
      'Close the eyes and let the whole body be heavy.',
      'Return slowly, rolling onto one side before sitting up.',
    ],
    breathing: 'Natural, unforced breathing; observe the breath without controlling it.',
    contraindications: 'Support the knees or lower back if lying flat is uncomfortable.',
  ),
];

/// Maps a curated pose key to the english name(s) the yoga API publishes for
/// the same posture. Only *exact* correspondences are listed: the API does not
/// describe every Indian pose, and a wrong match would show the wrong picture,
/// so unmatched poses keep their written placeholder instead.
const Map<String, List<String>> kYogaPoseApiAliases = {
  'vrikshasana': ['Tree'],
  'padahastasana': ['Standing Forward Bend'],
  'trikonasana': ['Triangle'],
  'virabhadrasana-two': ['Warrior Two'],
  'utkatasana': ['Chair'],
  'marjaryasana': ['Cat'],
  'bitilasana': ['Cow'],
  'adho-mukha-svanasana': ['Downward-Facing Dog'],
  'baddha-konasana': ['Butterfly'],
  'paschimottanasana': ['Seated Forward Bend'],
  'ardha-matsyendrasana': ['Half Lord of the Fishes'],
  'malasana': ['Garland Pose'],
  'anjaneyasana': ['Low Lunge'],
  'sphinx': ['Sphinx'],
  'dhanurasana': ['Bow'],
  'ustrasana': ['Camel'],
  'setu-bandhasana': ['Bridge'],
  'shashankasana': ["Child's Pose"],
  'shavasana': ['Corpse'],
};

/// API poses that are not safe to present as beginner material even though the
/// dataset publishes no difficulty: arm balances, deep backbends, full splits
/// and inversions. [mergeYogaPoses] applies these when API poses are appended,
/// so beginner-facing routines, filters and labels never treat them as easy.
const Set<String> kYogaAdvancedPoseKeys = {
  'crow',
  'forearm-stand',
  'handstand',
  'king-pigeon',
  'plow',
  'shoulder-stand',
  'side-splits',
  'splits',
  'wheel',
};

/// API poses that need some experience but are not advanced. Same rule as
/// [kYogaAdvancedPoseKeys]: editorial judgment layered over the difficulty-free
/// dataset.
const Set<String> kYogaIntermediatePoseKeys = {
  'crescent-lunge',
  'crescent-moon',
  'dolphin',
  'eagle',
  'extended-hand-to-toe',
  'extended-side-angle',
  'half-moon',
  'pigeon',
  'reverse-warrior',
  'side-plank',
  'wild-thing',
};

/// The difficulty an appended API pose is shown with, regardless of what the
/// dataset (which usually publishes none) says.
YogaDifficulty editorialYogaDifficulty(
  String key,
  YogaDifficulty fallback,
) {
  if (kYogaAdvancedPoseKeys.contains(key)) return YogaDifficulty.advanced;
  if (kYogaIntermediatePoseKeys.contains(key)) {
    return YogaDifficulty.intermediate;
  }
  return fallback;
}

/// Merges the curated Indian catalogue with poses from the yoga API
/// (or the bundled snapshot of it).
///
/// Curated poses keep their key, written cues and difficulty. When an API pose
/// matches one via [kYogaPoseApiAliases], its verified image and description are
/// copied across. API poses that match nothing are appended as extra entries so
/// the library is a superset, never a mishmash.
List<YogaPose> mergeYogaPoses({
  required List<YogaPose> curated,
  required List<YogaPose> apiPoses,
}) {
  final aliasToKey = <String, String>{
    for (final entry in kYogaPoseApiAliases.entries)
      for (final name in entry.value) YogaPose.normalize(name): entry.key,
  };
  final consumed = <int>{};
  final merged = <YogaPose>[];

  for (final pose in curated) {
    YogaPose? match;
    for (var i = 0; i < apiPoses.length; i++) {
      final candidate = apiPoses[i];
      final aliasedKey = aliasToKey[YogaPose.normalize(candidate.englishName)];
      final isAlias = aliasedKey == pose.key;
      final isName =
          YogaPose.normalize(candidate.englishName) ==
              YogaPose.normalize(pose.englishName) ||
          (pose.sanskritName.isNotEmpty &&
              YogaPose.normalize(candidate.sanskritName) ==
                  YogaPose.normalize(pose.sanskritName));
      if (isAlias || isName) {
        match = candidate;
        consumed.add(i);
        break;
      }
    }
    merged.add(
      match == null
          ? pose
          : pose.copyWith(
              imageUrl: pose.imageUrl.isEmpty ? match.imageUrl : pose.imageUrl,
              description:
                  pose.description.isEmpty ? match.description : pose.description,
              benefits: pose.benefits.isEmpty ? match.benefits : pose.benefits,
              apiId: match.apiId,
            ),
    );
  }

  final curatedKeys = {for (final pose in curated) pose.key};
  for (var i = 0; i < apiPoses.length; i++) {
    if (consumed.contains(i)) continue;
    final candidate = apiPoses[i];
    if (curatedKeys.contains(candidate.key)) continue;
    merged.add(
      candidate.copyWith(
        difficulty: editorialYogaDifficulty(candidate.key, candidate.difficulty),
      ),
    );
  }
  return List.unmodifiable(merged);
}

/// Ordered source sequences per routine kind.
///
/// Entries are `(poseKey, seconds)`. The generator filters each sequence by the
/// requested difficulty and by the poses actually available, so a missing pose
/// never breaks a routine.
class YogaRoutineGenerator {
  const YogaRoutineGenerator._();

  static const Map<YogaRoutineKind, List<(String, int)>> _sequences = {
    YogaRoutineKind.morning: [
      ('sukhasana', 60),
      ('marjaryasana', 45),
      ('bitilasana', 45),
      ('tadasana', 60),
      ('vrikshasana', 90),
      ('trikonasana', 90),
      ('utkatasana', 60),
      ('paschimottanasana', 60),
      ('bhujangasana', 60),
      ('setu-bandhasana', 60),
      ('shavasana', 120),
    ],
    YogaRoutineKind.evening: [
      ('sukhasana', 75),
      ('marjaryasana', 40),
      ('bitilasana', 40),
      ('ardha-matsyendrasana', 60),
      ('paschimottanasana', 60),
      ('baddha-konasana', 60),
      ('shashankasana', 90),
      ('pawanmuktasana', 60),
      ('shavasana', 150),
    ],
    YogaRoutineKind.flexibility: [
      ('padahastasana', 60),
      ('trikonasana', 75),
      ('anjaneyasana', 60),
      ('baddha-konasana', 75),
      ('paschimottanasana', 75),
      ('malasana', 60),
      ('ardha-matsyendrasana', 60),
      ('shashankasana', 60),
      ('shavasana', 90),
    ],
    YogaRoutineKind.beginner: [
      ('tadasana', 45),
      ('marjaryasana', 40),
      ('bitilasana', 40),
      ('baddha-konasana', 45),
      ('vrikshasana', 60),
      ('paschimottanasana', 45),
      ('shashankasana', 60),
      ('shavasana', 90),
    ],
    YogaRoutineKind.recovery: [
      ('sukhasana', 90),
      ('marjaryasana', 40),
      ('bitilasana', 40),
      ('shashankasana', 90),
      ('pawanmuktasana', 60),
      ('setu-bandhasana', 60),
      ('shavasana', 150),
    ],
    YogaRoutineKind.balanceMobility: [
      ('tadasana', 60),
      ('vrikshasana', 90),
      ('virabhadrasana-two', 75),
      ('trikonasana', 75),
      ('anjaneyasana', 60),
      ('ardha-matsyendrasana', 60),
      ('malasana', 45),
      ('shavasana', 90),
    ],
    YogaRoutineKind.breathing: [
      ('sukhasana', 120),
      ('vajrasana', 120),
      ('tadasana', 60),
      ('shavasana', 180),
    ],
    YogaRoutineKind.short: [
      ('tadasana', 45),
      ('marjaryasana', 40),
      ('baddha-konasana', 45),
      ('paschimottanasana', 50),
      ('shavasana', 90),
    ],
    YogaRoutineKind.standard: [
      ('sukhasana', 60),
      ('marjaryasana', 40),
      ('bitilasana', 40),
      ('tadasana', 45),
      ('vrikshasana', 75),
      ('trikonasana', 75),
      ('baddha-konasana', 60),
      ('paschimottanasana', 60),
      ('bhujangasana', 60),
      ('setu-bandhasana', 60),
      ('shavasana', 120),
    ],
    YogaRoutineKind.long: [
      ('sukhasana', 90),
      ('marjaryasana', 45),
      ('bitilasana', 45),
      ('tadasana', 60),
      ('vrikshasana', 90),
      ('virabhadrasana-two', 75),
      ('trikonasana', 90),
      ('utkatasana', 60),
      ('adho-mukha-svanasana', 60),
      ('padahastasana', 60),
      ('anjaneyasana', 60),
      ('malasana', 60),
      ('baddha-konasana', 75),
      ('paschimottanasana', 75),
      ('ardha-matsyendrasana', 60),
      ('bhujangasana', 60),
      ('sphinx', 60),
      ('dhanurasana', 45),
      ('ustrasana', 45),
      ('setu-bandhasana', 60),
      ('pawanmuktasana', 60),
      ('shashankasana', 60),
      ('shavasana', 180),
    ],
  };

  /// Builds a routine of [kind] for [difficulty] from the available [poses].
  ///
  /// Poses above the requested difficulty are skipped; poses missing from
  /// [poses] are skipped. The result may therefore be shorter than the kind's
  /// target minutes, which is preferred over fabricating or repeating content.
  static YogaRoutine build({
    required YogaRoutineKind kind,
    required YogaDifficulty difficulty,
    required List<YogaPose> poses,
  }) {
    final byKey = {for (final pose in poses) pose.key: pose};
    final maxRank = difficulty.index;
    final items = <YogaPlanItem>[];
    final sequence = _sequences[kind];
    if (sequence != null) {
      for (final (key, seconds) in sequence) {
        final pose = byKey[key];
        if (pose == null) continue;
        if (pose.difficulty.index > maxRank) continue;
        items.add(YogaPlanItem(pose: pose, durationSec: seconds));
      }
    }
    return YogaRoutine(kind: kind, difficulty: difficulty, items: items);
  }

  /// The sequence keys for a [kind], exposed for tests.
  static List<String> keysFor(YogaRoutineKind kind) {
    final sequence = _sequences[kind];
    if (sequence == null) return const [];
    return [for (final (key, _) in sequence) key];
  }
}
