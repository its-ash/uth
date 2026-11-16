import 'package:flutter_test/flutter_test.dart';
import 'package:uth/alarm/alarm.dart';
import 'package:uth/alarm/alarm_platform.dart';
import 'package:uth/alarm/alarm_store.dart';

class FakePlatform implements AlarmPlatform {
  List<Alarm> saved = [];
  int saves = 0;
  PlatformStatus current = const PlatformStatus();

  @override
  Future<List<Alarm>> loadAlarms() async => saved;

  @override
  Future<void> saveAlarms(List<Alarm> alarms) async {
    saved = alarms;
    saves++;
  }

  @override
  Future<PlatformStatus> status() async => current;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

void main() {
  test('adds, edits, toggles and deletes, saving every change', () async {
    final platform = FakePlatform();
    final store = AlarmStore(platform: platform);
    await store.load();
    expect(store.ready, isTrue);
    expect(store.alarms, isEmpty);

    const late = Alarm(id: 1, hour: 22, minute: 0);
    const early = Alarm(id: 2, hour: 6, minute: 30);
    await store.save(late);
    await store.save(early);
    expect(store.alarms.map((a) => a.id), [2, 1], reason: 'sorted by time of day');
    expect(platform.saved.map((a) => a.id), [2, 1]);

    await store.save(early.copyWith(hour: 23));
    expect(store.alarms.map((a) => a.id), [1, 2]);
    expect(store.alarms, hasLength(2), reason: 'same id replaces');

    await store.setEnabled(early, false);
    expect(store.alarms.firstWhere((a) => a.id == 2).enabled, isFalse);

    await store.delete(late);
    expect(store.alarms.map((a) => a.id), [2]);
    expect(platform.saves, 5);
  });

  test('load reads what native code saved, including a one-shot that switched itself off', () async {
    final platform = FakePlatform()..saved = [const Alarm(id: 1, hour: 7, minute: 0, enabled: false)];
    final store = AlarmStore(platform: platform);
    await store.load();
    expect(store.alarms.single.enabled, isFalse);
  });

  test('status comes from the platform', () async {
    final platform = FakePlatform()..current = const PlatformStatus(exactAlarms: false);
    final store = AlarmStore(platform: platform);
    await store.load();
    expect(store.status.exactAlarms, isFalse);
    expect(store.status.allGood, isFalse);
  });
}
