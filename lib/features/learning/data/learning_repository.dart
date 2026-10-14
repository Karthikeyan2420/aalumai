import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/providers/providers.dart';
import 'curriculum.dart';

class LearningRepository {
  LearningRepository(this._db);

  final AppDatabase _db;

  /// Seeds the Tamil→English beginner course once. Safe to call repeatedly.
  Future<void> seedCourse() async {
    final existing = await _db.select(_db.learningCourses).get();
    if (existing.isNotEmpty) return;
    await _db.transaction(() async {
      final courseId = await _db
          .into(_db.learningCourses)
          .insert(
            LearningCoursesCompanion.insert(
              title: 'Tamil to English — Beginner (30 days)',
              sourceLang: const Value('ta'),
              targetLang: const Value('en'),
              level: const Value(0),
              description: const Value(
                'A 30-day beginner course: 5 words, a grammar point and practice every day.',
              ),
            ),
          );
      final rng = Random(7);
      for (final lesson in kTamilEnglishCourse) {
        final lessonId = await _db
            .into(_db.lessons)
            .insert(
              LessonsCompanion.insert(
                courseId: courseId,
                dayNumber: lesson.day,
                title: lesson.title,
                orderIndex: Value(lesson.day),
                grammarJson: Value(
                  jsonEncode({
                    'title': lesson.grammarTitle,
                    'explanationTa': lesson.grammarTa,
                    'sentencesEn': lesson.sentencesEn,
                    'sentencesTa': lesson.sentencesTa,
                  }),
                ),
              ),
            );
        for (var i = 0; i < lesson.words.length; i++) {
          final w = lesson.words[i];
          final vocabId = await _db
              .into(_db.vocabulary)
              .insert(
                VocabularyCompanion.insert(
                  lessonId: Value(lessonId),
                  word: w.word,
                  meaningTa: Value(w.meaningTa),
                  pronunciationTa: Value(w.pron),
                  exampleEn: Value(w.exampleEn),
                  exampleTa: Value(w.exampleTa),
                  level: const Value(0),
                  orderIndex: Value(i),
                ),
              );
          await _db
              .into(_db.vocabReviews)
              .insert(
                VocabReviewsCompanion.insert(
                  vocabId: vocabId,
                  easeFactor: const Value(2.5),
                  intervalDays: const Value(0),
                  repetitions: const Value(0),
                  dueDate: DateTime.now(),
                ),
              );
          // Derive a word→meaning question from real data.
          final distractors = <String>[];
          final pool = List.of(lesson.words);
          while (distractors.length < 3 && pool.length > 1) {
            final cand = pool[rng.nextInt(pool.length)];
            if (cand.meaningTa != w.meaningTa &&
                !distractors.contains(cand.meaningTa)) {
              distractors.add(cand.meaningTa);
            }
          }
          final options = [w.meaningTa, ...distractors]..shuffle(rng);
          await _db
              .into(_db.learningExercises)
              .insert(
                LearningExercisesCompanion.insert(
                  lessonId: lessonId,
                  type: const Value(0),
                  question: w.word,
                  optionsJson: Value(jsonEncode(options)),
                  answer: w.meaningTa,
                  explanationTa: Value(w.exampleTa),
                  orderIndex: Value(i),
                ),
              );
        }
        await _db
            .into(_db.learningProgress)
            .insert(LearningProgressCompanion.insert(lessonId: lessonId));
      }
    });
  }

