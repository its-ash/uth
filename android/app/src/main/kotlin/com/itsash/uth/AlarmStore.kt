package com.itsash.uth

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** The part of an alarm that native code needs. Dart keeps the rest (challenge, QR value ...) in the same JSON. */
data class Alarm(
    val id: Long,
    val hour: Int,
    val minute: Int,
    val days: Set<Int>,
    val label: String,
    val sound: String?,
    val vibrate: Boolean,
    val gradual: Boolean,
    val enabled: Boolean,
    val maxSnoozes: Int,
) {
    companion object {
        fun fromJson(o: JSONObject): Alarm {
            val d = o.optJSONArray("days") ?: JSONArray()
            return Alarm(
                id = o.getLong("id"),
                hour = o.optInt("hour", 7),
                minute = o.optInt("minute", 0),
                days = (0 until d.length()).map { d.getInt(it) }.toSet(),
                label = o.optString("label", ""),
                sound = if (o.isNull("sound")) null else o.optString("sound").ifEmpty { null },
                vibrate = o.optBoolean("vibrate", true),
                gradual = o.optBoolean("gradual", true),
                enabled = o.optBoolean("enabled", true),
                maxSnoozes = o.optInt("maxSnoozes", 2),
            )
        }
    }
}

/**
 * Native owner of the alarm data (SharedPreferences "uth_prefs"), so alarms ring and reschedule with the app closed.
 * Dart writes the whole list with `saveAlarms`. Keys: `alarms` (JSON array), `snoozeId`, `snoozeAt`,
 * `snoozeCount` (snoozes used in the current ring), `askedNotifications`.
 */
class AlarmStore(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences("uth_prefs", Context.MODE_PRIVATE)

    var alarmsJson: String
        get() = prefs.getString("alarms", "[]") ?: "[]"
        set(value) = prefs.edit().putString("alarms", value).apply()

    fun alarms(): List<Alarm> = try {
        val a = JSONArray(alarmsJson)
        (0 until a.length()).map { Alarm.fromJson(a.getJSONObject(it)) }
    } catch (_: Exception) {
        emptyList()
    }

    fun alarm(id: Long): Alarm? = alarms().firstOrNull { it.id == id }

    /** Raw JSON of one alarm (Dart reads the challenge settings from it). */
    fun alarmJson(id: Long): String? = try {
        val a = JSONArray(alarmsJson)
        (0 until a.length()).map { a.getJSONObject(it) }.firstOrNull { it.getLong("id") == id }?.toString()
    } catch (_: Exception) {
        null
    }

    /** One-shot alarms switch themselves off after ringing. */
    fun disable(id: Long) {
        try {
            val a = JSONArray(alarmsJson)
            for (i in 0 until a.length()) {
                val o = a.getJSONObject(i)
                if (o.getLong("id") == id) o.put("enabled", false)
            }
            alarmsJson = a.toString()
        } catch (_: Exception) {
        }
    }

    var snoozeId: Long
        get() = prefs.getLong("snoozeId", 0)
        set(v) = prefs.edit().putLong("snoozeId", v).apply()

    var snoozeAt: Long
        get() = prefs.getLong("snoozeAt", 0)
        set(v) = prefs.edit().putLong("snoozeAt", v).apply()

    var snoozeCount: Int
        get() = prefs.getInt("snoozeCount", 0)
        set(v) = prefs.edit().putInt("snoozeCount", v).apply()

    var askedNotifications: Boolean
        get() = prefs.getBoolean("askedNotifications", false)
        set(v) = prefs.edit().putBoolean("askedNotifications", v).apply()

    fun clearSnooze() {
        prefs.edit().remove("snoozeId").remove("snoozeAt").apply()
    }
}
