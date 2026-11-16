import 'dart:math';

const sentences = [
  'The early bird catches the worm and I am not a worm',
  'I am awake and I will get out of bed right now',
  'Every morning I choose to stand up and start the day',
  'A glass of cold water and a short walk will wake me up',
  'The snooze button will not make me feel any better today',
  'Today is a good day to do something I will be proud of',
];

/// A random sentence to retype.
String pickSentence(Random random) => sentences[random.nextInt(sentences.length)];

String _normalize(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Whether [input] retypes [target]: case and extra spaces do not matter, every word does.
bool sentenceMatches(String target, String input) => _normalize(target) == _normalize(input);
