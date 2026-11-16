import 'dart:math';

import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../../alarm/alarm.dart';
import '../../alarm/challenge/math_challenge.dart';

/// Shows one problem at a time; [onSolved] fires after the last one is answered correctly.
class MathView extends StatefulWidget {
  const MathView({super.key, required this.difficulty, required this.count, required this.onSolved, this.random});

  final Difficulty difficulty;
  final int count;
  final VoidCallback onSolved;

  /// For tests.
  final Random? random;

  @override
  State<MathView> createState() => _MathViewState();
}

class _MathViewState extends State<MathView> {
  late final List<MathProblem> _problems = generateMathProblems(
    widget.difficulty,
    widget.count,
    widget.random ?? Random(),
  );
  final _controller = TextEditingController();
  int _index = 0;
  bool _wrong = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_problems[_index].accepts(_controller.text)) {
      _controller.clear();
      if (_index + 1 >= _problems.length) {
        widget.onSolved();
        return;
      }
      setState(() {
        _index++;
        _wrong = false;
      });
    } else {
      _controller.clear();
      setState(() => _wrong = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problems[_index];
    return UiColumn(
      gap: UiSpace.lg,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Problem ${_index + 1} of ${_problems.length}',
          textAlign: TextAlign.center,
          style: context.text.titleSmall,
        ),
        UiProgressBar(_index / _problems.length),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: UiSpace.md),
          child: Text(problem.question, textAlign: TextAlign.center, style: context.text.displayMedium),
        ),
        UiTextField(
          key: ValueKey(_index),
          controller: _controller,
          hint: 'Answer',
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          error: _wrong ? 'Wrong answer, try again' : null,
        ),
        UiButton('Check', expand: true, onPressed: _submit),
      ],
    );
  }
}