  Stream<List<LearningCourse>> watchCourses() =>
      (_db.select(_db.learningCourses)
        ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)])).watch();

  Stream<List<Lesson>> watchLessons(int courseId) =>
      (_db.select(_db.lessons)
            ..where((t) => t.courseId.equals(courseId))
            ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
          .watch();

  Future<Lesson?> getLesson(int id) =>
      (_db.select(_db.lessons)
        ..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<VocabularyData?> vocabById(int id) =>
      (_db.select(_db.vocabulary)
        ..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<VocabularyData>> watchVocab(int lessonId) =>
      (_db.select(_db.vocabulary)
            ..where((t) => t.lessonId.equals(lessonId))
            ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
          .watch();

  Future<List<LearningExercise>> exercisesFor(int lessonId) =>
      (_db.select(_db.learningExercises)
            ..where((t) => t.lessonId.equals(lessonId))
            ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
          .get();

  Future<void> recordAttempt({
    required int exerciseId,
    required bool correct,
    required String userAnswer,
  }) {
    return _db
        .into(_db.learningAttempts)
        .insert(
          LearningAttemptsCompanion.insert(
            exerciseId: exerciseId,
            isCorrect: correct,
            userAnswer: Value(userAnswer),
          ),
        );
  }

  Future<LearningProgressData?> progressFor(int lessonId) =>
      (_db.select(_db.learningProgress)
        ..where((t) => t.lessonId.equals(lessonId))).getSingleOrNull();

  Future<void> completeLesson(int lessonId, int score) async {
    await (_db.update(_db.learningProgress)
      ..where((t) => t.lessonId.equals(lessonId))).write(
      LearningProgressCompanion(
        isCompleted: const Value(true),
        score: Value(score),
        completedAt: Value(DateTime.now()),
      ),
    );
  }

  // ---- Spaced repetition (SM-2 lite) -------------------------------------

  Stream<List<VocabReview>> watchDueReviews() {
    final now = DateTime.now();
    return (_db.select(_db.vocabReviews)
          ..where((t) => t.dueDate.isSmallerOrEqualValue(now))
          ..orderBy([(t) => OrderingTerm(expression: t.dueDate)]))
        .watch();
  }

  Future<int> dueReviewCount() async {
    final now = DateTime.now();
    final rows =
        await (_db.select(_db.vocabReviews)
          ..where((t) => t.dueDate.isSmallerOrEqualValue(now))).get();
    return rows.length;
  }

  /// Applies an SM-2-style update. [quality] 0–5 (>=3 considered correct).
  Future<void> reviewVocab(int vocabId, int quality) async {
    final review =
        await (_db.select(_db.vocabReviews)
          ..where((t) => t.vocabId.equals(vocabId))).getSingleOrNull();
    if (review == null) return;
    var ease = review.easeFactor;
    var reps = review.repetitions;
    var interval = review.intervalDays;
    if (quality < 3) {
      reps = 0;
      interval = 1;
    } else {
      if (reps == 0) {
        interval = 1;
      } else if (reps == 1) {
        interval = 6;
      } else {
        interval = (interval * ease).round();
      }
      reps += 1;
    }
    ease = (ease + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))).clamp(
      1.3,
      2.8,
    );
    await (_db.update(_db.vocabReviews)
      ..where((t) => t.id.equals(review.id))).write(
      VocabReviewsCompanion(
        easeFactor: Value(ease),
        repetitions: Value(reps),
        intervalDays: Value(interval),
        dueDate: Value(DateTime.now().add(Duration(days: interval))),
        lastReviewedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> recordPronunciation({
    required int vocabId,
    required String recognizedText,
    required int score,
  }) {
    return _db
        .into(_db.pronunciationAttempts)
        .insert(
          PronunciationAttemptsCompanion.insert(
            vocabId: vocabId,
            recognizedText: Value(recognizedText),
            score: Value(score),
          ),
        );
  }

  /// Number of consecutive days with at least one learning attempt.
  Future<int> studyStreak() async {
    final attempts = await _db.select(_db.learningAttempts).get();
    final days =
        attempts
            .map(
              (a) => DateTime(
                a.createdAt.year,
                a.createdAt.month,
                a.createdAt.day,
              ),
            )
            .toSet();
    var streak = 0;
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    var graceUsed = false;
    for (var i = 0; i < 3650; i++) {
      if (days.contains(cursor)) {
        streak++;
      } else if (!graceUsed) {
        graceUsed = true;
      } else {
        break;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

final learningRepositoryProvider = Provider<LearningRepository>(
  (ref) => LearningRepository(ref.watch(appDatabaseProvider)),
);

final coursesProvider = StreamProvider<List<LearningCourse>>(
  (ref) => ref.watch(learningRepositoryProvider).watchCourses(),
);
