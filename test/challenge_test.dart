import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:uth/alarm/alarm.dart';
import 'package:uth/alarm/challenge/math_challenge.dart';
import 'package:uth/alarm/challenge/sentence_challenge.dart';
import 'package:uth/alarm/challenge/shake_counter.dart';

/// Evaluates "a op b" or "a x b op c" so the generator's answers are checked independently.
int evaluate(String q) {
  final t = q.split(' ');
  int apply(int a, String op, int b) => switch (op) {
    '+' => a + b,
    '−' => a - b,
    '×' => a * b,
    _ => throw ArgumentError(op),
  };
  var value = apply(int.parse(t[0]), t[1], int.parse(t[2]));
  if (t.length == 5) value = apply(value, t[3], int.parse(t[4]));
  return value;
}

void main() {
  group('generateMathProblems', () {
    for (final d in Difficulty.values) {
      test('${d.name}: right count, correct and positive answers', () {
        final problems = generateMathProblems(d, 200, Random(42));
        expect(problems, hasLength(200));
        for (final p in problems) {
          expect(p.answer, evaluate(p.question), reason: p.question);
          expect(p.answer, greaterThan(0), reason: p.question);
        }
      });

      test('${d.name}: no question twice in a row', () {
        final problems = generateMathProblems(d, 200, Random(7));
        for (var i = 1; i < problems.length; i++) {
          expect(problems[i].question, isNot(problems[i - 1].question));
        }
      });
    }

    test('easy stays small, hard is bigger than easy', () {
      final easy = generateMathProblems(Difficulty.easy, 100, Random(1));
      final hard = generateMathProblems(Difficulty.hard, 100, Random(1));
      expect(easy.every((p) => p.answer <= 100), isTrue);
      expect(hard.map((p) => p.answer).reduce(max), greaterThan(100));
    });

    test('the same seed gives the same problems', () {
      final a = generateMathProblems(Difficulty.medium, 5, Random(3)).map((p) => p.question).toList();
      final b = generateMathProblems(Difficulty.medium, 5, Random(3)).map((p) => p.question).toList();
      expect(a, b);
    });

    test('accepts the answer with spaces, rejects others and junk', () {
      const p = MathProblem('6 × 7', 42);
      expect(p.accepts('42'), isTrue);
      expect(p.accepts(' 42 '), isTrue);
      expect(p.accepts('41'), isFalse);
      expect(p.accepts(''), isFalse);
      expect(p.accepts('4x2'), isFalse);
    });
  });

  group('sentence', () {
    test('ignores case and extra spaces but not words', () {
      const s = 'I am awake now';
      expect(sentenceMatches(s, 'i  AM awake   now '), isTrue);
      expect(sentenceMatches(s, 'I am awake'), isFalse);
      expect(sentenceMatches(s, 'I am asleep now'), isFalse);
    });

    test('pickSentence returns one of the list', () {
      expect(sentences, contains(pickSentence(Random(1))));
    });
  });

  group('ShakeCounter', () {
    Duration ms(int v) => Duration(milliseconds: v);

    test('still phone (gravity only) never counts', () {
      final c = ShakeCounter();
      for (var i = 0; i < 100; i++) {
        c.add(0, 0, 9.8, ms(i * 20));
      }
      expect(c.count, 0);
    });

    test('hard readings count, with a gap between shakes', () {
      final c = ShakeCounter();
      expect(c.add(25, 0, 0, ms(0)), isTrue);
      expect(c.add(25, 0, 0, ms(100)), isFalse); // same shake
      expect(c.add(0, 30, 0, ms(400)), isTrue);
      expect(c.count, 2);
    });
  });
}
