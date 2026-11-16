import 'dart:math';

import '../alarm.dart';

/// One question with a whole-number answer.
class MathProblem {
  const MathProblem(this.question, this.answer);

  final String question;
  final int answer;

  /// True when [input] (what the user typed) is the answer.
  bool accepts(String input) => int.tryParse(input.trim()) == answer;
}

/// Makes the problems for the math dismiss challenge. Pure; pass a seeded [Random] in tests.
///
/// - easy: add or subtract two numbers up to 50.
/// - medium: multiply 6..12 by 3..9, or add two 2-digit numbers.
/// - hard: (a x b) plus or minus c, with a 12..29, b 3..9, c 10..99, and a positive answer.
List<MathProblem> generateMathProblems(Difficulty difficulty, int count, Random random) {
  final problems = <MathProblem>[];
  String? last;
  while (problems.length < count) {
    final p = switch (difficulty) {
      Difficulty.easy => _easy(random),
      Difficulty.medium => _medium(random),
      Difficulty.hard => _hard(random),
    };
    if (p.question == last) continue; // never the same question twice in a row
    last = p.question;
    problems.add(p);
  }
  return problems;
}

int _between(Random r, int min, int max) => min + r.nextInt(max - min + 1);

MathProblem _easy(Random r) {
  final a = _between(r, 10, 50), b = _between(r, 5, 50);
  if (r.nextBool()) return MathProblem('$a + $b', a + b);
  final lo = min(a, b), hi = max(a, b) == lo ? lo + 1 : max(a, b); // never 0
  return MathProblem('$hi − $lo', hi - lo);
}

MathProblem _medium(Random r) {
  if (r.nextBool()) {
    final a = _between(r, 6, 12), b = _between(r, 3, 9);
    return MathProblem('$a × $b', a * b);
  }
  final a = _between(r, 20, 99), b = _between(r, 20, 99);
  return MathProblem('$a + $b', a + b);
}

MathProblem _hard(Random r) {
  final a = _between(r, 12, 29), b = _between(r, 3, 9), c = _between(r, 10, 99);
  final product = a * b;
  if (r.nextBool() || product - c <= 0) return MathProblem('$a × $b + $c', product + c);
  return MathProblem('$a × $b − $c', product - c);
}
