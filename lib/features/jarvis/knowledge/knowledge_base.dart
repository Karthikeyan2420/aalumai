/// A single local knowledge entry: a topic with concise, curated content and
/// the tags/synonyms used to match user questions to it.
class KnowledgeEntry {
  const KnowledgeEntry({
    required this.id,
    required this.title,
    required this.summary,
    this.body = '',
    this.tags = const [],
  });

  final String id;
  final String title;

  /// One or two sentence explanation, shown and spoken directly.
  final String summary;

  /// Optional longer explanation for "tell me more".
  final String body;

  /// Extra keywords/synonyms that should match this entry.
  final List<String> tags;
}

/// Result of matching a question against the local knowledge base.
class KnowledgeMatch {
  const KnowledgeMatch(this.entry, this.score);

  final KnowledgeEntry entry;

  /// 0.0–1.0 confidence. Above [KnowledgeBase.matchThreshold], the engine
  /// answers locally instead of offering a web search.
  final double score;
}

/// Curated, offline knowledge base for common questions.
///
/// This is intentionally small and hand-written: every entry is verifiable
/// and short enough to speak. It is not a substitute for a language model —
/// unknown questions fall through to the web-search workflow.
class KnowledgeBase {
  KnowledgeBase([List<KnowledgeEntry>? entries])
    : _entries = entries ?? kDefaultKnowledge;

  final List<KnowledgeEntry> _entries;

  static const double matchThreshold = 0.5;

  List<KnowledgeEntry> get entries => List.unmodifiable(_entries);

  KnowledgeEntry? byId(String id) {
    for (final entry in _entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// Scores [question] against every entry and returns the best match above
  /// zero, or `null` when nothing is relevant.
  ///
  /// Scoring is deterministic token overlap: exact title match scores 1.0,
  /// a tag hit scores 0.8, and shared significant words add proportional
  /// weight. No stemming beyond lower-casing is attempted.
  KnowledgeMatch? match(String question) {
    final queryTokens = _significantTokens(question);
    if (queryTokens.isEmpty) return null;

    KnowledgeMatch? best;
    for (final entry in _entries) {
      final score = _score(entry, queryTokens, question);
      if (score <= 0) continue;
      if (best == null || score > best.score) {
        best = KnowledgeMatch(entry, score);
      }
    }
    return best;
  }

  double _score(
    KnowledgeEntry entry,
    Set<String> queryTokens,
    String rawQuestion,
  ) {
    final normalized = rawQuestion.trim().toLowerCase();
    if (normalized == entry.title.toLowerCase()) return 1.0;

    final titleTokens = _significantTokens(entry.title);
    var matches = 0;
    for (final token in queryTokens) {
      if (titleTokens.contains(token)) {
        matches += 2;
      } else if (entry.tags.any((tag) => tag.toLowerCase() == token)) {
        matches += 2;
      } else if (_significantTokens(entry.summary).contains(token)) {
        matches += 1;
      }
    }
    if (matches == 0) return 0;
    // Normalise by the number of query tokens so long questions don't win
    // merely by containing more words.
    final score = matches / (queryTokens.length * 2);
    return score.clamp(0.0, 0.95);
  }
}

const Set<String> _stopWords = {
  'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'to', 'of', 'in', 'on',
  'at', 'for', 'and', 'or', 'my', 'me', 'i', 'you', 'it', 'that', 'this',
  'what', 'when', 'where', 'who', 'why', 'how', 'do', 'does', 'did', 'have',
  'has', 'about', 'from', 'with', 'tell', 'please', 'can', 'could', 'would',
  'will', 'explain', 'define',
};

Set<String> _significantTokens(String text) => text
    .toLowerCase()
    .split(RegExp(r"[^a-z0-9]+"))
    .where((t) => t.length > 1 && !_stopWords.contains(t))
    .toSet();

/// The built-in knowledge entries. Keep summaries short enough to speak and
/// factually safe — no invented specifics.
const List<KnowledgeEntry> kDefaultKnowledge = [
  KnowledgeEntry(
    id: 'gravity',
    title: 'gravity',
    summary:
        'Gravity is the force by which objects attract each other. On Earth '
        'it accelerates falling objects at about 9.8 metres per second '
        'squared.',
    tags: ['gravitational', 'falling', 'weight'],
  ),
  KnowledgeEntry(
    id: 'photosynthesis',
    title: 'photosynthesis',
    summary:
        'Photosynthesis is how plants use sunlight, water and carbon dioxide '
        'to make sugar, releasing oxygen as a by-product.',
    tags: ['plants', 'chlorophyll', 'sunlight'],
  ),
  KnowledgeEntry(
    id: 'water',
    title: 'water',
    summary:
        'Water is a molecule of two hydrogen atoms bonded to one oxygen atom. '
        'It freezes at 0 and boils at 100 degrees Celsius at sea level.',
    tags: ['h2o', 'liquid', 'freezing', 'boiling'],
  ),
  KnowledgeEntry(
    id: 'internet',
    title: 'the internet',
    summary:
        'The internet is a global network of interconnected computers that '
        'exchange data using shared protocols such as TCP/IP.',
    tags: ['network', 'web', 'online'],
  ),
  KnowledgeEntry(
    id: 'ai',
    title: 'artificial intelligence',
    summary:
        'Artificial intelligence is the field of building computer systems '
        'that perform tasks normally needing human intelligence, such as '
        'recognising images or understanding language.',
    tags: ['ai', 'machine learning', 'ml'],
  ),
  KnowledgeEntry(
    id: 'electricity',
    title: 'electricity',
    summary:
        'Electricity is the flow of electric charge, usually electrons '
        'moving through a conductor such as copper wire.',
    tags: ['current', 'voltage', 'charge'],
  ),
  KnowledgeEntry(
    id: 'capital_india',
    title: 'capital of india',
    summary: 'New Delhi is the capital of India.',
    tags: ['india', 'new delhi'],
  ),
  KnowledgeEntry(
    id: 'capital_france',
    title: 'capital of france',
    summary: 'Paris is the capital of France.',
    tags: ['france', 'paris'],
  ),
  KnowledgeEntry(
    id: 'sun',
    title: 'the sun',
    summary:
        'The Sun is the star at the centre of our solar system. It is a ball '
        'of hot plasma that provides Earth with light and heat.',
    tags: ['star', 'solar'],
  ),
  KnowledgeEntry(
    id: 'moon',
    title: 'the moon',
    summary:
        'The Moon is Earth\u2019s only natural satellite. It orbits Earth '
        'roughly every 27 days and drives the ocean tides.',
    tags: ['satellite', 'tides', 'lunar'],
  ),
  KnowledgeEntry(
    id: 'earth',
    title: 'earth',
    summary:
        'Earth is the third planet from the Sun and the only known planet '
        'with life. It completes one orbit in about 365 days.',
    tags: ['planet', 'world'],
  ),
  KnowledgeEntry(
    id: 'atom',
    title: 'atom',
    summary:
        'An atom is the smallest unit of ordinary matter. It has a nucleus of '
        'protons and neutrons surrounded by electrons.',
    tags: ['molecule', 'proton', 'neutron', 'electron'],
  ),
];
