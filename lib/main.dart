import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import 'alarm/alarm_platform.dart';
import 'alarm/alarm_store.dart';
import 'screens/home_screen.dart';
import 'screens/ring_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // RingActivity.kt starts the engine on "/ring": the screen shown over the lock screen while an alarm rings.
  if (PlatformDispatcher.instance.defaultRouteName == '/ring') {
    runApp(const UthRingApp(platform: ChannelAlarmPlatform()));
  } else {
    runApp(UthApp(store: AlarmStore()));
  }
}

class UthApp extends StatelessWidget {
  const UthApp({super.key, required this.store});

  final AlarmStore store;

  @override
  Widget build(BuildContext context) {
    return UiApp(title: 'Uth', home: HomeScreen(store: store));
  }
}

class UthRingApp extends StatelessWidget {
  const UthRingApp({super.key, required this.platform});

  final AlarmPlatform platform;

  @override
  Widget build(BuildContext context) {
    return UiApp(title: 'Uth', home: RingScreen(platform: platform));
  }
}
