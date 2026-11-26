package com.itsash.uth

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel "com.itsash.uth/control" (Dart side: lib/alarm/alarm_platform.dart), shared by
 * [MainActivity] and [RingActivity]:
 *   - getAlarms() -> JSON array string. saveAlarms(String) saves it and reschedules the system alarm.
 *   - status() -> {notifications, exactAlarms, fullScreen}.
 *   - requestNotifications(), openExactAlarmSettings(), openFullScreenSettings().
 *   - ringtoneTitle({uri?}) -> String. (pickRingtone is in MainActivity.)
 *   - testAlarm({json}): rings now, flagged as a test (never touches the schedule).
 *   - ringInfo() -> {alarm: JSON string, test, snoozesUsed}, for the ring screen.
 *   - dismiss({id, test}): stops the ringing and closes the ring screen. snooze({id, test}): same, rings again later.
 */
object UthChannel {
    const val NAME = "com.itsash.uth/control"
    private const val REQUEST_NOTIFICATIONS = 1

    fun install(
        activity: Activity,
        messenger: BinaryMessenger,
        extra: (MethodCall, MethodChannel.Result) -> Boolean = { _, _ -> false },
    ): MethodChannel {
        val store = AlarmStore(activity)
        val channel = MethodChannel(messenger, NAME)
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getAlarms" -> result.success(store.alarmsJson)
                    "saveAlarms" -> {
                        store.alarmsJson = call.arguments<String>() ?: "[]"
                        Scheduler.reschedule(activity)
                        result.success(null)
                    }
                    "status" -> result.success(status(activity))
                    "requestNotifications" -> {
                        requestNotifications(activity, store)
                        result.success(null)
                    }
                    "openExactAlarmSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            activity.startActivity(
                                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:${activity.packageName}")),
                            )
                        }
                        result.success(null)
                    }
                    "openFullScreenSettings" -> {
                        if (Build.VERSION.SDK_INT >= 34) {
                            activity.startActivity(
                                Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:${activity.packageName}")),
                            )
                        }
                        result.success(null)
                    }
                    "ringtoneTitle" -> {
                        val uri = call.argument<String>("uri")
                        val target = if (uri.isNullOrEmpty()) {
                            RingtoneManager.getActualDefaultRingtoneUri(activity, RingtoneManager.TYPE_ALARM)
                        } else {
                            Uri.parse(uri)
                        }
                        result.success(target?.let { RingtoneManager.getRingtone(activity, it)?.getTitle(activity) })
                    }
                    "testAlarm" -> {
                        val json = call.argument<String>("json") ?: ""
                        AlarmService.start(activity, json, test = true)
                        result.success(null)
                    }
                    "ringInfo" -> {
                        val json = activity.intent?.getStringExtra(AlarmService.EXTRA_JSON)
                        result.success(
                            mapOf(
                                "alarm" to json,
                                "test" to (activity.intent?.getBooleanExtra(AlarmService.EXTRA_TEST, false) ?: false),
                                "snoozesUsed" to store.snoozeCount,
                            ),
                        )
                    }
                    "dismiss" -> {
                        AlarmService.stop(activity)
                        if (call.argument<Boolean>("test") != true) store.snoozeCount = 0
                        activity.finishAndRemoveTask()
                        result.success(null)
                    }
                    "snooze" -> {
                        val id = (call.argument<Number>("id") ?: 0).toLong()
                        if (call.argument<Boolean>("test") != true) {
                            store.snoozeCount = store.snoozeCount + 1
                            store.snoozeId = id
                            store.snoozeAt = System.currentTimeMillis() + AlarmMath.SNOOZE_MS
                            Scheduler.reschedule(activity)
                        }
                        AlarmService.stop(activity)
                        activity.finishAndRemoveTask()
                        result.success(null)
                    }
                    else -> if (!extra(call, result)) result.notImplemented()
                }
            } catch (e: Throwable) {
                result.error("failed", e.message, null)
            }
        }
        return channel
    }

    private fun notificationsAllowed(activity: Activity): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        } else {
            activity.getSystemService(NotificationManager::class.java).areNotificationsEnabled()
        }

    private fun status(activity: Activity): Map<String, Any?> {
        val nm = activity.getSystemService(NotificationManager::class.java)
        return mapOf(
            "notifications" to notificationsAllowed(activity),
            "exactAlarms" to Scheduler.canScheduleExact(activity.getSystemService(AlarmManager::class.java)),
            "fullScreen" to (Build.VERSION.SDK_INT < 34 || nm.canUseFullScreenIntent()),
        )
    }

    /** System dialog the first time (Android 13+); after a denial it no longer shows, so open the app's settings. */
    private fun requestNotifications(activity: Activity, store: AlarmStore) {
        if (notificationsAllowed(activity)) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && !store.askedNotifications) {
            store.askedNotifications = true
            activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
        } else {
            activity.startActivity(
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName),
            )
        }
    }
}
