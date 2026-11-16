import 'dart:async';

import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../alarm/alarm.dart';
import '../alarm/alarm_store.dart';
import '../alarm/next_trigger.dart';
import 'alarm_editor_screen.dart';
import 'settings_screen.dart';

/// The alarm list, the next-alarm text and permission warnings.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final AlarmStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AppLifecycleListener _lifecycle;
  Timer? _tick;
  DateTime _now = DateTime.now();

  AlarmStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    store.load();
    // Back from a permission screen or after a one-shot alarm rang: read the phone again.
    _lifecycle = AppLifecycleListener(onResume: store.load);
    _tick = Timer.periodic(const Duration(seconds: 20), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _tick?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _edit(Alarm alarm, {required bool isNew}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AlarmEditorScreen(store: store, alarm: alarm, isNew: isNew)),
    );
    if (mounted) setState(() => _now = DateTime.now());
  }

  Future<void> _testAlarm() async {
    final base = store.alarms.isNotEmpty ? store.alarms.first : Alarm.create();
    await store.platform.testAlarm(base);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final next = nextAlarm(store.alarms, _now);
        return UiScaffold(
          appBar: UiAppBar(
            title: 'Uth',
            actions: [
              UiIconButton(Icons.notifications_active_rounded, tooltip: 'Test alarm', onPressed: _testAlarm),
              UiIconButton(
                Icons.settings_rounded,
                tooltip: 'Settings',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => SettingsScreen(store: store)),
                ),
              ),
            ],
          ),
          fab: UiFab(
            Icons.add_rounded,
            label: 'New alarm',
            onPressed: () => _edit(Alarm.create(), isNew: true),
          ),
          scrollable: true,
          body: !store.ready
              ? const Padding(padding: EdgeInsets.only(top: UiSpace.xl), child: Center(child: UiSpinner(size: 28)))
              : UiColumn(
                  gap: UiSpace.md,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _NextAlarmText(next: next, now: _now),
                    ..._warnings(),
                    if (store.alarms.isEmpty)
                      const UiEmptyState(
                        title: 'No alarms yet',
                        message: 'Add one, then pick how hard it is to switch off.',
                        icon: Icons.alarm_rounded,
                      )
                    else
                      for (final a in store.alarms)
                        _AlarmCard(
                          alarm: a,
                          onTap: () => _edit(a, isNew: false),
                          onToggle: (v) => store.setEnabled(a, v),
                        ),
                    const SizedBox(height: 80),
                  ],
                ),
        );
      },
    );
  }

  List<Widget> _warnings() {
    final s = store.status;
    if (s.allGood || store.alarms.isEmpty) return const [];
    return [
      if (!s.notifications)
        UiAlert(
          'Notifications are blocked. The alarm still rings, but Android may hide the ring screen.',
          status: UiStatus.warning,
          action: UiButton(
            'Allow',
            size: UiSize.sm,
            variant: UiButtonVariant.soft,
            onPressed: () async {
              await store.platform.requestNotifications();
              await Future<void>.delayed(const Duration(seconds: 1));
              await store.refreshStatus();
            },
          ),
        ),
      if (!s.exactAlarms)
        UiAlert(
          'Exact alarms are off, so alarms may ring a few minutes late.',
          status: UiStatus.warning,
          action: UiButton(
            'Allow',
            size: UiSize.sm,
            variant: UiButtonVariant.soft,
            onPressed: store.platform.openExactAlarmSettings,
          ),
        ),
      if (!s.fullScreen)
        UiAlert(
          'Full-screen alerts are off, so the ring screen will not open over the lock screen.',
          status: UiStatus.warning,
          action: UiButton(
            'Allow',
            size: UiSize.sm,
            variant: UiButtonVariant.soft,
            onPressed: store.platform.openFullScreenSettings,
          ),
        ),
    ];
  }
}

class _NextAlarmText extends StatelessWidget {
  const _NextAlarmText({required this.next, required this.now});

  final ({Alarm alarm, DateTime at})? next;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final n = next;
    final text = n == null ? 'No alarm is on' : 'Next alarm in ${describeRemaining(n.at.difference(now))}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: UiSpace.sm),
      child: Text(text, style: context.text.headlineSmall),
    );
  }
}

class _AlarmCard extends StatelessWidget {
  const _AlarmCard({required this.alarm, required this.onTap, required this.onToggle});

  final Alarm alarm;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  static String time(Alarm a) =>
      '${a.hour.toString().padLeft(2, '0')}:${a.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final muted = alarm.enabled ? colors.text : colors.textDisabled;
    final subtitle = [
      alarm.repeatLabel,
      if (alarm.label.isNotEmpty) alarm.label,
    ].join(' · ');
    return UiCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(time(alarm), style: context.text.displaySmall?.copyWith(color: muted)),
                const SizedBox(height: UiSpace.xs),
                Text(subtitle, style: context.text.bodySmall),
                const SizedBox(height: UiSpace.sm),
                UiChip(alarm.effectiveChallenge.label, size: UiSize.sm, variant: UiChipVariant.soft, icon: _icon(alarm)),
              ],
            ),
          ),
          UiSwitch(alarm.enabled, onChanged: onToggle),
        ],
      ),
    );
  }

  static IconData _icon(Alarm a) => switch (a.effectiveChallenge) {
    ChallengeType.none => Icons.touch_app_rounded,
    ChallengeType.math => Icons.calculate_rounded,
    ChallengeType.shake => Icons.vibration_rounded,
    ChallengeType.qr => Icons.qr_code_scanner_rounded,
    ChallengeType.sentence => Icons.keyboard_rounded,
  };
}
