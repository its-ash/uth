import 'package:flutter_test/flutter_test.dart';
import 'package:uth/alarm/alarm.dart';
import 'package:uth/alarm/next_trigger.dart';

/// Wall-clock arithmetic in UTC so the tests do not depend on the machine's time zone.
DateTime utc(int y, int m, int d, int h, int mi) => DateTime.utc(y, m, d, h, mi);

DateTime? next(int h, int m, Set<int> days, DateTime now, {LocalTimeBuilder build = utc}) =>
    nextTrigger(hour: h, minute: m, days: days, now: now, build: build);

void main() {
  // 2026-06-10 is a Wednesday.
  final wed8 = utc(2026, 6, 10, 8, 0);

  group('one-shot', () {
    test('later today rings today', () {
      expect(next(9, 30, {}, wed8), utc(2026, 6, 10, 9, 30));
    });

    test('already passed rings tomorrow', () {
      expect(next(7, 30, {}, wed8), utc(2026, 6, 11, 7, 30));
    });

    test('exactly now is not in the future', () {
      expect(next(8, 0, {}, wed8), utc(2026, 6, 11, 8, 0));
    });

    test('rolls over a month end', () {
      expect(next(7, 0, {}, utc(2026, 6, 30, 23, 0)), utc(2026, 7, 1, 7, 0));
    });
  });

  group('repeat days', () {
    test('picks the next matching weekday', () {
      expect(next(7, 0, {1, 5}, wed8), utc(2026, 6, 12, 7, 0)); // Friday
    });

    test('same weekday already passed goes a week ahead', () {
      expect(next(7, 0, {3}, wed8), utc(2026, 6, 17, 7, 0));
    });

    test('same weekday still ahead rings today', () {
      expect(next(9, 0, {3}, wed8), utc(2026, 6, 10, 9, 0));
    });

    test('wraps from Sunday to Monday', () {
      expect(next(7, 0, {1}, utc(2026, 6, 14, 12, 0)), utc(2026, 6, 15, 7, 0)); // Sunday noon
    });
  });

  group('daylight saving', () {
    // Spring forward: 02:30 does not exist on 2026-03-08, the clock jumps to 03:30.
    DateTime gap(int y, int m, int d, int h, int mi) =>
        (y == 2026 && m == 3 && d == 8 && h == 2) ? utc(y, m, d, 3, mi) : utc(y, m, d, h, mi);

    test('a skipped time rings at the shifted time of the same day', () {
      final now = utc(2026, 3, 8, 0, 10);
      expect(next(2, 30, {}, now, build: gap), utc(2026, 3, 8, 3, 30));
      expect(next(2, 30, {7}, now, build: gap), utc(2026, 3, 8, 3, 30)); // Sunday
    });

    test('the day after the gap is back to the normal time', () {
      final now = utc(2026, 3, 8, 4, 0);
      expect(next(2, 30, {}, now, build: gap), utc(2026, 3, 9, 2, 30));
    });

    test('the real local clock agrees on a plain day', () {
      final now = DateTime(2026, 6, 10, 8, 0);
      expect(nextTrigger(hour: 9, minute: 15, days: {}, now: now), DateTime(2026, 6, 10, 9, 15));
    });
  });

  group('nextAlarm', () {
    Alarm alarm(int id, int h, int m, {Set<int> days = const {}, bool enabled = true}) =>
        Alarm(id: id, hour: h, minute: m, days: days, enabled: enabled);

    test('picks the soonest enabled alarm', () {
      final result = nextAlarm([
        alarm(1, 6, 0, enabled: false),
        alarm(2, 12, 0),
        alarm(3, 9, 0),
      ], wed8, build: utc);
      expect(result?.alarm.id, 3);
      expect(result?.at, utc(2026, 6, 10, 9, 0));
    });

    test('null when nothing is on', () {
      expect(nextAlarm([alarm(1, 6, 0, enabled: false)], wed8, build: utc), isNull);
      expect(nextAlarm(const [], wed8, build: utc), isNull);
    });
  });

  group('describeRemaining', () {
    test('formats minutes, hours and days', () {
      expect(describeRemaining(const Duration(seconds: 20)), '1 min');
      expect(describeRemaining(const Duration(minutes: 45)), '45 min');
      expect(describeRemaining(const Duration(hours: 7, minutes: 20)), '7 h 20 min');
      expect(describeRemaining(const Duration(hours: 3)), '3 h');
      expect(describeRemaining(const Duration(days: 1, hours: 2)), '1 day 2 h');
      expect(describeRemaining(Duration.zero), 'less than a minute');
    });
  });

  group('Alarm', () {
    test('JSON round trip keeps every field', () {
      const a = Alarm(
        id: 5,
        hour: 6,
        minute: 45,
        days: {1, 2, 3, 4, 5},
        label: 'Gym',
        sound: 'content://media/x',
        soundTitle: 'Beep',
        vibrate: false,
        gradual: false,
        enabled: false,
        maxSnoozes: 1,
        challenge: ChallengeType.qr,
        difficulty: Difficulty.hard,
        count: 7,
        qrCode: 'bathroom',
      );
      final b = Alarm.fromJson(a.toJson());
      expect(b.toJson(), a.toJson());
      expect(b.repeatLabel, 'Weekdays');
    });

    test('a scan alarm without a code falls back to math', () {
      const a = Alarm(id: 1, hour: 7, minute: 0, challenge: ChallengeType.qr);
      expect(a.effectiveChallenge, ChallengeType.math);
    });
  });
}
