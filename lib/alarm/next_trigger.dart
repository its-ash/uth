import 'alarm.dart';

/// Builds a local date and time. Tests pass their own to simulate a daylight-saving gap.
typedef LocalTimeBuilder = DateTime Function(int year, int month, int day, int hour, int minute);

DateTime _local(int y, int m, int d, int h, int mi) => DateTime(y, m, d, h, mi);

/// The first moment strictly after [now] that an alarm at [hour]:[minute] rings.
///
/// [days] are ISO weekdays (Monday = 1 ... Sunday = 7); empty means one-shot: the next time the clock shows
/// that time. A time skipped by daylight saving rings at the shifted time of the same day (the system
/// clock decides the shift). Twin of `AlarmMath.nextTrigger` in AlarmMath.kt.
DateTime? nextTrigger({
  required int hour,
  required int minute,
  required Set<int> days,
  required DateTime now,
  LocalTimeBuilder build = _local,
}) {
  for (var offset = 0; offset <= 8; offset++) {
    // The weekday of a calendar date does not depend on the time zone: use UTC.
    final weekday = DateTime.utc(now.year, now.month, now.day + offset).weekday;
    if (days.isNotEmpty && !days.contains(weekday)) continue;
    final at = build(now.year, now.month, now.day + offset, hour, minute);
    if (at.isAfter(now)) return at;
  }
  return null;
}

/// The soonest ring of the enabled alarms.
({Alarm alarm, DateTime at})? nextAlarm(Iterable<Alarm> alarms, DateTime now, {LocalTimeBuilder build = _local}) {
  ({Alarm alarm, DateTime at})? best;
  for (final a in alarms) {
    if (!a.enabled) continue;
    final at = nextTrigger(hour: a.hour, minute: a.minute, days: a.days, now: now, build: build);
    if (at != null && (best == null || at.isBefore(best.at))) best = (alarm: a, at: at);
  }
  return best;
}

/// "7 h 20 min", "2 days 3 h", "Less than a minute".
String describeRemaining(Duration d) {
  final minutes = (d.inSeconds / 60).ceil();
  if (minutes <= 0) return 'less than a minute';
  final days = minutes ~/ (24 * 60);
  final hours = (minutes % (24 * 60)) ~/ 60;
  final mins = minutes % 60;
  if (days > 0) return '$days ${days == 1 ? 'day' : 'days'}${hours > 0 ? ' $hours h' : ''}';
  if (hours > 0) return mins > 0 ? '$hours h $mins min' : '$hours h';
  return '$mins min';
}
