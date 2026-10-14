import 'dart:convert';

/// Structured, versionable content for the Tamil→English beginner course.
/// This is real, reviewed starter content (not UI-hard-coded logic). Practice
/// questions are derived from the vocabulary at seed time, so they stay in
/// sync with the word list. Additional source languages can be added by
/// providing further course seeds.
class WordSeed {
  const WordSeed({
    required this.word,
    required this.meaningTa,
    required this.pron,
    required this.exampleEn,
    required this.exampleTa,
  });

  final String word;
  final String meaningTa;
  final String pron;
  final String exampleEn;
  final String exampleTa;
}

class LessonSeed {
  const LessonSeed({
    required this.day,
    required this.title,
    required this.grammarTitle,
    required this.grammarTa,
    required this.words,
    required this.sentencesEn,
    required this.sentencesTa,
  });

  final int day;
  final String title;
  final String grammarTitle;
  final String grammarTa;
  final List<WordSeed> words;
  final List<String> sentencesEn;
  final List<String> sentencesTa;
}

LessonSeed _l(
  int day,
  String title,
  String grammarTitle,
  String grammarTa,
  List<WordSeed> words,
  List<String> en,
  List<String> ta,
) => LessonSeed(
  day: day,
  title: title,
  grammarTitle: grammarTitle,
  grammarTa: grammarTa,
  words: words,
  sentencesEn: en,
  sentencesTa: ta,
);

WordSeed _w(String w, String m, String p, String e, String et) =>
    WordSeed(word: w, meaningTa: m, pron: p, exampleEn: e, exampleTa: et);

