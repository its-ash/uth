# Uth

An alarm clock you cannot switch off half asleep. Solve math, shake, scan a code or retype a sentence.

**[Website](https://uth.itsash.in)** · **[Download APK](https://github.com/its-ash/uth/releases/latest/download/uth.apk)** · Get it in **[Ash Store](https://store.itsash.in)**

## Features

- **Alarms**: time, repeat days, label, sound (system default alarm or any ringtone), vibration,
  gradual volume and an on/off switch. A one-shot alarm switches itself off after it rings.
- **Dismiss challenge** per alarm: math problems (easy, medium or hard, 1 to 10 of them), shake the phone
  (5 to 100 shakes), scan a QR code or barcode you registered (stick one in the bathroom), or retype a sentence.
- **Limited snoozes**: 0 to 5 per alarm, 5 minutes each.
- **Rings reliably**: an exact system alarm clock alarm, a foreground service on the alarm audio stream, and a
  full-screen ring screen over the lock screen. Alarms come back after a reboot, an app update, a clock change or a
  time zone change.
- **Test alarm** button, and "next alarm in 7 h 20 min" on the home screen.
- **Private**: no account, everything stays on your phone. The only network call is the update check in Settings.

## Install

- **Ash Store**: install [Ash Store](https://store.itsash.in) once, then install and update Uth from it.
- **APK**: download the [latest APK](https://github.com/its-ash/uth/releases/latest/download/uth.apk) on your phone and open it. Allow your browser to install unknown apps if Android asks.

Requires Android 8.0 (API 26) or later. Allow notifications when Android asks. On Android 14 and later also allow
full-screen alerts so the ring screen opens over the lock screen (Settings shows the state of each permission).
Some phone makers kill background apps: if an alarm is late, exclude Uth from battery optimization.

## Develop

Needs Flutter >= 3.44 and the shared theme package at `../theme`.

```bash
make run           # run on a connected device
make test          # flutter analyze + flutter test
make test-native   # JVM tests for the Kotlin alarm math
make build         # release APK
make deploy        # bump version, build, tag, push, GitHub release (see store.mk)
```

## Release

`make deploy` follows the Ash Store kit (`store.mk`, `store.json`): it bumps the
version in `pubspec.yaml`, builds, commits, tags `vX.Y.Z`, pushes, and publishes
a GitHub release with `uth.apk`. Ash Store and the website pick up the new
version from that release.

## Project layout

```
lib/
├── main.dart                     # home app, or the ring screen when started on route "/ring"
├── alarm/
│   ├── alarm.dart                # Alarm model, challenge types, JSON shared with Kotlin
│   ├── next_trigger.dart         # next ring time (repeat days, DST), "in 7 h 20 min"
│   ├── alarm_platform.dart       # MethodChannel to native code
│   ├── alarm_store.dart          # UI state
│   └── challenge/                # math generator, sentences, shake counter (pure)
└── screens/
    ├── home_screen.dart, alarm_editor_screen.dart, settings_screen.dart
    ├── ring_screen.dart, qr_scan_page.dart
    └── challenges/               # math, shake, scan, sentence views
android/app/src/main/kotlin/com/itsash/uth/
├── AlarmMath.kt                  # pure next-trigger rule (unit tested)
├── AlarmStore.kt                 # alarm data (SharedPreferences), native owner
├── Scheduler.kt                  # one AlarmManager.setAlarmClock alarm
├── Receivers.kt                  # alarm fired, boot / time change
├── AlarmService.kt               # foreground service: sound, vibration, notification
├── RingActivity.kt               # Flutter ring screen over the lock screen
└── UthChannel.kt, MainActivity.kt
android/app/src/test/…/AlarmMathTest.kt
```

See `CLAUDE.md` for details.

## License

No license file is included yet.

Built by [itsash.in](https://itsash.in).
