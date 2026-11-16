package com.itsash.uth

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** The system alarm went off: start the ringing service, then schedule whatever comes next. */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Scheduler.ACTION_FIRE) return
        val id = intent.getLongExtra(Scheduler.EXTRA_ID, 0)
        val store = AlarmStore(context)
        val alarm = store.alarm(id)
        val fromSnooze = store.snoozeId == id && store.snoozeAt > 0
        if (fromSnooze) {
            store.clearSnooze()
        } else {
            store.snoozeCount = 0
            // A one-shot alarm (no repeat days) switches itself off once it has rung.
            if (alarm != null && alarm.days.isEmpty()) store.disable(id)
        }
        // Queue the next alarm first, so a failure below never loses it.
        Scheduler.reschedule(context)
        val json = store.alarmJson(id) ?: return
        AlarmService.start(context, json, test = false)
    }
}

/** Reboot, app update, clock / time zone change or exact-alarm permission change: the system forgot our alarm. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Scheduler.reschedule(context)
    }
}