final kTamilEnglishCourse = <LessonSeed>[
  _l(
    1,
    'Greetings',
    'Present tense: am / is / are',
    'I am, you are, he is — தமிழில் "நான் இருக்கிறேன்" என்பதற்கு இணையானது.',
    [
      _w(
        'hello',
        'வணக்கம்',
        'ஹெல்லோ',
        'Hello, how are you?',
        'வணக்கம், எப்படி இருக்கிறீர்கள்?',
      ),
      _w(
        'good morning',
        'காலை வணக்கம்',
        'குட் மார்னிங்',
        'Good morning, teacher.',
        'காலை வணக்கம், ஆசிரியரே.',
      ),
      _w(
        'thank you',
        'நன்றி',
        'தேங்க் யூ',
        'Thank you for your help.',
        'உதவிக்கு நன்றி.',
      ),
      _w(
        'please',
        'தயவுசெய்து',
        'ப்ளீஸ்',
        'Please come in.',
        'தயவுசெய்து உள்ளே வாருங்கள்.',
      ),
      _w(
        'sorry',
        'மன்னிக்கவும்',
        'சாரி',
        'Sorry, I am late.',
        'மன்னிக்கவும், நான் தாமதமானேன்.',
      ),
    ],
    ['I am fine.', 'She is my friend.', 'We are ready.'],
    [
      'நான் நலமாக இருக்கிறேன்.',
      'அவள் என் நண்பி.',
      'நாங்கள் தயாராக இருக்கிறோம்.',
    ],
  ),
  _l(
    2,
    'People',
    'Singular and plural nouns',
    'ஒருமை பன்மை: friend → friends. பெரும்பாலும் s சேர்த்தால் போதும்.',
    [
      _w(
        'mother',
        'அம்மா',
        'மதர்',
        'My mother cooks well.',
        'என் அம்மா நன்றாக சமைக்கிறார்.',
      ),
      _w(
        'father',
        'அப்பா',
        'ஃபாதர்',
        'My father is a farmer.',
        'என் அப்பா ஒரு விவசாயி.',
      ),
      _w(
        'friend',
        'நண்பன்',
        'ஃப்ரெண்ட்',
        'He is my best friend.',
        'அவன் என் சிறந்த நண்பன்.',
      ),
      _w(
        'teacher',
        'ஆசிரியர்',
        'டீச்சர்',
        'The teacher is kind.',
        'ஆசிரியர் அன்பானவர்.',
      ),
      _w(
        'child',
        'குழந்தை',
        'சைல்டு',
        'The child is playing.',
        'குழந்தை விளையாடுகிறது.',
      ),
    ],
    ['I have two brothers.', 'They are students.', 'The children are happy.'],
    [
      'எனக்கு இரண்டு சகோதரர்கள் இருக்கிறார்கள்.',
      'அவர்கள் மாணவர்கள்.',
      'குழந்தைகள் மகிழ்ச்சியாக இருக்கிறார்கள்.',
    ],
  ),
  _l(
    3,
    'Numbers',
    'Counting 1–10',
    'எண்கள்: one, two, three … பேச்சில் பயன்படுத்துவோம்.',
    [
      _w(
        'one',
        'ஒன்று',
        'வன்',
        'I have one pen.',
        'என்னிடம் ஒரு பேனா இருக்கிறது.',
      ),
      _w(
        'two',
        'இரண்டு',
        'டூ',
        'She has two books.',
        'அவளிடம் இரண்டு புத்தகங்கள் உள்ளன.',
      ),
      _w(
        'three',
        'மூன்று',
        'த்ரீ',
        'There are three chairs.',
        'மூன்று நாற்காலிகள் உள்ளன.',
      ),
      _w(
        'four',
        'நான்கு',
        'ஃபோர்',
        'A table has four legs.',
        'ஒரு மேசைக்கு நான்கு கால்கள்.',
      ),
      _w(
        'five',
        'ஐந்து',
        'ஃபைவ்',
        'I work five days.',
        'நான் ஐந்து நாட்கள் வேலை செய்கிறேன்.',
      ),
    ],
    [
      'I live on the second floor.',
      'There are ten students.',
      'He is number three.',
    ],
    [
      'நான் இரண்டாம் மாடியில் வசிக்கிறேன்.',
      'பத்து மாணவர்கள் இருக்கிறார்கள்.',
      'அவன் மூன்றாம் எண்.',
    ],
  ),
  _l(
    4,
    'Colours',
    'Adjective + noun order',
    'பெயரடை முதலில்: a red car (சிவப்பு கார்). "a car red" என்பது தவறு.',
    [
      _w(
        'red',
        'சிவப்பு',
        'ரெட்',
        'I like the red shirt.',
        'எனக்கு சிவப்பு சட்டை பிடிக்கும்.',
      ),
      _w('blue', 'நீலம்', 'ப்ளூ', 'The sky is blue.', 'வானம் நீலமாக உள்ளது.'),
      _w(
        'green',
        'பச்சை',
        'க்ரீன்',
        'The leaf is green.',
        'இலை பச்சையாக உள்ளது.',
      ),
      _w(
        'black',
        'கருப்பு',
        'ப்ளாக்',
        'He wears black shoes.',
        'அவன் கருப்பு காலணி அணிகிறான்.',
      ),
      _w(
        'white',
        'வெள்ளை',
        'வைட்',
        'She has a white bag.',
        'அவளிடம் ஒரு வெள்ளை பை உள்ளது.',
      ),
    ],
    ['The flower is yellow.', 'I have a new bag.', 'It is a small house.'],
    [
      'பூ மஞ்சள் நிறமாக உள்ளது.',
      'என்னிடம் ஒரு புதிய பை இருக்கிறது.',
      'இது ஒரு சிறிய வீடு.',
    ],
  ),
  _l(
    5,
    'Food',
    'I like / I want',
    'விருப்பம்: I like (பிடிக்கும்), I want (வேண்டும்).',
    [
      _w(
        'water',
        'தண்ணீர்',
        'வாட்டர்',
        'Please give me water.',
        'தயவுசெய்து எனக்கு தண்ணீர் தாருங்கள்.',
      ),
      _w(
        'rice',
        'சோறு',
        'ரைஸ்',
        'We eat rice daily.',
        'நாங்கள் தினமும் சோறு சாப்பிடுகிறோம்.',
      ),
      _w('milk', 'பால்', 'மில்க்', 'The milk is hot.', 'பால் சூடாக உள்ளது.'),
      _w(
        'fruit',
        'பழம்',
        'ஃப்ரூட்',
        'This fruit is sweet.',
        'இந்த பழம் இனிப்பாக உள்ளது.',
      ),
      _w(
        'tea',
        'தேநீர்',
        'டீ',
        'I drink tea in the morning.',
        'நான் காலையில் தேநீர் குடிக்கிறேன்.',
      ),
    ],
    ['I want some rice.', 'She likes fruits.', 'We need water.'],
    [
      'எனக்கு சிறிது சோறு வேண்டும்.',
      'அவளுக்கு பழங்கள் பிடிக்கும்.',
      'எங்களுக்கு தண்ணீர் தேவை.',
    ],
  ),
  _l(
    6,
    'Family',
    'Possessive: my / your / his / her',
    'உடைமை: my (என்), your (உன்), his (அவன்), her (அவள்).',
    [
      _w(
        'family',
        'குடும்பம்',
        'ஃபேமிலி',
        'My family is small.',
        'என் குடும்பம் சிறியது.',
      ),
      _w(
        'brother',
        'சகோதரன்',
        'ப்ரதர்',
        'My brother is tall.',
        'என் சகோதரன் உயரமானவன்.',
      ),
      _w(
        'sister',
        'சகோதரி',
        'சிஸ்டர்',
        'Her sister is a doctor.',
        'அவள் சகோதரி ஒரு மருத்துவர்.',
      ),
      _w(
        'son',
        'மகன்',
        'சன்',
        'Their son studies well.',
        'அவர்கள் மகன் நன்றாக படிக்கிறான்.',
      ),
      _w(
        'daughter',
        'மகள்',
        'டாட்டர்',
        'My daughter is five.',
        'என் மகள் ஐந்து வயது.',
      ),
    ],
    ['His family lives here.', 'Your sister is kind.', 'This is my house.'],
    [
      'அவன் குடும்பம் இங்கே வாழ்கிறது.',
      'உன் சகோதரி அன்பானவள்.',
      'இது என் வீடு.',
    ],
  ),
  _l(
    7,
    'Days',
    'Present simple: routine',
    'வழக்கமான செயல்கள்: I go, I eat, I work.',
    [
      _w('today', 'இன்று', 'டுடே', 'Today is Monday.', 'இன்று திங்கள்.'),
      _w(
        'tomorrow',
        'நாளை',
        'டுமாரோ',
        'I will come tomorrow.',
        'நான் நாளை வருவேன்.',
      ),
      _w(
        'yesterday',
        'நேற்று',
        'யெஸ்டர்டே',
        'It rained yesterday.',
        'நேற்று மழை பெய்தது.',
      ),
      _w(
        'morning',
        'காலை',
        'மார்னிங்',
        'I walk in the morning.',
        'நான் காலையில் நடக்கிறேன்.',
      ),
      _w(
        'night',
        'இரவு',
        'நைட்',
        'Good night, sleep well.',
        'இரவு வணக்கம், நன்றாக தூங்குங்கள்.',
      ),
    ],
    ['I go to work today.', 'She studies every day.', 'We rest on Sunday.'],
    [
      'நான் இன்று வேலைக்கு செல்கிறேன்.',
      'அவள் தினமும் படிக்கிறாள்.',
      'நாங்கள் ஞாயிற்றுக்கிழமை ஓய்வெடுக்கிறோம்.',
    ],
  ),
  _l(
    8,
    'Places',
    'There is / There are',
    'இடத்தை குறிக்க: There is a shop (ஒரு கடை உள்ளது).',
    [
      _w('house', 'வீடு', 'ஹவுஸ்', 'Our house is big.', 'எங்கள் வீடு பெரியது.'),
      _w(
        'school',
        'பள்ளி',
        'ஸ்கூல்',
        'The school is near.',
        'பள்ளி அருகில் உள்ளது.',
      ),
      _w(
        'market',
        'சந்தை',
        'மார்க்கெட்',
        'I go to the market.',
        'நான் சந்தைக்கு செல்கிறேன்.',
      ),
      _w(
        'hospital',
        'மருத்துவமனை',
        'ஹாஸ்பிடல்',
        'The hospital is far.',
        'மருத்துவமனை தூரமாக உள்ளது.',
      ),
      _w(
        'road',
        'சாலை',
        'ரோடு',
        'This road is busy.',
        'இந்த சாலை பரபரப்பாக உள்ளது.',
      ),
    ],
    [
      'There is a temple here.',
      'The market is open.',
      'I live near the school.',
    ],
    [
      'இங்கே ஒரு கோவில் உள்ளது.',
      'சந்தை திறந்திருக்கிறது.',
      'நான் பள்ளி அருகில் வசிக்கிறேன்.',
    ],
  ),
  _l(
    9,
    'Actions',
    'Present continuous: -ing',
    'இப்போது நடப்பது: I am eating (நான் சாப்பிடுகிறேன்).',
    [
      _w(
        'eat',
        'சாப்பிடு',
        'ஈட்',
        'I am eating now.',
        'நான் இப்போது சாப்பிடுகிறேன்.',
      ),
      _w(
        'drink',
        'குடி',
        'ட்ரிங்க்',
        'She is drinking tea.',
        'அவள் தேநீர் குடிக்கிறாள்.',
      ),
      _w(
        'read',
        'படி',
        'ரீட்',
        'He is reading a book.',
        'அவன் ஒரு புத்தகம் படிக்கிறான்.',
      ),
      _w(
        'write',
        'எழுது',
        'ரைட்',
        'I am writing a letter.',
        'நான் ஒரு கடிதம் எழுதுகிறேன்.',
      ),
      _w(
        'walk',
        'நட',
        'வாக்',
        'They are walking home.',
        'அவர்கள் வீட்டிற்கு நடக்கிறார்கள்.',
      ),
    ],
    ['We are listening.', 'The baby is sleeping.', 'I am learning English.'],
    [
      'நாங்கள் கேட்டுக்கொண்டிருக்கிறோம்.',
      'குழந்தை தூங்குகிறது.',
      'நான் ஆங்கிலம் கற்கிறேன்.',
    ],
  ),
  _l(
    10,
    'Questions',
    'Yes/No questions with do/does',
    'கேள்வி: Do you …? Does he …?',
    [
      _w('what', 'என்ன', 'வாட்', 'What is your name?', 'உங்கள் பெயர் என்ன?'),
      _w(
        'where',
        'எங்கே',
        'வேர்',
        'Where do you live?',
        'நீங்கள் எங்கே வசிக்கிறீர்கள்?',
      ),
      _w(
        'when',
        'எப்போது',
        'வென்',
        'When will you come?',
        'நீங்கள் எப்போது வருவீர்கள்?',
      ),
      _w('who', 'யார்', 'ஹூ', 'Who is he?', 'அவன் யார்?'),
      _w('why', 'ஏன்', 'வை', 'Why are you late?', 'நீங்கள் ஏன் தாமதம்?'),
    ],
    ['Do you speak English?', 'Does she like tea?', 'Where is the market?'],
    [
      'நீங்கள் ஆங்கிலம் பேசுகிறீர்களா?',
      'அவளுக்கு தேநீர் பிடிக்குமா?',
      'சந்தை எங்கே உள்ளது?',
    ],
  ),
  _l(
    11,
    'Time',
    'Telling the time',
    'நேரம்: It is three o\'clock.',
    [
      _w('time', 'நேரம்', 'டைம்', 'What time is it?', 'நேரம் என்ன?'),
      _w(
        'hour',
        'மணி',
        'அவர்',
        'I waited an hour.',
        'நான் ஒரு மணி நேரம் காத்திருந்தேன்.',
      ),
      _w(
        'minute',
        'நிமிடம்',
        'மினிட்',
        'Give me a minute.',
        'எனக்கு ஒரு நிமிடம் தாருங்கள்.',
      ),
      _w(
        'early',
        'சீக்கிரம்',
        'அர்லி',
        'I wake up early.',
        'நான் சீக்கிரம் எழுந்திருக்கிறேன்.',
      ),
      _w('late', 'தாமதம்', 'லேட்', 'Do not be late.', 'தாமதமாக வராதீர்கள்.'),
    ],
    ['It is nine o\'clock.', 'We meet at noon.', 'The bus is on time.'],
    [
      'இப்போது ஒன்பது மணி.',
      'நாங்கள் நண்பகலில் சந்திக்கிறோம்.',
      'பஸ் சரியான நேரத்திற்கு வருகிறது.',
    ],
  ),
  _l(
    12,
    'Shopping',
    'How much / How many',
    'விலை கேட்பது: How much is this?',
    [
      _w(
        'money',
        'பணம்',
        'மணி',
        'I do not have money.',
        'என்னிடம் பணம் இல்லை.',
      ),
      _w('price', 'விலை', 'ப்ரைஸ்', 'The price is high.', 'விலை அதிகம்.'),
      _w('cheap', 'மலிவு', 'சீப்', 'This is very cheap.', 'இது மிகவும் மலிவு.'),
      _w(
        'costly',
        'விலை அதிகமான',
        'காஸ்ட்லி',
        'Gold is costly.',
        'தங்கம் விலை அதிகம்.',
      ),
      _w('buy', 'வாங்கு', 'பை', 'I will buy this.', 'நான் இதை வாங்குவேன்.'),
    ],
    ['How much is this shirt?', 'I want to buy rice.', 'The shop is closed.'],
    [
      'இந்த சட்டை எவ்வளவு?',
      'நான் அரிசி வாங்க விரும்புகிறேன்.',
      'கடை மூடியுள்ளது.',
    ],
  ),
  _l(
    13,
    'Travel',
    'Can / cannot',
    'திறன்: I can swim (என்னால் நீந்த முடியும்).',
    [
      _w('bus', 'பஸ்', 'பஸ்', 'I go by bus.', 'நான் பஸ்ஸில் செல்கிறேன்.'),
      _w('train', 'ரயில்', 'ட்ரெய்ன்', 'The train is late.', 'ரயில் தாமதம்.'),
      _w(
        'ticket',
        'டிக்கெட்',
        'டிக்கெட்',
        'Buy one ticket.',
        'ஒரு டிக்கெட் வாங்குங்கள்.',
      ),
      _w(
        'journey',
        'பயணம்',
        'ஜர்னி',
        'The journey was long.',
        'பயணம் நீளமானது.',
      ),
      _w(
        'arrive',
        'வந்து சேர',
        'அரைவ்',
        'We arrive at noon.',
        'நாங்கள் நண்பகலில் சேருகிறோம்.',
      ),
    ],
    ['I can drive a car.', 'She cannot come today.', 'The bus stops here.'],
    [
      'என்னால் கார் ஓட்ட முடியும்.',
      'அவளால் இன்று வர முடியாது.',
      'பஸ் இங்கே நிற்கிறது.',
    ],
  ),
  _l(
    14,
    'Weather',
    'It is + adjective',
    'வானிலை: It is hot / cold / rainy.',
    [
      _w(
        'sun',
        'சூரியன்',
        'சன்',
        'The sun is bright.',
        'சூரியன் பிரகாசமாக உள்ளது.',
      ),
      _w('rain', 'மழை', 'ரெயின்', 'It will rain today.', 'இன்று மழை பெய்யும்.'),
      _w('hot', 'சூடு', 'ஹாட்', 'The water is hot.', 'தண்ணீர் சூடாக உள்ளது.'),
      _w(
        'cold',
        'குளிர்',
        'கோல்டு',
        'It is cold outside.',
        'வெளியே குளிராக உள்ளது.',
      ),
      _w(
        'wind',
        'காற்று',
        'விண்ட்',
        'The wind is strong.',
        'காற்று வலுவாக உள்ளது.',
      ),
    ],
    ['It is very hot today.', 'We need an umbrella.', 'The sky is cloudy.'],
    [
      'இன்று மிகவும் சூடாக உள்ளது.',
      'எங்களுக்கு குடை தேவை.',
      'வானம் மேகமூட்டமாக உள்ளது.',
    ],
  ),
  _l(
    15,
    'Work',
    'Present simple questions',
    'வேலை பற்றி: What do you do?',
    [
      _w(
        'work',
        'வேலை',
        'வொர்க்',
        'I go to work.',
        'நான் வேலைக்கு செல்கிறேன்.',
      ),
      _w(
        'office',
        'அலுவலகம்',
        'ஆஃபீஸ்',
        'The office is open.',
        'அலுவலகம் திறந்துள்ளது.',
      ),
      _w(
        'job',
        'வேலை',
        'ஜாப்',
        'He found a new job.',
        'அவன் புதிய வேலை கண்டான்.',
      ),
      _w(
        'busy',
        'பிஸியான',
        'பிஸி',
        'I am busy now.',
        'நான் இப்போது பிஸியாக இருக்கிறேன்.',
      ),
      _w('rest', 'ஓய்வு', 'ரெஸ்ட்', 'You need rest.', 'உங்களுக்கு ஓய்வு தேவை.'),
    ],
    ['Where do you work?', 'She starts work at nine.', 'We are very busy.'],
    [
      'நீங்கள் எங்கே வேலை செய்கிறீர்கள்?',
      'அவள் ஒன்பது மணிக்கு வேலை தொடங்குகிறாள்.',
      'நாங்கள் மிகவும் பிஸியாக இருக்கிறோம்.',
    ],
  ),
  _l(
    16,
    'Body',
    'Have / has',
    'உடைமை: I have, he has.',
    [
      _w('head', 'தலை', 'ஹெட்', 'My head hurts.', 'என் தலை வலிக்கிறது.'),
      _w(
        'hand',
        'கை',
        'ஹேண்ட்',
        'Raise your hand.',
        'உங்கள் கையை உயர்த்துங்கள்.',
      ),
      _w(
        'eye',
        'கண்',
        'ஐ',
        'She has brown eyes.',
        'அவளுக்கு பழுப்பு கண்கள் உள்ளன.',
      ),
      _w('leg', 'கால்', 'லெக்', 'My leg is tired.', 'என் கால் சோர்வாக உள்ளது.'),
      _w(
        'heart',
        'இதயம்',
        'ஹார்ட்',
        'Keep your heart strong.',
        'உங்கள் இதயத்தை வலுவாக வைத்திருங்கள்.',
      ),
    ],
    ['I have a headache.', 'Wash your hands.', 'He has long hair.'],
    [
      'எனக்கு தலைவலி உள்ளது.',
      'உங்கள் கைகளை கழுவுங்கள்.',
      'அவனுக்கு நீண்ட முடி உள்ளது.',
    ],
  ),
  _l(
    17,
    'Feelings',
    'I feel + adjective',
    'உணர்வு: I feel happy (நான் மகிழ்ச்சியாக உணர்கிறேன்).',
    [
      _w(
        'happy',
        'மகிழ்ச்சி',
        'ஹாப்பி',
        'I am very happy.',
        'நான் மிகவும் மகிழ்ச்சியாக இருக்கிறேன்.',
      ),
      _w('sad', 'வருத்தம்', 'சேட்', 'Do not be sad.', 'வருத்தப்படாதீர்கள்.'),
      _w(
        'tired',
        'சோர்வு',
        'டயர்டு',
        'I feel tired.',
        'நான் சோர்வாக உணர்கிறேன்.',
      ),
      _w(
        'angry',
        'கோபம்',
        'ஆங்கிரி',
        'He is angry now.',
        'அவன் இப்போது கோபமாக இருக்கிறான்.',
      ),
      _w(
        'afraid',
        'பயம்',
        'அஃப்ரெய்டு',
        'She is afraid of dogs.',
        'அவளுக்கு நாய்களிடம் பயம்.',
      ),
    ],
    ['I am happy today.', 'They are excited.', 'Are you okay?'],
    [
      'நான் இன்று மகிழ்ச்சியாக இருக்கிறேன்.',
      'அவர்கள் ஆர்வமாக இருக்கிறார்கள்.',
      'நீங்கள் நலமா?',
    ],
  ),
  _l(
    18,
    'Directions',
    'Imperatives: turn, go, stop',
    'கட்டளை: Turn left, go straight.',
    [
      _w(
        'left',
        'இடது',
        'லெஃப்ட்',
        'Turn left here.',
        'இங்கே இடதுபுறம் திரும்புங்கள்.',
      ),
      _w('right', 'வலது', 'ரைட்', 'Go to the right.', 'வலதுபுறம் செல்லுங்கள்.'),
      _w(
        'straight',
        'நேராக',
        'ஸ்ட்ரைட்',
        'Go straight ahead.',
        'நேராக செல்லுங்கள்.',
      ),
      _w(
        'near',
        'அருகில்',
        'நியர்',
        'It is near the bank.',
        'இது வங்கிக்கு அருகில் உள்ளது.',
      ),
      _w(
        'far',
        'தூரம்',
        'ஃபார்',
        'The station is far.',
        'நிலையம் தூரமாக உள்ளது.',
      ),
    ],
    ['Turn right at the corner.', 'The shop is nearby.', 'How do I get there?'],
    [
      'மூலையில் வலதுபுறம் திரும்புங்கள்.',
      'கடை அருகில் உள்ளது.',
      'நான் அங்கே எப்படி செல்வது?',
    ],
  ),
  _l(
    19,
    'Past',
    'Past simple: -ed',
    'கடந்த காலம்: I worked, I walked.',
    [
      _w(
        'yesterday',
        'நேற்று',
        'யெஸ்டர்டே',
        'I met him yesterday.',
        'நான் நேற்று அவனை சந்தித்தேன்.',
      ),
      _w(
        'went',
        'சென்றேன்',
        'வென்ட்',
        'I went to school.',
        'நான் பள்ளிக்கு சென்றேன்.',
      ),
      _w(
        'ate',
        'சாப்பிட்டேன்',
        'ஏட்',
        'We ate together.',
        'நாங்கள் ஒன்றாக சாப்பிட்டோம்.',
      ),
      _w(
        'saw',
        'பார்த்தேன்',
        'ஸா',
        'I saw a film.',
        'நான் ஒரு படம் பார்த்தேன்.',
      ),
      _w(
        'finished',
        'முடிந்தது',
        'ஃபினிஷ்ட்',
        'The work finished.',
        'வேலை முடிந்தது.',
      ),
    ],
    ['I called you yesterday.', 'They played well.', 'She arrived late.'],
    [
      'நான் நேற்று உங்களை அழைத்தேன்.',
      'அவர்கள் நன்றாக விளையாடினார்கள்.',
      'அவள் தாமதமாக வந்தாள்.',
    ],
  ),
  _l(
    20,
    'Future',
    'Will + verb',
    'எதிர்காலம்: I will go (நான் செல்வேன்).',
    [
      _w(
        'will',
        '…போகிறேன் (எதிர்காலம்)',
        'வில்',
        'I will call you.',
        'நான் உங்களை அழைப்பேன்.',
      ),
      _w(
        'soon',
        'விரைவில்',
        'சூன்',
        'He will come soon.',
        'அவன் விரைவில் வருவான்.',
      ),
      _w(
        'later',
        'பின்னர்',
        'லேட்டர்',
        'We will talk later.',
        'நாங்கள் பின்னர் பேசுவோம்.',
      ),
      _w(
        'plan',
        'திட்டம்',
        'ப்ளான்',
        'I have a plan.',
        'எனக்கு ஒரு திட்டம் உள்ளது.',
      ),
      _w(
        'future',
        'எதிர்காலம்',
        'ஃபியூச்சர்',
        'Think about the future.',
        'எதிர்காலத்தைப் பற்றி சிந்தியுங்கள்.',
      ),
    ],
    ['I will help you.', 'She will study tomorrow.', 'We will meet again.'],
    [
      'நான் உங்களுக்கு உதவுவேன்.',
      'அவள் நாளை படிப்பாள்.',
      'நாங்கள் மீண்டும் சந்திப்போம்.',
    ],
  ),
  _l(
    21,
    'Home',
    'Prepositions: in, on, under',
    'இட முன்னிடைச்சொற்கள்: in, on, under.',
    [
      _w('room', 'அறை', 'ரூம்', 'The room is clean.', 'அறை சுத்தமாக உள்ளது.'),
      _w('door', 'கதவு', 'டோர்', 'Close the door.', 'கதவை மூடுங்கள்.'),
      _w(
        'table',
        'மேசை',
        'டேபிள்',
        'The book is on the table.',
        'புத்தகம் மேசையில் உள்ளது.',
      ),
      _w(
        'bed',
        'படுக்கை',
        'பெட்',
        'The cat is under the bed.',
        'பூனை படுக்கையின் கீழே உள்ளது.',
      ),
      _w('window', 'ஜன்னல்', 'விண்டோ', 'Open the window.', 'ஜன்னலை திறங்கள்.'),
    ],
    [
      'The keys are in the bag.',
      'The cup is on the shelf.',
      'The shoes are under the chair.',
    ],
    [
      'சாவிகள் பையில் உள்ளன.',
      'கோப்பை அலமாரியில் உள்ளது.',
      'காலணிகள் நாற்காலியின் கீழே உள்ளன.',
    ],
  ),
  _l(
    22,
    'Clothes',
    'Wear / put on',
    'உடை: I wear a shirt. Put on your shoes.',
    [
      _w(
        'shirt',
        'சட்டை',
        'ஷர்ட்',
        'This shirt is new.',
        'இந்த சட்டை புதியது.',
      ),
      _w(
        'dress',
        'ஆடை',
        'ட்ரெஸ்',
        'Her dress is pretty.',
        'அவள் ஆடை அழகாக உள்ளது.',
      ),
      _w(
        'shoes',
        'காலணி',
        'ஷூஸ்',
        'Wear your shoes.',
        'உங்கள் காலணியை அணியுங்கள்.',
      ),
      _w('hat', 'தொப்பி', 'ஹாட்', 'He wears a hat.', 'அவன் தொப்பி அணிகிறான்.'),
      _w(
        'clean',
        'சுத்தமான',
        'க்ளீன்',
        'Keep your clothes clean.',
        'உங்கள் ஆடைகளை சுத்தமாக வைத்திருங்கள்.',
      ),
    ],
    ['I wear a blue dress.', 'These shoes are old.', 'Wash your shirt.'],
    [
      'நான் நீல ஆடை அணிகிறேன்.',
      'இந்த காலணிகள் பழையவை.',
      'உங்கள் சட்டையை கழுவுங்கள்.',
    ],
  ),
  _l(
    23,
    'Animals',
    'This / That / These / Those',
    'சுட்டு: This (இது), That (அது), These (இவை), Those (அவை).',
    [
      _w('dog', 'நாய்', 'டாக்', 'The dog is friendly.', 'நாய் நட்பானது.'),
      _w('cat', 'பூனை', 'கேட்', 'The cat is sleeping.', 'பூனை தூங்குகிறது.'),
      _w('cow', 'பசு', 'கா', 'The cow gives milk.', 'பசு பால் தருகிறது.'),
      _w(
        'bird',
        'பறவை',
        'பேர்ட்',
        'Birds sing in the morning.',
        'பறவைகள் காலையில் பாடுகின்றன.',
      ),
      _w(
        'fish',
        'மீன்',
        'ஃபிஷ்',
        'Fish live in water.',
        'மீன்கள் தண்ணீரில் வாழ்கின்றன.',
      ),
    ],
    ['This is my dog.', 'Those birds are beautiful.', 'That cat is black.'],
    ['இது என் நாய்.', 'அந்த பறவைகள் அழகானவை.', 'அந்த பூனை கருப்பு.'],
  ),
  _l(
    24,
    'Education',
    'Because / so',
    'காரணம்: because (ஏனெனில்), so (எனவே).',
    [
      _w(
        'study',
        'படி',
        'ஸ்டடி',
        'I study every evening.',
        'நான் தினமும் மாலையில் படிக்கிறேன்.',
      ),
      _w(
        'book',
        'புத்தகம்',
        'புக்',
        'This book is useful.',
        'இந்த புத்தகம் பயனுள்ளது.',
      ),
      _w(
        'learn',
        'கற்றுக்கொள்',
        'லர்ன்',
        'I learn English.',
        'நான் ஆங்கிலம் கற்கிறேன்.',
      ),
      _w(
        'understand',
        'புரிந்துகொள்',
        'அண்டர்ஸ்டாண்ட்',
        'I understand now.',
        'நான் இப்போது புரிந்துகொள்கிறேன்.',
      ),
      _w(
        'practice',
        'பயிற்சி',
        'பிராக்டிஸ்',
        'Practice makes perfect.',
        'பயிற்சியே சிறப்பைத் தரும்.',
      ),
    ],
    [
      'I study because I have an exam.',
      'She reads a lot.',
      'We learn new words daily.',
    ],
    [
      'எனக்கு தேர்வு இருப்பதால் நான் படிக்கிறேன்.',
      'அவள் நிறைய படிக்கிறாள்.',
      'நாங்கள் தினமும் புதிய சொற்களை கற்கிறோம்.',
    ],
  ),
  _l(
    25,
    'Health',
    'Should / must',
    'ஆலோசனை: You should rest. கட்டாயம்: You must take medicine.',
    [
      _w(
        'healthy',
        'ஆரோக்கியமான',
        'ஹெல்தி',
        'Eat healthy food.',
        'ஆரோக்கியமான உணவை சாப்பிடுங்கள்.',
      ),
      _w(
        'medicine',
        'மருந்து',
        'மெடிசின்',
        'Take your medicine.',
        'உங்கள் மருந்தை எடுங்கள்.',
      ),
      _w(
        'doctor',
        'மருத்துவர்',
        'டாக்டர்',
        'See a doctor.',
        'மருத்துவரை பாருங்கள்.',
      ),
      _w(
        'sleep',
        'தூங்கு',
        'ஸ்லீப்',
        'Get enough sleep.',
        'போதுமான தூக்கம் பெறுங்கள்.',
      ),
      _w(
        'exercise',
        'உடற்பயிற்சி',
        'எக்சர்சைஸ்',
        'Exercise daily.',
        'தினமும் உடற்பயிற்சி செய்யுங்கள்.',
      ),
    ],
    ['You should drink water.', 'I must go home.', 'Health is important.'],
    [
      'நீங்கள் தண்ணீர் குடிக்க வேண்டும்.',
      'நான் வீட்டிற்கு செல்ல வேண்டும்.',
      'ஆரோக்கியம் முக்கியம்.',
    ],
  ),
  _l(
    26,
    'Requests',
    'Could / would you',
    'கோரிக்கை: Could you help me?',
    [
      _w(
        'help',
        'உதவி',
        'ஹெல்ப்',
        'Can you help me?',
        'நீங்கள் எனக்கு உதவ முடியுமா?',
      ),
      _w(
        'need',
        'தேவை',
        'நீட்',
        'I need your help.',
        'எனக்கு உங்கள் உதவி தேவை.',
      ),
      _w(
        'give',
        'கொடு',
        'கிவ்',
        'Please give me the pen.',
        'தயவுசெய்து எனக்கு பேனா தாருங்கள்.',
      ),
      _w(
        'open',
        'திற',
        'ஓபன்',
        'Please open the door.',
        'தயவுசெய்து கதவை திறங்கள்.',
      ),
      _w(
        'wait',
        'காத்திரு',
        'வெயிட்',
        'Please wait a minute.',
        'தயவுசெய்து ஒரு நிமிடம் காத்திருங்கள்.',
      ),
    ],
    [
      'Could you repeat that?',
      'Would you like tea?',
      'I would like some water.',
    ],
    [
      'அதை மீண்டும் சொல்ல முடியுமா?',
      'உங்களுக்கு தேநீர் வேண்டுமா?',
      'எனக்கு சிறிது தண்ணீர் வேண்டும்.',
    ],
  ),
  _l(
    27,
    'Numbers & Quantity',
    'Much / many / some',
    'அளவு: much (அளவில்லாத), many (எண்ணக்கூடிய), some (சில).',
    [
      _w(
        'many',
        'பல',
        'மெனி',
        'He has many friends.',
        'அவனுக்கு பல நண்பர்கள் உள்ளன.',
      ),
      _w(
        'few',
        'சில',
        'ஃபியூ',
        'I have a few coins.',
        'என்னிடம் சில நாணயங்கள் உள்ளன.',
      ),
      _w(
        'more',
        'மேலும்',
        'மோர்',
        'I need more time.',
        'எனக்கு மேலும் நேரம் தேவை.',
      ),
      _w('enough', 'போதுமான', 'இனஃப்', 'That is enough.', 'அது போதும்.'),
      _w(
        'little',
        'சிறிது',
        'லிட்டில்',
        'Add a little salt.',
        'சிறிது உப்பு சேர்க்கவும்.',
      ),
    ],
    [
      'There is too much sugar.',
      'I have little money.',
      'We need more chairs.',
    ],
    [
      'அதிக சர்க்கரை உள்ளது.',
      'என்னிடம் சிறிது பணம் உள்ளது.',
      'எங்களுக்கு மேலும் நாற்காலிகள் தேவை.',
    ],
  ),
  _l(
    28,
    'Comparisons',
    'Bigger / the biggest',
    'ஒப்பீடு: bigger than, the biggest.',
    [
      _w('big', 'பெரிய', 'பிக்', 'This house is big.', 'இந்த வீடு பெரியது.'),
      _w('small', 'சிறிய', 'ஸ்மால்', 'The cup is small.', 'கோப்பை சிறியது.'),
      _w('tall', 'உயரமான', 'டால்', 'He is tall.', 'அவன் உயரமானவன்.'),
      _w('better', 'சிறந்த', 'பெட்டர்', 'This is better.', 'இது சிறந்தது.'),
      _w(
        'best',
        'மிகச் சிறந்த',
        'பெஸ்ட்',
        'She is the best.',
        'அவள் மிகச் சிறந்தவள்.',
      ),
    ],
    [
      'My bag is bigger than yours.',
      'This is the best option.',
      'He runs faster.',
    ],
    [
      'என் பை உங்களுடையதை விட பெரியது.',
      'இது மிகச் சிறந்த வழி.',
      'அவன் வேகமாக ஓடுகிறான்.',
    ],
  ),
  _l(
    29,
    'Conversation',
    'Linking words: and, but, or',
    'இணைப்புச்சொற்கள்: and (மற்றும்), but (ஆனால்), or (அல்லது).',
    [
      _w(
        'and',
        'மற்றும்',
        'ஆண்ட்',
        'I like tea and coffee.',
        'எனக்கு தேநீர் மற்றும் காபி பிடிக்கும்.',
      ),
      _w(
        'but',
        'ஆனால்',
        'பட்',
        'I am tired but happy.',
        'நான் சோர்வாக ஆனால் மகிழ்ச்சியாக இருக்கிறேன்.',
      ),
      _w('or', 'அல்லது', 'ஆர்', 'Tea or coffee?', 'தேநீர் அல்லது காபி?'),
      _w(
        'because',
        'ஏனெனில்',
        'பிகாஸ்',
        'I am late because of traffic.',
        'போக்குவரத்து காரணமாக தாமதம்.',
      ),
      _w(
        'also',
        'மேலும்',
        'ஆல்சோ',
        'She also sings.',
        'அவள் பாடவும் செய்கிறாள்.',
      ),
    ],
    [
      'I am hungry but I will wait.',
      'Do you want water or tea?',
      'He is smart and kind.',
    ],
    [
      'எனக்கு பசி ஆனால் நான் காத்திருப்பேன்.',
      'உங்களுக்கு தண்ணீர் அல்லது தேநீர் வேண்டுமா?',
      'அவன் புத்திசாலி மற்றும் அன்பானவன்.',
    ],
  ),
  _l(
    30,
    'Review',
    'Everyday conversation',
    'அன்றாட உரையாடல்: கேள், பதில் சொல், நன்றி சொல்.',
    [
      _w(
        'welcome',
        'வரவேற்பு',
        'வெல்கம்',
        'You are welcome.',
        'பரவாயில்லை (வரவேற்கிறேன்).',
      ),
      _w(
        'goodbye',
        'பிரியாவிடை',
        'குட்பை',
        'Goodbye, see you soon.',
        'பிரியாவிடை, விரைவில் சந்திப்போம்.',
      ),
      _w(
        'excuse me',
        'மன்னிக்கவும்',
        'எக்ஸ்கியூஸ் மீ',
        'Excuse me, where is the bus stop?',
        'மன்னிக்கவும், பஸ் நிலையம் எங்கே?',
      ),
      _w(
        'how are you',
        'எப்படி இருக்கிறீர்கள்',
        'ஹவ் ஆர் யூ',
        'How are you today?',
        'இன்று எப்படி இருக்கிறீர்கள்?',
      ),
      _w(
        'see you',
        'பார்க்கிறேன்',
        'சீ யூ',
        'See you tomorrow.',
        'நாளை பார்க்கிறேன்.',
      ),
    ],
    ['Thank you very much.', 'Have a nice day.', 'It was nice to meet you.'],
    ['மிக்க நன்றி.', 'இனிய நாள் அமையட்டும்.', 'உங்களை சந்தித்தது மகிழ்ச்சி.'],
  ),
];

/// Parsed grammar block for a lesson.
class GrammarInfo {
  const GrammarInfo({
    required this.title,
    required this.explanationTa,
    required this.sentencesEn,
    required this.sentencesTa,
  });

  final String title;
  final String explanationTa;
  final List<String> sentencesEn;
  final List<String> sentencesTa;
}

/// Decodes a lesson's `grammarJson` column into a [GrammarInfo], returning
/// `null` when absent or malformed so the UI can degrade gracefully.
GrammarInfo? learningGrammar(String json) {
  if (json.isEmpty) return null;
  try {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return GrammarInfo(
      title: (map['title'] ?? '') as String,
      explanationTa: (map['explanationTa'] ?? '') as String,
      sentencesEn:
          ((map['sentencesEn'] ?? const []) as List)
              .map((e) => e.toString())
              .toList(),
      sentencesTa:
          ((map['sentencesTa'] ?? const []) as List)
              .map((e) => e.toString())
              .toList(),
    );
  } catch (_) {
    return null;
  }
}
