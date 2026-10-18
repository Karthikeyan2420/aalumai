// One-off helper that appends the alarm/workout/music UI strings to every ARB
// file. Existing keys are preserved; new keys are added with English text in
// the non-English locales (to be translated later). Run from the project root:
//
//   dart run tool/add_l10n_keys.dart
import 'dart:convert';
import 'dart:io';

const _newKeys = <String, String>{
  // Alarm
  'oneTime': 'One-time',
  'repeatDays': 'Repeat',
  'volume': 'Volume',
  'vibrate': 'Vibrate',
  'maxSnoozes': 'Max snoozes',
  'unlimited': 'Unlimited',
  'duplicate': 'Duplicate',
  'upcomingAlarms': 'Upcoming alarms',
  'nextRing': 'Next ring',
  'soundClassic': 'Classic beep',
  'soundGentle': 'Gentle chime',
  'soundUrgent': 'Urgent',
  'soundSystem': 'System default',
  'snoozeDuration': 'Snooze length',
  'ringsTomorrow': 'Tomorrow',
  'noUpcomingAlarms': 'No upcoming alarms.',
  'previewSound': 'Preview sound',
  // Workout
  'quickWorkout': 'Quick workout',
  'chooseExercises': 'Choose exercises',
  'newWorkout': 'New workout',
  'elapsed': 'Elapsed',
  'logSet': 'Log set',
  'completeSet': 'Complete set',
  'previousExercise': 'Previous',
  'nextExercise': 'Next',
  'workoutSummary': 'Workout summary',
  'exercisesCompleted': 'Exercises completed',
  'setsCompleted': 'Sets completed',
  'totalReps': 'Total reps',
  'skippedExercises': 'Skipped exercises',
  'restComplete': 'Rest complete',
  'workoutPaused': 'Workout paused',
  'resumeWorkout': 'Resume workout',
  'endWorkout': 'End workout',
  'restartWorkout': 'Restart workout',
  'ready': 'Ready',
  'nextUp': 'Next up',
  'workoutInProgress': 'Workout in progress',
  'resumeOrDiscard': 'You have a workout in progress.',
  'discard': 'Discard',
  'actualReps': 'Actual reps',
  'weightUsed': 'Weight (kg)',
  'targetReps': 'Target reps',
  'timed': 'Timed',
  'startRest': 'Start rest',
  'setDone': 'Set done',
  'markSetDone': 'Mark set done',
  'completeWorkout': 'Complete workout',
  'workoutSaved': 'Workout saved',
  'totalTime': 'Total time',
  'resting': 'Resting',
  'workSet': 'Work',
  'go': 'Go',
  'resumeLastWorkout': 'Resume last workout',
  'planProgress': 'Plan progress',
  'exercise': 'Exercise',
  'emptyWorkoutExercises': 'Add or select at least one exercise to start.',
  'newExercise': 'New exercise',
  'timedExercise': 'Timed exercise',
  'noSetsLogged': 'No sets were logged for this workout.',
  // Exercise categories
  'armsLabel': 'Arms',
  'shouldersLabel': 'Shoulders',
  'chestLabel': 'Chest',
  'backLabel': 'Back',
  'legsLabel': 'Legs',
  'coreLabel': 'Core',
  'cardioLabel': 'Cardio',
  'secondsShort': 'sec',
  // Exercise library
  'starterPlans': 'Starter plans',
  'exerciseDetail': 'Exercise',
  'howTo': 'How to do it',
  'reorder': 'Reorder',
  'editItem': 'Edit',
  // Music
  'musicScanFailed':
      "Couldn't scan that folder. Check that access is granted and try again.",
  'musicAccessNeeded':
      'Choose a folder that contains your music. AALUMAI scans files on your device only.',
  'rescan': 'Rescan folders',
  'noMusicYet': 'No music added yet. Add a folder to get started.',
  'musicAddedCount': 'tracks added',
};

void main() {
  final dir = Directory('lib/core/localization/l10n');
  for (final file in dir.listSync().whereType<File>()) {
    if (!file.path.endsWith('.arb')) continue;
    final map =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    var changed = false;
    _newKeys.forEach((key, value) {
      if (!map.containsKey(key)) {
        map[key] = value;
        changed = true;
      }
    });
    if (changed) {
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(map)}\n',
      );
      stdout.writeln('Updated ${file.path}');
    }
  }
}
