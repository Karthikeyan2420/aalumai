/// Lightweight text normalisation shared by the intent matcher and the
/// knowledge topic matcher.
///
/// Everything here is deterministic and offline. The helpers are intentionally
/// conservative: they fold case, strip punctuation, collapse whitespace, and
/// correct a small set of common spelling slips, but never attempt semantic
/// understanding.
library;

/// Lower-cases, trims and collapses internal whitespace.
String normalize(String input) =>
    input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Drops trailing punctuation and common filler so "what's the time?" and
/// "what is the time" normalise to comparable forms.
String stripFiller(String input) {
  var text = normalize(input);
  // Expand the most common contractions the matcher cares about.
  const contractions = {
    "what's": 'what is',
    "who's": 'who is',
    "where's": 'where is',
    "how's": 'how is',
    "it's": 'it is',
    "i'm": 'i am',
    "don't": 'do not',
    "can't": 'cannot',
    "won't": 'will not',
    "let's": 'let us',
    "there's": 'there is',
  };
  contractions.forEach((from, to) {
    text = text.replaceAll(from, to);
  });
  text = text.replaceAll(RegExp(r'[?!.,;:]+$'), '');
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Splits [input] into meaningful tokens (words + numbers), dropping the
/// most common stop words.
Set<String> tokens(String input) {
  const stop = {
    'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'to', 'of', 'in',
    'on', 'at', 'for', 'and', 'or', 'my', 'me', 'i', 'you', 'it', 'that',
    'this', 'do', 'does', 'did', 'have', 'has', 'please', 'can', 'could',
    'would', 'will',
  };
  return input
      .toLowerCase()
      .split(RegExp(r"[^a-z0-9']+"))
      .where((t) => t.isNotEmpty && !stop.contains(t))
      .toSet();
}

/// A tiny typo table for common assistant-word misspellings. Kept small on
/// purpose: aggressive correction invents meaning we cannot verify.
const Map<String, String> _typoFixes = {
  'jarivs': 'jarvis',
  'jervis': 'jarvis',
  'weathr': 'weather',
  'tomorow': 'tomorrow',
  'tommorow': 'tomorrow',
  'yesterdy': 'yesterday',
  'calcualte': 'calculate',
  'calcluate': 'calculate',
  'rember': 'remember',
  'remind me': 'remind me',
};

/// Applies [_typoFixes] word-by-word.
String fixTypos(String input) {
  final words = normalize(input).split(' ');
  for (var i = 0; i < words.length; i++) {
    final fixed = _typoFixes[words[i]];
    if (fixed != null) words[i] = fixed;
  }
  return words.join(' ');
}

/// One-shot canonical form used by matching: typo-fixed, filler-stripped.
String canonicalize(String input) => stripFiller(fixTypos(input));
