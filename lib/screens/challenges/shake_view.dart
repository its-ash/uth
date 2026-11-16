import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:theme/theme.dart';

import '../../alarm/challenge/shake_counter.dart';

/// Counts shakes of the phone with the accelerometer; [onSolved] fires at [count].
class ShakeView extends StatefulWidget {
  const ShakeView({super.key, required this.count, required this.onSolved, required this.onUnavailable});

  final int count;
  final VoidCallback onSolved;

  /// The phone has no accelerometer: the ring screen swaps in another challenge.
  final VoidCallback onUnavailable;

  @override
  State<ShakeView> createState() => _ShakeViewState();
}

class _ShakeViewState extends State<ShakeView> {
  final _counter = ShakeCounter();
  final _clock = Stopwatch()..start();
  StreamSubscription<AccelerometerEvent>? _sub;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _sub = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
      (e) {
        if (_finished) return;
        if (_counter.add(e.x, e.y, e.z, _clock.elapsed)) {
          setState(() {});
          if (_counter.count >= widget.count) {
            _finished = true;
            widget.onSolved();
          }
        }
      },
      onError: (Object _) => widget.onUnavailable(),
      cancelOnError: true,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = _counter.count.clamp(0, widget.count);
    return UiColumn(
      gap: UiSpace.lg,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Shake the phone hard', style: context.text.titleMedium),
        UiProgressRing(
          done / widget.count,
          size: 200,
          stroke: 12,
          center: Text('$done / ${widget.count}', style: context.text.displaySmall),
        ),
      ],
    );
  }
}
