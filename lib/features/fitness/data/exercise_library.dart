/// Starter exercise library bundled offline with the app.
///
/// Categories: 0 arms, 1 shoulders, 2 chest, 3 back, 4 legs, 5 core,
/// 6 cardio, 7 yoga/mobility, 8 warm-up/cool-down.
/// Difficulty: 0 beginner, 1 intermediate, 2 advanced.
class ExerciseSeed {
  const ExerciseSeed({
    required this.name,
    required this.category,
    required this.targetMuscles,
    required this.equipment,
    required this.difficulty,
    required this.instructions,
    required this.safetyNotes,
    this.isTimed = false,
    this.sets = 3,
    this.reps = 10,
    this.durationSec = 0,
    this.restSec = 60,
  });

  final String name;
  final int category;
  final String targetMuscles;
  final String equipment;
  final int difficulty;
  final String instructions;
  final String safetyNotes;
  final bool isTimed;
  final int sets;
  final int reps;
  final int durationSec;
  final int restSec;
}

const kExerciseLibrary = <ExerciseSeed>[
  // --- Warm-up / cool-down (8) ---
  ExerciseSeed(
    name: 'Marching in place',
    category: 8,
    targetMuscles: 'Full body',
    equipment: 'None',
    difficulty: 0,
    instructions:
        'March on the spot, lifting knees to hip height and swinging the arms.',
    safetyNotes: 'Keep it gentle; stop if you feel dizzy.',
    isTimed: true,
    durationSec: 60,
    restSec: 20,
  ),
  ExerciseSeed(
    name: 'Arm circles',
    category: 8,
    targetMuscles: 'Shoulders',
    equipment: 'None',
    difficulty: 0,
    instructions:
        'Extend arms sideways and make small circles, then medium, then large. Reverse direction halfway.',
    safetyNotes: 'Avoid shrugging; keep shoulders relaxed.',
    isTimed: true,
    durationSec: 45,
    restSec: 15,
  ),
  ExerciseSeed(
    name: 'Leg swings',
    category: 8,
    targetMuscles: 'Hips, hamstrings',
    equipment: 'None',
    difficulty: 0,
    instructions:
        'Hold a wall and swing one leg forward and back, then repeat on the other side.',
    safetyNotes: 'Control the swing; do not force range.',
    isTimed: true,
    durationSec: 40,
    restSec: 15,
  ),
  ExerciseSeed(
    name: 'Neck and shoulder rolls',
    category: 8,
    targetMuscles: 'Neck, shoulders',
    equipment: 'None',
    difficulty: 0,
    instructions:
        'Slowly roll shoulders back, then gently tilt the head side to side.',
    safetyNotes: 'Never roll the head in a full circle.',
    isTimed: true,
    durationSec: 40,
    restSec: 15,
  ),
  ExerciseSeed(
    name: 'Cat-cow stretch',
    category: 8,
    targetMuscles: 'Spine, core',
    equipment: 'Mat',
    difficulty: 0,
    instructions:
        'On all fours, alternate arching and rounding the spine with the breath.',
    safetyNotes: 'Move within a pain-free range.',
    sets: 2,
    reps: 10,
    restSec: 30,
  ),
  ExerciseSeed(
    name: 'Standing hamstring stretch',
    category: 8,
    targetMuscles: 'Hamstrings',
    equipment: 'None',
    difficulty: 0,
    instructions:
        'Place one heel forward, hinge at the hips and hold for 20–30 seconds per side.',
    safetyNotes: 'Keep the back straight; do not bounce.',
    isTimed: true,
    durationSec: 60,
    restSec: 10,
  ),
  ExerciseSeed(
    name: 'Hip flexor stretch',
    category: 8,
    targetMuscles: 'Hip flexors',
    equipment: 'Mat',
    difficulty: 0,
    instructions:
        'In a half-kneeling position, tuck the pelvis and lean forward gently. Hold 30s per side.',
    safetyNotes: 'Place padding under the knee.',
    isTimed: true,
    durationSec: 60,
    restSec: 10,
  ),
  ExerciseSeed(
    name: 'Child\'s pose',
    category: 8,
    targetMuscles: 'Back, shoulders',
    equipment: 'Mat',
    difficulty: 0,
    instructions:
        'Kneel, sit back on the heels, extend arms forward and rest the forehead down.',
    safetyNotes: 'Use a cushion under the hips if uncomfortable.',
    isTimed: true,
    durationSec: 60,
    restSec: 0,
  ),

  // --- Core (6) ---
  ExerciseSeed(
    name: 'Forearm plank',
    category: 5,
    targetMuscles: 'Core',
    equipment: 'Mat',
    difficulty: 0,
    instructions:
        'Rest on forearms and toes, keep a straight line from head to heels, brace the abs.',
    safetyNotes: 'Do not let the hips sag; stop if the lower back hurts.',
    isTimed: true,
    durationSec: 30,
    restSec: 45,
  ),
  ExerciseSeed(
    name: 'Crunches',
    category: 5,
    targetMuscles: 'Upper abs',
    equipment: 'Mat',
    difficulty: 0,
    instructions:
        'Lie on the back, knees bent, curl the shoulders off the floor and lower slowly.',
    safetyNotes: 'Do not pull on the neck.',
    sets: 3,
    reps: 15,
    restSec: 45,
  ),
  ExerciseSeed(
    name: 'Bicycle crunches',
    category: 5,
    targetMuscles: 'Obliques',
    equipment: 'Mat',
    difficulty: 1,
    instructions:
        'Alternate touching elbow to opposite knee in a smooth pedalling motion.',
    safetyNotes: 'Slow and controlled beats fast and sloppy.',
    sets: 3,
    reps: 20,
    restSec: 45,
  ),
  ExerciseSeed(
    name: 'Leg raises',
    category: 5,
    targetMuscles: 'Lower abs',
    equipment: 'Mat',
    difficulty: 1,
    instructions:
        'Lie flat, lift straight legs to 90 degrees and lower without touching the floor.',
    safetyNotes: 'Keep the lower back pressed down; bend knees if needed.',
    sets: 3,
    reps: 12,
    restSec: 45,
  ),
  ExerciseSeed(
    name: 'Dead bug',
    category: 5,
    targetMuscles: 'Deep core',
    equipment: 'Mat',
    difficulty: 0,
    instructions:
        'On the back, extend opposite arm and leg while keeping the back flat.',
    safetyNotes: 'Move slowly and keep ribs down.',
    sets: 3,
    reps: 10,
    restSec: 40,
  ),
  ExerciseSeed(
    name: 'Russian twists',
    category: 5,
    targetMuscles: 'Obliques',
    equipment: 'None',
    difficulty: 1,
    instructions:
        'Sit with knees bent, lean back slightly and rotate the torso side to side.',
    safetyNotes: 'Keep the chest lifted; avoid rounding the back.',
    sets: 3,
    reps: 20,
    restSec: 45,
  ),

  // --- Legs (6) ---
  ExerciseSeed(
    name: 'Bodyweight squats',
    category: 4,
    targetMuscles: 'Quads, glutes',
    equipment: 'None',
    difficulty: 0,
    instructions:
        'Stand feet shoulder-width, sit back and down, then drive up through the heels.',
    safetyNotes: 'Keep knees tracking over toes; chest up.',
    sets: 3,
    reps: 15,
    restSec: 60,
  ),
  ExerciseSeed(
    name: 'Lunges',
    category: 4,
    targetMuscles: 'Quads, glutes',
    equipment: 'None',
    difficulty: 0,
    instructions:
        'Step forward, lower until both knees are near 90 degrees, then push back.',
    safetyNotes: 'Keep the torso upright and front knee over the ankle.',
    sets: 3,
    reps: 12,
    restSec: 60,
  ),
  ExerciseSeed(
    name: 'Glute bridge',
    category: 4,
    targetMuscles: 'Glutes, hamstrings',
    equipment: 'Mat',
    difficulty: 0,
    instructions:
        'Lie on the back, knees bent, drive the hips up and squeeze the glutes.',
    safetyNotes: 'Do not over-arch the lower back.',
    sets: 3,
    reps: 15,
    restSec: 45,
  ),
  ExerciseSeed(
    name: 'Dumbbell goblet squat',
    category: 4,
    targetMuscles: 'Quads, glutes',
    equipment: 'One dumbbell',
    difficulty: 1,
    instructions:
        'Hold a dumbbell at the chest and squat down, keeping the elbows inside the knees.',
    safetyNotes: 'Start light and focus on form.',
    sets: 3,
    reps: 12,
    restSec: 75,
  ),
  ExerciseSeed(
    name: 'Dumbbell Romanian deadlift',
    category: 4,
    targetMuscles: 'Hamstrings, glutes',
    equipment: 'Two dumbbells',
    difficulty: 1,
    instructions:
        'Hinge at the hips with a slight knee bend, lower the weights along the legs and stand tall.',
    safetyNotes: 'Keep the back neutral; feel the stretch in the hamstrings.',
    sets: 3,
    reps: 10,
    restSec: 75,
  ),
  ExerciseSeed(
    name: 'Calf raises',
    category: 4,
    targetMuscles: 'Calves',
    equipment: 'None',
    difficulty: 0,
    instructions:
        'Rise onto the balls of the feet and lower slowly under control.',
    safetyNotes: 'Hold a wall for balance if needed.',
    sets: 3,
    reps: 20,
    restSec: 40,
  ),

  // --- Chest (4) ---
  ExerciseSeed(
    name: 'Knee push-ups',
    category: 2,
    targetMuscles: 'Chest, triceps',
    equipment: 'Mat',
    difficulty: 0,
    instructions:
        'On knees and hands, lower the chest to the floor and press back up.',
    safetyNotes: 'Keep the body in a straight line from knees to head.',
    sets: 3,
    reps: 12,
    restSec: 60,
  ),
  ExerciseSeed(
    name: 'Push-ups',
    category: 2,
    targetMuscles: 'Chest, triceps, shoulders',
    equipment: 'None',
    difficulty: 1,
    instructions:
        'From a plank, lower until the chest is near the floor and press up.',
    safetyNotes: 'Keep the core braced; do not flare the elbows out fully.',
    sets: 3,
    reps: 12,
    restSec: 60,
  ),
  ExerciseSeed(
    name: 'Dumbbell floor press',
    category: 2,
    targetMuscles: 'Chest, triceps',
    equipment: 'Two dumbbells',
    difficulty: 1,
    instructions:
        'Lie on the floor, press the dumbbells up from the chest and lower with control.',
    safetyNotes: 'Keep wrists over elbows.',
    sets: 3,
    reps: 12,
    restSec: 60,
  ),
  ExerciseSeed(
    name: 'Incline push-ups',
    category: 2,
    targetMuscles: 'Chest',
    equipment: 'Bench/step',
    difficulty: 0,
    instructions:
        'Place hands on a raised surface and perform push-ups at an easier angle.',
    safetyNotes: 'Use a stable surface.',
    sets: 3,
    reps: 12,
    restSec: 60,
  ),

  // --- Back (4) ---
  ExerciseSeed(
    name: 'Superman',
    category: 3,
    targetMuscles: 'Lower back, glutes',
    equipment: 'Mat',
    difficulty: 0,
    instructions:
        'Lie face down, lift arms and legs off the floor, hold briefly and lower.',
    safetyNotes: 'Lift only as high as comfortable.',
    sets: 3,
    reps: 12,
    restSec: 45,
  ),
  ExerciseSeed(
    name: 'Dumbbell bent-over row',
    category: 3,
    targetMuscles: 'Back, biceps',
    equipment: 'Two dumbbells',
    difficulty: 1,
    instructions:
        'Hinge forward, row the dumbbells to the ribs and lower with control.',
    safetyNotes: 'Keep a flat back throughout.',
    sets: 3,
    reps: 10,
    restSec: 75,
  ),
  ExerciseSeed(
    name: 'Reverse snow angels',
    category: 3,
    targetMuscles: 'Upper back',
    equipment: 'Mat',
    difficulty: 0,
    instructions:
        'Lie face down and sweep the arms from hips to overhead just off the floor.',
    safetyNotes: 'Keep movements slow.',
    sets: 2,
    reps: 12,
    restSec: 40,
  ),
  ExerciseSeed(
    name: 'Bird dog',
    category: 3,
    targetMuscles: 'Lower back, core',
    equipment: 'Mat',
    difficulty: 0,
    instructions:
        'On all fours, extend opposite arm and leg and hold, then switch.',
    safetyNotes: 'Keep hips level; avoid rotating the torso.',
    sets: 3,
    reps: 10,
    restSec: 40,
  ),

  // --- Arms (4) ---
  ExerciseSeed(
    name: 'Dumbbell bicep curls',
    category: 0,
    targetMuscles: 'Biceps',
    equipment: 'Two dumbbells',
    difficulty: 0,
    instructions:
        'Curl the dumbbells to the shoulders and lower under control, elbows pinned.',
    safetyNotes: 'Avoid swinging the body.',
    sets: 3,
    reps: 12,
    restSec: 60,
  ),
  ExerciseSeed(
    name: 'Tricep dips on a chair',
    category: 0,
    targetMuscles: 'Triceps',
    equipment: 'Chair/bench',
    difficulty: 1,
    instructions:
        'With hands on the edge behind you, lower the hips by bending the elbows and press up.',
    safetyNotes:
        'Keep the back close to the chair; stop if the shoulders hurt.',
    sets: 3,
    reps: 10,
    restSec: 60,
  ),
  ExerciseSeed(
    name: 'Dumbbell hammer curls',
    category: 0,
    targetMuscles: 'Biceps, forearms',
    equipment: 'Two dumbbells',
    difficulty: 0,
    instructions: 'Curl with a neutral (thumbs-up) grip and lower slowly.',
    safetyNotes: 'Keep elbows still.',
    sets: 3,
    reps: 12,
    restSec: 60,
  ),
  ExerciseSeed(
    name: 'Overhead tricep extension',
    category: 0,
    targetMuscles: 'Triceps',
    equipment: 'One dumbbell',
    difficulty: 1,
    instructions:
        'Hold one dumbbell overhead with both hands and lower behind the head, then extend.',
    safetyNotes: 'Keep elbows pointing forward.',
    sets: 3,
    reps: 12,
    restSec: 60,
  ),

  // --- Shoulders (3) ---
  ExerciseSeed(
    name: 'Dumbbell shoulder press',
    category: 1,
    targetMuscles: 'Shoulders',
    equipment: 'Two dumbbells',
    difficulty: 1,
    instructions:
        'Press the dumbbells overhead from shoulder height and lower with control.',
    safetyNotes: 'Do not arch the lower back.',
    sets: 3,
    reps: 10,
    restSec: 75,
  ),
  ExerciseSeed(
    name: 'Lateral raises',
    category: 1,
    targetMuscles: 'Side delts',
    equipment: 'Two dumbbells',
    difficulty: 0,
    instructions:
        'Raise the dumbbells to shoulder height with a slight elbow bend and lower slowly.',
    safetyNotes: 'Use light weight; avoid shrugging.',
    sets: 3,
    reps: 12,
    restSec: 60,
  ),
  ExerciseSeed(
    name: 'Wall shoulder taps',
    category: 1,
    targetMuscles: 'Shoulders, core',
    equipment: 'None',
    difficulty: 0,
    instructions:
        'In a high plank against a wall, tap each shoulder with the opposite hand.',
    safetyNotes: 'Keep hips stable.',
    sets: 3,
    reps: 16,
    restSec: 45,
  ),

  // --- Cardio (3) ---
  ExerciseSeed(
    name: 'Jumping jacks',
    category: 6,
    targetMuscles: 'Full body',
    equipment: 'None',
    difficulty: 0,
    instructions:
        'Jump the feet out while raising the arms overhead, then back in.',
    safetyNotes: 'Land softly with bent knees.',
    isTimed: true,
    durationSec: 45,
    restSec: 30,
  ),
  ExerciseSeed(
    name: 'High knees',
    category: 6,
    targetMuscles: 'Full body, hip flexors',
    equipment: 'None',
    difficulty: 1,
    instructions: 'Run in place driving the knees as high as comfortable.',
    safetyNotes: 'Stay on the balls of the feet.',
    isTimed: true,
    durationSec: 40,
    restSec: 30,
  ),
  ExerciseSeed(
    name: 'Mountain climbers',
    category: 6,
    targetMuscles: 'Core, cardio',
    equipment: 'Mat',
    difficulty: 1,
    instructions:
        'From a plank, alternate driving the knees toward the chest quickly.',
    safetyNotes: 'Keep the hips low and back flat.',
    isTimed: true,
    durationSec: 40,
    restSec: 40,
  ),

  // --- Yoga / mobility (4) ---
  ExerciseSeed(
    name: 'Downward dog',
    category: 7,
    targetMuscles: 'Hamstrings, shoulders',
    equipment: 'Mat',
    difficulty: 0,
    instructions:
        'From all fours, lift the hips up and back, forming an inverted V. Pedal the feet.',
    safetyNotes: 'Bend the knees if hamstrings are tight.',
    isTimed: true,
    durationSec: 45,
    restSec: 15,
  ),
  ExerciseSeed(
    name: 'Warrior II',
    category: 7,
    targetMuscles: 'Legs, hips',
    equipment: 'Mat',
    difficulty: 0,
    instructions:
        'Step the feet wide, bend the front knee, extend the arms and gaze over the front hand. Hold each side.',
    safetyNotes: 'Keep the front knee over the ankle.',
    isTimed: true,
    durationSec: 60,
    restSec: 15,
  ),
  ExerciseSeed(
    name: 'Seated forward fold',
    category: 7,
    targetMuscles: 'Hamstrings, back',
    equipment: 'Mat',
    difficulty: 0,
    instructions:
        'Sit with legs extended and hinge forward from the hips, reaching toward the feet.',
    safetyNotes: 'Do not force; keep breathing.',
    isTimed: true,
    durationSec: 45,
    restSec: 15,
  ),
  ExerciseSeed(
    name: 'World\'s greatest stretch',
    category: 7,
    targetMuscles: 'Hips, spine',
    equipment: 'Mat',
    difficulty: 1,
    instructions:
        'From a lunge, place the same-side hand down, rotate and reach the other arm to the sky. Alternate sides.',
    safetyNotes: 'Move slowly and control the rotation.',
    sets: 2,
    reps: 8,
    restSec: 30,
  ),
];
