import 'dart:math';

import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../../alarm/challenge/sentence_challenge.dart';

/// Retype [count] sentences exactly (case and extra spaces do not matter).
class SentenceView extends StatefulWidget {
  const SentenceView({super.key, required this.count, required this.onSolved, this.random});

  final int count;
  final VoidCallback onSolved;
  final Random? random;

  @override
  State<SentenceView> createState() => _SentenceViewState();
}

class _SentenceViewState extends State<SentenceView> {
  late final Random _random = widget.random ?? Random();
  late String _target = pickSentence(_random);
  final _controller = TextEditingController();
  int _done = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _check(String input) {
    if (!sentenceMatches(_target, input)) return;
    _controller.clear();
    if (_done + 1 >= widget.count) {
      widget.onSolved();
      return;
    }
    setState(() {
      _done++;
      _target = pickSentence(_random);
    });
  }

  @override
  Widget build(BuildContext context) {
    return UiColumn(
      gap: UiSpace.lg,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Sentence ${_done + 1} of ${widget.count}',
          textAlign: TextAlign.center,
          style: context.text.titleSmall,
        ),
        UiCard(child: Text(_target, textAlign: TextAlign.center, style: context.text.titleLarge)),
        UiTextField(
          controller: _controller,
          hint: 'Type the sentence above',
          autofocus: true,
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          onChanged: _check,
        ),
      ],
    );
  }
}
