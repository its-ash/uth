package com.itsash.uth

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.time.ZoneId

/** Keeps exactly one system alarm: the earliest of every enabled alarm and a pending snooze. */
object Scheduler {

    const val ACTION_FIRE = "com.itsash.uth.FIRE"
    const val EXTRA_ID = "alarmId"

    fun canScheduleExact(am: AlarmManager): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()

    /** Epoch ms and alarm id of the next ring, or null. */
    fun next(context: Context, nowMs: Long = System.currentTimeMillis()): Pair<Long, Long>? {
        val store = AlarmStore(context)
        var best: Pair<Long, Long>? = null
        val zone = ZoneId.systemDefault()
        for (a in store.alarms()) {
            if (!a.enabled) continue
            val at = AlarmMath.nextTrigger(a.hour, a.minute, a.days, nowMs, zone)
            if (at > 0 && (best == null || at < best.first)) best = at to a.id
        }
        if (store.snoozeAt > nowMs && store.alarm(store.snoozeId) != null) {
            if (best == null || store.snoozeAt < best.first) best = store.snoozeAt to store.snoozeId
        }
        return best
    }

    private fun firePending(context: Context, id: Long): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            REQUEST_FIRE,
            Intent(context, AlarmReceiver::class.java).setAction(ACTION_FIRE).putExtra(EXTRA_ID, id),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    /** Call after any change to the alarms, a snooze, boot, a time change or an app update. */
    fun reschedule(context: Context) {
        val am = context.getSystemService(AlarmManager::class.java)
        val next = next(context)
        if (next == null) {
            am.cancel(firePending(context, 0))
            return
        }
        val (at, id) = next
        val pi = firePending(context, id)
        val show = PendingIntent.getActivity(
            context,
            REQUEST_SHOW,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        try {
            // An alarm clock alarm: exact, wakes the phone from Doze, and shows in the status bar and lock screen.
            am.setAlarmClock(AlarmManager.AlarmClockInfo(at, show), pi)
        } catch (_: SecurityException) {
            // Exact alarms were revoked: fall back to the best the system allows.
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
        }
    }

    private const val REQUEST_FIRE = 100
    private const val REQUEST_SHOW = 101
}
