# Uth (package: uth / com.itsash.uth)

Offline alarm clock with a dismiss challenge. Flutter is the UI (alarm list, editor, settings, ring
screen); Kotlin owns the data and everything that must work with the app closed.

## Data contract (Kotlin and Dart)

- Alarms live natively in SharedPreferences `uth_prefs`, key `alarms`: a JSON array. Dart reads and writes
  the whole array (`getAlarms` / `saveAlarms`); each save reschedules the system alarm.
- Alarm JSON keys: `id` (epoch ms), `hour`, `minute`, `days` (ISO weekdays 1=Mon..7=Sun, empty = once), `label`,
  `sound` (ringtone URI or null = default alarm), `soundTitle`, `vibrate`, `gradual`, `enabled`, `maxSnoozes`,
  and Dart-only `challenge` (none|math|shake|qr|sentence), `difficulty`, `count`, `qrCode`.
  Kotlin (`Alarm.fromJson`) reads only the first group; add a key in `alarm.dart` and, if native needs it, in
  `AlarmStore.kt`.
- Native-only keys: `snoozeId`, `snoozeAt`, `snoozeCount`, `askedNotifications`.

## Ringing

- `Scheduler.kt` keeps ONE `AlarmManager.setAlarmClock` alarm: the earliest of all enabled alarms and a pending
  snooze (`AlarmMath.nextTrigger`, `SNOOZE_MS` = 5 min). Falls back to `setAndAllowWhileIdle` if exact alarms are
  revoked. Two alarms in the same minute: only the first rings (the other goes to its next day).
- `AlarmReceiver` (fire): clears the snooze or resets the snooze count, switches one-shot alarms off, reschedules,
  then starts `AlarmService`. `BootReceiver`: boot, app update, TIME_SET, TIMEZONE_CHANGED, exact-alarm permission change
  -> `Scheduler.reschedule`.
- `AlarmService`: foreground service, type `mediaPlayback`. MediaPlayer on `USAGE_ALARM` (raises a muted alarm
  stream to 60 percent), looping; gradual volume over 45 s; vibration; partial wake lock; full-screen-intent
  notification (channel `alarm`). Stops after 15 min with a "Missed alarm" notification.
- `RingActivity`: a `FlutterActivity` with initial route `/ring`, `showWhenLocked` + `turnScreenOn`, own task.
  `main.dart` shows `RingScreen` for that route. The alarm JSON comes from the intent (`ringInfo`).
  Solving the challenge calls `dismiss`; Snooze calls `snooze` (limited by `maxSnoozes`).
- Test alarm: `testAlarm` starts the service with `test=true`; dismiss/snooze then never touch the schedule.
- If the camera or accelerometer is unavailable the ring screen offers / falls back to a math challenge.

## Channel `com.itsash.uth/control` (`UthChannel.kt`, `lib/alarm/alarm_platform.dart`)

`getAlarms`, `saveAlarms`, `status` -> `{notifications, exactAlarms, fullScreen}`, `requestNotifications`,
`openExactAlarmSettings`, `openFullScreenSettings`, `pickRingtone` (MainActivity), `ringtoneTitle`, `testAlarm`,
`ringInfo`, `dismiss`, `snooze`.

## Permissions

`SCHEDULE_EXACT_ALARM` (max SDK 32) + `USE_EXACT_ALARM` (13+), `USE_FULL_SCREEN_INTENT` (14+ user-revocable),
`FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `POST_NOTIFICATIONS`, `WAKE_LOCK`, `VIBRATE`,
`RECEIVE_BOOT_COMPLETED`, `CAMERA` (QR; `mobile_scanner` asks at use), `INTERNET` (update check only).

## Code layout

- `lib/alarm/`: model, `next_trigger.dart` (Dart twin of `AlarmMath.kt`), platform, store, `challenge/` (pure:
  math generator, sentences, shake counter).
- `lib/screens/`: home, editor, settings (Permissions, then `UiAppearanceSection`,
  `UiUpdateSection(storeId: 'uth')`, `UiDeveloperSection`), ring, QR scan, `challenges/` views.
- Tests: `test/` (next trigger incl. DST, math generator, shake, store with a fake platform) and
  `android/app/src/test/` (`AlarmMathTest`, incl. DST in America/New_York).

## Commands

- `make run`, `make build`, `make test` (analyze + Dart tests), `make test-native` (Kotlin tests), `make clean`.
- Icon: `assets/icon/*.svg` -> PNG at 1024, then `dart run flutter_launcher_icons`. Notification icon:
  `res/drawable/ic_stat_alarm.xml`.

## Conventions

- minSdk 26. UI only from `../theme` (read `../theme/COMPONENTS.md`). No analytics; the only network use is
  `UiUpdateSection`.

## Release (Ash Store)

- `store.json` (id `uth`, repo its-ash/uth), `store.mk`, `index.html` + `CNAME` (`uth.itsash.in`). See
  `../ash-store/store-kit/STORE.md`.
- `make deploy` = bump version -> build -> commit, tag `vX.Y.Z`, push -> GitHub release with `uth.apk`. Never create
  releases, tags or asset names by hand.
- Do not edit `store.mk` here. Edit `../ash-store/store-kit/store.mk`, then run `make store-sync` at the workspace root.
