/// Built-in sample motivational messages offered in the alarm editor.
///
/// A sample is only a starting point: the user can edit or clear the message
/// for each alarm independently. Kept free of Flutter imports so it is trivially
/// unit-testable.
class AlarmMessages {
  const AlarmMessages._();

  static const String _english =
      'Good morning! Wake up. Today is your day. Move toward your goal!';
  static const String _tamil =
      'காலை வணக்கம்! எழுந்திரு. இன்று உன்னுடைய நாள். உன் இலக்கை நோக்கி முன்னேறு!';
  static const String _telugu =
      'శుభోదయం! లెండి. ఈరోజు మీ రోజు. మీ లక్ష్యం వైపు ముందుకు సాగండి!';
  static const String _malayalam =
      'സുപ്രഭാതം! എഴുന്നേൽക്കൂ. ഇന്ന് നിന്റെ ദിവസമാണ്. നിന്റെ ലക്ഷ്യത്തിലേക്ക് മുന്നേറൂ!';
  static const String _kannada =
      'ಶುಭೋದಯ! ಎದ್ದೇಳಿ. ಇಂದು ನಿಮ್ಮ ದಿನ. ನಿಮ್ಮ ಗುರಿಯತ್ತ ಮುನ್ನಡೆಯಿರಿ!';

  /// Sample messages keyed by primary language subtag.
  static const Map<String, String> samples = {
    'en': _english,
    'ta': _tamil,
    'te': _telugu,
    'ml': _malayalam,
    'kn': _kannada,
  };

  /// A sample message for [localeCode] (e.g. `ta`, `ta-IN`), falling back to
  /// English when the language is unknown.
  static String sampleFor(String? localeCode) {
    final raw = (localeCode ?? '').replaceAll('_', '-').toLowerCase();
    final dash = raw.indexOf('-');
    final code = dash == -1 ? raw : raw.substring(0, dash);
    return samples[code] ?? _english;
  }
}
