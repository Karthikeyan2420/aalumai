/// Memory records and retrieval ranking (pure, testable).
///
/// Rows come from the `jarvis_memories` table via the repository; this
/// layer owns the domain shape and the scoring used to decide what gets
/// injected into the system prompt.
library;

import 'dart:math' as math;

import 'prompt_builder.dart' show estimateTokens;

enum MemoryCategory { fact, preference, goal, person, event, summary }

MemoryCategory memoryCategoryFromDb(String? raw) {
  for (final category in MemoryCategory.values) {
    if (category.name == raw) return category;
  }
  return MemoryCategory.fact;
}

class MemoryRecord {
  const MemoryRecord({
    required this.id,
    required this.content,
    required this.category,
    required this.confirmed,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String content;
  final MemoryCategory category;

  /// true = the user acknowledged this memory (via the memory manager UI
  /// or by saving it explicitly), false = the model saved it on its own.
  final bool confirmed;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class MemoryHit {
  const MemoryHit(this.record, this.score);

  final MemoryRecord record;
  final double score;
}

const Set<String> _stopWords = {
  'the',
  'a',
  'an',
  'is',
  'are',
  'was',
  'were',
  'be',
  'to',
  'of',
  'in',
  'on',
  'at',
  'for',
  'and',
  'or',
  'my',
  'me',
  'i',
  'you',
  'it',
  'that',
  'this',
  'what',
  'when',
  'how',
  'do',
  'does',
  'did',
  'have',
  'has',
  'about',
  'from',
  'with',
};

Set<String> _tokens(String text) => text
    .toLowerCase()
    .split(RegExp(r'[^a-z0-9\u0900-\u097F\u0B80-\u0BFF]+'))
    .where((t) => t.length > 1 && !_stopWords.contains(t))
    .toSet();

/// Ranks [memories] for a natural-language [query].
///
/// Scoring: term overlap with the content (weights by how many query terms
/// hit), a small boost for user-confirmed memories, and a recency boost.
/// An empty query returns everything ordered by recency (used by
/// `memory.search` with no arguments and by the memory manager).
List<MemoryHit> rankMemories({
  required List<MemoryRecord> memories,
  String query = '',
  DateTime? now,
  int limit = 6,
  int tokenBudget = 320,
}) {
  final clock = now ?? DateTime.now();
  final queryTokens = _tokens(query);

  final scored = <MemoryHit>[];
  for (final memory in memories) {
    double score = 0;
    if (query.isEmpty) {
      score = 1; // Recency-only ordering.
    } else {
      final contentTokens = _tokens(memory.content);
      final categoryTokens = _tokens(memory.category.name);
      for (final token in queryTokens) {
        if (contentTokens.contains(token)) {
          score += 3;
        } else if (categoryTokens.contains(token)) {
          score += 1;
        }
      }
      if (score == 0) continue;
    }

    if (memory.confirmed) score += 1;

    final age = clock.difference(memory.updatedAt);
    if (age < const Duration(days: 7)) {
      score += 1.5;
    } else if (age < const Duration(days: 30)) {
      score += 1;
    }

    scored.add(MemoryHit(memory, score));
  }

  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return b.record.updatedAt.compareTo(a.record.updatedAt);
  });

  final picked = <MemoryHit>[];
  var used = 0;
  for (final hit in scored) {
    if (picked.length >= limit) break;
    final cost = estimateTokens(hit.record.content) + 8;
    if (used + cost > tokenBudget && picked.isNotEmpty) break;
    picked.add(hit);
    used += cost;
  }
  return picked;
}

/// Finds a memory by substring match for `memory.forget` — returns every
/// hit so the caller can distinguish exact/fuzzy matches and ask when
/// several plausible records exist.
List<MemoryRecord> matchMemories(
  List<MemoryRecord> memories,
  String match, {
  int max = 5,
}) {
  final needle = match.trim().toLowerCase();
  if (needle.isEmpty) return const [];
  final scored = <({MemoryRecord record, int score})>[];
  for (final memory in memories) {
    final haystack = memory.content.toLowerCase();
    final index = haystack.indexOf(needle);
    if (index >= 0) {
      scored.add((record: memory, score: index == 0 ? 2 : 1));
    } else {
      // Require every query word to appear for word-level matches.
      final words = _tokens(match);
      final contentTokens = _tokens(memory.content);
      if (words.isNotEmpty && words.every(contentTokens.contains)) {
        scored.add((record: memory, score: 0));
      }
    }
  }
  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return b.record.updatedAt.compareTo(a.record.updatedAt);
  });
  return [
    for (final entry in scored.take(math.max(1, max))) entry.record,
  ];
}
