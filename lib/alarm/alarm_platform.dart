import 'dart:convert';

import 'package:flutter/services.dart';

import 'alarm.dart';

/// What the phone currently allows. Each missing permission can make an alarm late or silent.
class PlatformStatus {
  const PlatformStatus({this.notifications = true, this.exactAlarms = true, this.fullScreen = true});

  factory PlatformStatus.fromMap(Map<Object?, Object?> map) => PlatformStatus(
    notifications: map['notifications'] as bool? ?? true,
    exactAlarms: map['exactAlarms'] as bool? ?? true,
    fullScreen: map['fullScreen'] as bool? ?? true,
  );

  /// POST_NOTIFICATIONS (Android 13+): without it the ring notification is hidden.
  final bool notifications;

  /// Exact alarms allowed (Android 12+). Without it alarms may be a few minutes late.
  final bool exactAlarms;

  /// Full-screen intent allowed (Android 14+). Without it the ring screen does not open over the lock screen.
  final bool fullScreen;

  bool get allGood => notifications && exactAlarms && fullScreen;
}

/// A ringtone picked by the user. [uri] null means the system default alarm sound.
class PickedSound {
  const PickedSound({this.uri, this.title});

  final String? uri;
  final String? title;
}

/// What the ring screen needs to know when it opens.
class RingInfo {
  const RingInfo({required this.alarm, required this.test, required this.snoozesUsed});

  final Alarm alarm;

  /// A test alarm: dismissing or snoozing never touches the schedule.
  final bool test;
  final int snoozesUsed;
}

/// Everything the UI needs from native code. The real implementation is [ChannelAlarmPlatform]; tests use a fake.
abstract interface class AlarmPlatform {
  Future<List<Alarm>> loadAlarms();

  /// Saves the whole list and reschedules the system alarm.
  Future<void> saveAlarms(List<Alarm> alarms);
  Future<PlatformStatus> status();
  Future<void> requestNotifications();
  Future<void> openExactAlarmSettings();
  Future<void> openFullScreenSettings();

  /// Shows the system ringtone picker. Null when cancelled.
  Future<PickedSound?> pickRingtone({String? current});
  Future<String?> ringtoneTitle(String? uri);

  /// Rings [alarm] right now, flagged as a test.
  Future<void> testAlarm(Alarm alarm);

  /// For the ring screen.
  Future<RingInfo?> ringInfo();
  Future<void> dismiss(Alarm alarm, {required bool test});
  Future<void> snooze(Alarm alarm, {required bool test});
}

/// Dart side of MethodChannel "com.itsash.uth/control" (UthChannel.kt).
class ChannelAlarmPlatform implements AlarmPlatform {
  const ChannelAlarmPlatform();

  static const _channel = MethodChannel('com.itsash.uth/control');

  @override
  Future<List<Alarm>> loadAlarms() async {
    final raw = await _channel.invokeMethod<String>('getAlarms') ?? '[]';
    try {
      return [for (final o in jsonDecode(raw) as List<Object?>) Alarm.fromJson((o as Map).cast<String, Object?>())];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> saveAlarms(List<Alarm> alarms) =>
      _channel.invokeMethod('saveAlarms', jsonEncode([for (final a in alarms) a.toJson()]));

  @override
  Future<PlatformStatus> status() async =>
      PlatformStatus.fromMap(await _channel.invokeMapMethod<Object?, Object?>('status') ?? const {});

  @override
  Future<void> requestNotifications() => _channel.invokeMethod('requestNotifications');

  @override
  Future<void> openExactAlarmSettings() => _channel.invokeMethod('openExactAlarmSettings');

  @override
  Future<void> openFullScreenSettings() => _channel.invokeMethod('openFullScreenSettings');

  @override
  Future<PickedSound?> pickRingtone({String? current}) async {
    final map = await _channel.invokeMapMethod<Object?, Object?>('pickRingtone', {'uri': current});
    if (map == null) return null;
    return PickedSound(uri: map['uri'] as String?, title: map['title'] as String?);
  }

  @override
  Future<String?> ringtoneTitle(String? uri) => _channel.invokeMethod<String>('ringtoneTitle', {'uri': uri});

  @override
  Future<void> testAlarm(Alarm alarm) => _channel.invokeMethod('testAlarm', {'json': jsonEncode(alarm.toJson())});

  @override
  Future<RingInfo?> ringInfo() async {
    final map = await _channel.invokeMapMethod<Object?, Object?>('ringInfo');
    final json = map?['alarm'] as String?;
    if (map == null || json == null) return null;
    return RingInfo(
      alarm: Alarm.fromJson((jsonDecode(json) as Map).cast<String, Object?>()),
      test: map['test'] as bool? ?? false,
      snoozesUsed: (map['snoozesUsed'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> dismiss(Alarm alarm, {required bool test}) =>
      _channel.invokeMethod('dismiss', {'id': alarm.id, 'test': test});

  @override
  Future<void> snooze(Alarm alarm, {required bool test}) =>
      _channel.invokeMethod('snooze', {'id': alarm.id, 'test': test});
}
