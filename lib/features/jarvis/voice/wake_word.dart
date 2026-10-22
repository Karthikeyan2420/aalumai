/// Offline wake-word detection for the phrase "Hey Jarvis" (and close
/// variants).
///
/// This is deliberately simple and deterministic: it normalises the
/// transcript and looks for a greeting token followed by a name token. It
/// will not fire on unrelated speech, and it accepts the common ways speech
/// recognition mangles "Jarvis" (jervis, jarvas, jarvez, …).
class WakeWordDetector {
  const WakeWordDetector();

  /// Greeting words that may precede the assistant name.
  static const List<String> greetings = [
    'hey', 'hi', 'hello', 'ok', 'okay', 'yo', 'hay',
  ];

  /// Accepted spellings/variants of the assistant name.
  static const List<String> names = [
    'jarvis', 'jervis', 'jarvas', 'jarvez', 'jarviss', 'jarvis.',
  ];

  /// Returns true when [transcript] contains a wake phrase.
  bool containsWakeWord(String transcript) {
    final words = transcript
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z\s]"), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    for (var i = 0; i < words.length; i++) {
      if (!greetings.contains(words[i])) continue;
      // Look at the next one or two words for the name.
      for (var j = i + 1; j < words.length && j <= i + 2; j++) {
        if (names.contains(words[j])) return true;
      }
    }
    // Also accept a bare "Jarvis" at the start of an utterance.
    if (words.isNotEmpty && names.contains(words.first)) return true;
    return false;
  }

  /// Strips the wake phrase from [transcript], returning the remaining
  /// command (empty when the user only said the wake word).
  String stripWakeWord(String transcript) {
    var text = transcript;
    final pattern = RegExp(
      r'^\s*(?:' + greetings.join('|') + r')?\s*(?:' + names.join('|') + r')\b',
      caseSensitive: false,
    );
    text = text.replaceFirst(pattern, '');
    return text.replaceAll(RegExp(r'^[\s,!.]+'), '').trim();
  }
}
