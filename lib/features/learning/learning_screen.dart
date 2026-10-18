import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/db/database.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/widgets/common.dart';
import 'data/curriculum.dart';
import 'data/learning_repository.dart';

class LearningScreen extends ConsumerWidget {
  const LearningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final courses = ref.watch(coursesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.learnEnglish),
        actions: [
          IconButton(
            tooltip: l10n.reviewDue,
            icon: const Icon(Icons.replay_circle_filled_outlined),
            onPressed:
                () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ReviewScreen())),
          ),
        ],
      ),
      body: courses.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.menu_book_outlined,
              message: 'No courses available.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const _StreakHeader(),
              for (final course in list)
                Card(
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: const CircleAvatar(child: Icon(Icons.school)),
                    title: Text(course.title),
                    subtitle: Text(course.description),
                    trailing: const Icon(Icons.chevron_right),
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LessonListScreen(course: course),
                          ),
                        ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StreakHeader extends ConsumerWidget {
  const _StreakHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final streak = ref.watch(_studyStreakProvider);
    final due = ref.watch(_dueCountProvider);
    return SectionCard(
      title: l10n.progress,
      icon: Icons.local_fire_department,
      child: Row(
        children: [
          Expanded(
            child: _Metric(
              value: streak.valueOrNull?.toString() ?? '—',
              label: l10n.streakDays,
            ),
          ),
          Expanded(
            child: _Metric(
              value: due.valueOrNull?.toString() ?? '—',
              label: l10n.reviewDue,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.headlineSmall),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

final _studyStreakProvider = FutureProvider<int>(
  (ref) => ref.watch(learningRepositoryProvider).studyStreak(),
);

final _dueCountProvider = FutureProvider<int>(
  (ref) => ref.watch(learningRepositoryProvider).dueReviewCount(),
);

class LessonListScreen extends ConsumerWidget {
  const LessonListScreen({super.key, required this.course});
  final LearningCourse course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessons = ref.watch(_lessonsProvider(course.id));
    return Scaffold(
      appBar: AppBar(title: Text(course.title)),
      body: lessons.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data:
            (list) => ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final lesson = list[i];
                return Card(
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: CircleAvatar(child: Text('${lesson.dayNumber}')),
                    title: Text(lesson.title),
                    trailing: const Icon(Icons.chevron_right),
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LessonDetailScreen(lesson: lesson),
                          ),
                        ),
                  ),
                );
              },
            ),
      ),
    );
  }
}

final _lessonsProvider = StreamProvider.family<List<Lesson>, int>(
  (ref, courseId) =>
      ref.watch(learningRepositoryProvider).watchLessons(courseId),
);

class LessonDetailScreen extends ConsumerWidget {
  const LessonDetailScreen({super.key, required this.lesson});
  final Lesson lesson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final grammar = learningGrammar(lesson.grammarJson);
    final vocab = ref.watch(_vocabProvider(lesson.id));
    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'learningPractice',
        onPressed:
            () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => QuizScreen(lessonId: lesson.id),
              ),
            ),
        icon: const Icon(Icons.quiz_outlined),
        label: Text(l10n.practice),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          if (grammar != null)
            SectionCard(
              title: l10n.grammar,
              icon: Icons.rule,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    grammar.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(grammar.explanationTa),
                  if (grammar.sentencesEn.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    for (var i = 0; i < grammar.sentencesEn.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• ${grammar.sentencesEn[i]}'),
                      ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(l10n.vocabulary, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          vocab.when(
            loading: () => const LoadingState(),
            error: (e, _) => ErrorState(message: e.toString()),
            data:
                (words) => Column(
                  children: [for (final w in words) _VocabTile(word: w)],
                ),
          ),
        ],
      ),
    );
  }
}

final _vocabProvider = StreamProvider.family<List<VocabularyData>, int>((
  ref,
  lessonId,
) {
  return ref.watch(learningRepositoryProvider).watchVocab(lessonId);
});

class _VocabTile extends ConsumerStatefulWidget {
  const _VocabTile({required this.word});
  final VocabularyData word;

  @override
  ConsumerState<_VocabTile> createState() => _VocabTileState();
}

