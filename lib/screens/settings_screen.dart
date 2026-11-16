import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../alarm/alarm_store.dart';

/// Permissions, then Appearance, Updates and Developer.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.store});

  final AlarmStore store;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final AppLifecycleListener _lifecycle;

  AlarmStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    store.refreshStatus();
    _lifecycle = AppLifecycleListener(onResume: store.refreshStatus);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UiScaffold(
      appBar: const UiAppBar(title: 'Settings'),
      scrollable: true,
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final s = store.status;
          return UiColumn(
            gap: UiSpace.lg,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UiListGroup(
                header: 'Permissions',
                footer: 'Uth needs these to ring on time and to open over the lock screen.',
                children: [
                  UiListTile(
                    'Notifications',
                    icon: Icons.notifications_rounded,
                    iconStatus: s.notifications ? UiStatus.success : UiStatus.warning,
                    value: s.notifications ? 'Allowed' : 'Blocked',
                    chevron: !s.notifications,
                    onTap: s.notifications ? null : store.platform.requestNotifications,
                  ),
                  UiListTile(
                    'Exact alarms',
                    icon: Icons.alarm_on_rounded,
                    iconStatus: s.exactAlarms ? UiStatus.success : UiStatus.warning,
                    value: s.exactAlarms ? 'Allowed' : 'Off',
                    chevron: !s.exactAlarms,
                    onTap: s.exactAlarms ? null : store.platform.openExactAlarmSettings,
                  ),
                  UiListTile(
                    'Full-screen alerts',
                    icon: Icons.fullscreen_rounded,
                    iconStatus: s.fullScreen ? UiStatus.success : UiStatus.warning,
                    value: s.fullScreen ? 'Allowed' : 'Off',
                    chevron: !s.fullScreen,
                    onTap: s.fullScreen ? null : store.platform.openFullScreenSettings,
                  ),
                ],
              ),
              const UiAppearanceSection(),
              const UiUpdateSection(storeId: 'uth'),
              const UiDeveloperSection(),
            ],
          );
        },
      ),
    );
  }
}
