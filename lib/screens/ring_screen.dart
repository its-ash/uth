import 'dart:async';

import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../alarm/alarm.dart';
import '../alarm/alarm_platform.dart';
import 'challenges/math_view.dart';
import 'challenges/qr_view.dart';
import 'challenges/sentence_view.dart';
import 'challenges/shake_view.dart';

/// Shown over the lock screen while an alarm rings. The alarm keeps ringing until the challenge is solved.
class RingScreen extends StatefulWidget {
  const RingScreen({super.key, required this.platform});

  final AlarmPlatform platform;

  @override
  State<RingScreen> createState() => _RingScreenState();
}

class _RingScreenState extends State<RingScreen> {
  RingInfo? _info;
  bool _loaded = false;
  bool _mathFallback = false;
  bool _busy = false;
  DateTime _now = DateTime.now();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
    widget.platform.ringInfo().then((info) {
      if (mounted) {
        setState(() {
          _info = info;
          _loaded = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _dismiss() async {
    final info = _info;
    if (info == null || _busy) return;
    _busy = true;
    await widget.platform.dismiss(info.alarm, test: info.test);
  }

  Future<void> _snooze() async {
    final info = _info;
    if (info == null || _busy) return;
    _busy = true;
    await widget.platform.snooze(info.alarm, test: info.test);
  }

  String get _clock =>
      '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return PopScope(
      canPop: false,
      child: UiScaffold(
        scrollable: true,
        body: !_loaded
            ? const Padding(padding: EdgeInsets.only(top: UiSpace.xl), child: Center(child: UiSpinner(size: 28)))
            : info == null
            ? const UiEmptyState(title: 'Nothing is ringing', icon: Icons.alarm_off_rounded)
            : UiColumn(
                gap: UiSpace.lg,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: UiSpace.lg),
                  Text(_clock, textAlign: TextAlign.center, style: context.text.displayLarge),
                  Text(
                    info.alarm.label.isEmpty ? (info.test ? 'Test alarm' : 'Wake up') : info.alarm.label,
                    textAlign: TextAlign.center,
                    style: context.text.headlineSmall,
                  ),
                  const SizedBox(height: UiSpace.md),
                  _challenge(info),
                  const SizedBox(height: UiSpace.lg),
                  ..._footer(info),
                ],
              ),
      ),
    );
  }

  Widget _challenge(RingInfo info) {
    final a = info.alarm;
    final type = _mathFallback ? ChallengeType.math : a.effectiveChallenge;
    return switch (type) {
      ChallengeType.none => UiHoldButton('Hold to dismiss', icon: Icons.alarm_off_rounded, onConfirmed: _dismiss),
      ChallengeType.math => MathView(
        key: ValueKey(_mathFallback),
        difficulty: _mathFallback ? Difficulty.medium : a.difficulty,
        count: _mathFallback ? 3 : a.count,
        onSolved: _dismiss,
      ),
      ChallengeType.shake => ShakeView(
        count: a.count,
        onSolved: _dismiss,
        onUnavailable: () => setState(() => _mathFallback = true),
      ),
      ChallengeType.qr => QrView(
        expected: a.qrCode!,
        onSolved: _dismiss,
        onUnavailable: () => setState(() => _mathFallback = true),
      ),
      ChallengeType.sentence => SentenceView(count: a.count, onSolved: _dismiss),
    };
  }

  List<Widget> _footer(RingInfo info) {
    final left = info.alarm.maxSnoozes - info.snoozesUsed;
    return [
      if (left > 0)
        UiButton(
          'Snooze 5 min ($left left)',
          variant: UiButtonVariant.outline,
          icon: Icons.snooze_rounded,
          expand: true,
          onPressed: _snooze,
        )
      else
        Text(
          info.alarm.maxSnoozes == 0 ? 'No snooze on this alarm' : 'No snoozes left',
          textAlign: TextAlign.center,
          style: context.text.bodySmall,
        ),
      if (info.test)
        UiButton('End test', variant: UiButtonVariant.ghost, expand: true, onPressed: _dismiss),
    ];
  }
}