class _VocabTileState extends ConsumerState<_VocabTile> {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _speech = SpeechToText();
  String? _heard;

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.4);
      await _tts.speak(widget.word.word);
    } catch (_) {}
  }

  Future<void> _listen() async {
    final l10n = context.l10n;
    try {
      final available = await _speech.initialize();
      if (!available) {
        _snack(l10n.microphonePermission);
        return;
      }
      await _speech.listen(
        onResult: (r) async {
          final heard = r.recognizedWords.toLowerCase();
          setState(() => _heard = r.recognizedWords);
          if (r.finalResult) {
            final target = widget.word.word.toLowerCase();
            final score =
                heard == target
                    ? 100
                    : (heard.contains(target) || target.contains(heard)
                        ? 70
                        : 30);
            await ref
                .read(learningRepositoryProvider)
                .recordPronunciation(
                  vocabId: widget.word.id,
                  recognizedText: r.recognizedWords,
                  score: score,
                );
          }
        },
      );
    } catch (_) {
      _snack(l10n.microphonePermission);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final w = widget.word;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        w.word,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${w.meaningTa} · ${w.pronunciationTa}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _speak,
                  tooltip: l10n.speak,
                  icon: const Icon(Icons.volume_up_outlined),
                ),
                IconButton(
                  onPressed: _listen,
                  tooltip: l10n.pronunciation,
                  icon: const Icon(Icons.mic_none),
                ),
              ],
            ),
            if (w.exampleEn.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${w.exampleEn}\n${w.exampleTa}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (_heard != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${l10n.listen}: $_heard',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key, required this.lessonId});
  final int lessonId;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  List<LearningExercise>? _exercises;
  int _index = 0;
  int _correct = 0;
  String? _chosen;

  @override
  void initState() {
    super.initState();
    ref.read(learningRepositoryProvider).exercisesFor(widget.lessonId).then((
      list,
    ) {
      if (mounted) setState(() => _exercises = list);
    });
  }

  List<String> _options(LearningExercise e) {
    final raw = e.optionsJson;
    if (raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((o) => o.toString()).toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _answer(LearningExercise e, String option) async {
    if (_chosen != null) return;
    final isCorrect = option == e.answer;
    setState(() {
      _chosen = option;
      if (isCorrect) _correct++;
    });
    await ref
        .read(learningRepositoryProvider)
        .recordAttempt(
          exerciseId: e.id,
          correct: isCorrect,
          userAnswer: option,
        );
  }

  void _next() {
    final total = _exercises?.length ?? 0;
    if (_index + 1 >= total) {
      _finish();
      return;
    }
    setState(() {
      _index++;
      _chosen = null;
    });
  }

  Future<void> _finish() async {
    final total = _exercises?.length ?? 0;
    final score = total == 0 ? 0 : ((_correct / total) * 100).round();
    await ref
        .read(learningRepositoryProvider)
        .completeLesson(widget.lessonId, score);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(context.l10n.progress),
            content: Text('$_correct / $total'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.done),
              ),
            ],
          ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final exercises = _exercises;
    if (exercises == null) {
      return Scaffold(appBar: AppBar(), body: const LoadingState());
    }
    if (exercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.quiz)),
        body: const EmptyState(
          icon: Icons.quiz_outlined,
          message: 'No practice questions.',
        ),
      );
    }
    final e = exercises[_index];
    final options = _options(e);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.quiz),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_index + 1) / exercises.length,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${_index + 1}/${exercises.length}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Text(
            e.question,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OptionButton(
                label: option,
                state:
                    _chosen == null
                        ? _OptionState.idle
                        : option == e.answer
                        ? _OptionState.correct
                        : option == _chosen
                        ? _OptionState.wrong
                        : _OptionState.idle,
                onTap: () => _answer(e, option),
              ),
            ),
          if (_chosen != null) ...[
            const SizedBox(height: 8),
            if (e.explanationTa.isNotEmpty)
              Text(
                e.explanationTa,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _next,
              child: Text(
                _index + 1 >= exercises.length ? l10n.finish : l10n.next,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _OptionState { idle, correct, wrong }

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.state,
    required this.onTap,
  });
  final String label;
  final _OptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color color;
    switch (state) {
      case _OptionState.correct:
        color = theme.colorScheme.secondaryContainer;
      case _OptionState.wrong:
        color = theme.colorScheme.errorContainer;
      case _OptionState.idle:
        color = theme.colorScheme.surfaceContainerHighest;
    }
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(child: Text(label)),
              if (state == _OptionState.correct) const Icon(Icons.check_circle),
              if (state == _OptionState.wrong) const Icon(Icons.cancel),
            ],
          ),
        ),
      ),
    );
  }
}

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  Future<void> _review(int vocabId, int quality) async {
    await ref.read(learningRepositoryProvider).reviewVocab(vocabId, quality);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final due = ref.watch(_dueReviewsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviewDue)),
      body: due.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (reviews) {
          if (reviews.isEmpty) {
            return EmptyState(
              icon: Icons.check_circle_outline,
              message: l10n.all,
            );
          }
          final review = reviews.first;
          return _ReviewCard(
            vocabId: review.vocabId,
            onGrade: (q) => _review(review.vocabId, q),
          );
        },
      ),
    );
  }
}

final _dueReviewsProvider = StreamProvider<List<VocabReview>>(
  (ref) => ref.watch(learningRepositoryProvider).watchDueReviews(),
);

class _ReviewCard extends ConsumerWidget {
  const _ReviewCard({required this.vocabId, required this.onGrade});
  final int vocabId;
  final ValueChanged<int> onGrade;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final vocab = ref.watch(_vocabByIdProvider(vocabId));
    return vocab.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(message: e.toString()),
      data: (word) {
        if (word == null) {
          return EmptyState(
            icon: Icons.check_circle_outline,
            message: l10n.all,
          );
        }
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(word.word, style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(
                '${word.meaningTa} · ${word.pronunciationTa}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 32),
              Text(
                l10n.pronunciationGuide,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final q in const [
                    (0, Icons.sentiment_very_dissatisfied),
                    (2, Icons.sentiment_dissatisfied),
                    (3, Icons.sentiment_neutral),
                    (4, Icons.sentiment_satisfied),
                    (5, Icons.sentiment_very_satisfied),
                  ])
                    OutlinedButton(
                      onPressed: () => onGrade(q.$1),
                      child: Icon(q.$2),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

final _vocabByIdProvider = FutureProvider.family<VocabularyData?, int>((
  ref,
  id,
) async {
  final repo = ref.watch(learningRepositoryProvider);
  return repo.vocabById(id);
});
