import 'package:flutter/foundation.dart';

import 'alarm.dart';
import 'alarm_platform.dart';

/// UI state: the alarm list and the permission status. Every change is saved to native code first.
class AlarmStore extends ChangeNotifier {
  AlarmStore({this.platform = const ChannelAlarmPlatform()});

  final AlarmPlatform platform;

  List<Alarm> _alarms = const [];
  PlatformStatus _status = const PlatformStatus();
  bool _ready = false;

  List<Alarm> get alarms => _alarms;
  PlatformStatus get status => _status;
  bool get ready => _ready;

  /// Reads the phone again: on start and whenever the app comes back (a one-shot alarm may have switched off).
  Future<void> load() async {
    _alarms = _sorted(await platform.loadAlarms());
    _status = await platform.status();
    _ready = true;
    notifyListeners();
  }

  Future<void> refreshStatus() async {
    _status = await platform.status();
    notifyListeners();
  }

  /// Adds the alarm, or replaces the one with the same id.
  Future<void> save(Alarm alarm) async {
    final next = [for (final a in _alarms) if (a.id != alarm.id) a, alarm];
    await _commit(next);
  }

  Future<void> setEnabled(Alarm alarm, bool enabled) => save(alarm.copyWith(enabled: enabled));

  Future<void> delete(Alarm alarm) => _commit([for (final a in _alarms) if (a.id != alarm.id) a]);

  Future<void> _commit(List<Alarm> next) async {
    _alarms = _sorted(next);
    notifyListeners();
    await platform.saveAlarms(_alarms);
  }

  static List<Alarm> _sorted(List<Alarm> list) =>
      [...list]..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
}
