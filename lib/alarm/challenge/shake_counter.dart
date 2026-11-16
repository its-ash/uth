import 'dart:math';

/// Counts shakes from accelerometer readings (m/s^2 including gravity, about 9.8 when still).
///
/// A shake is a reading above [threshold] at least [minGap] after the previous one.
class ShakeCounter {
  ShakeCounter({this.threshold = 20, this.minGap = const Duration(milliseconds: 300)});

  final double threshold;
  final Duration minGap;
  int count = 0;
  Duration? _last;

  /// Feeds one reading taken at [time] (any monotonic clock). Returns true when it counted as a shake.
  bool add(double x, double y, double z, Duration time) {
    final magnitude = sqrt(x * x + y * y + z * z);
    if (magnitude < threshold) return false;
    final last = _last;
    if (last != null && time - last < minGap) return false;
    _last = time;
    count++;
    return true;
  }
}
