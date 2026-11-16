package com.itsash.uth

import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime

/** Pure alarm time rules, unit tested (AlarmMathTest.kt). The Dart twin is lib/alarm/next_trigger.dart. */
object AlarmMath {

    const val SNOOZE_MS = 5 * 60 * 1000L

    /**
     * Epoch ms of the first moment strictly after [nowMs] at which an alarm at [hour]:[minute] rings,
     * or -1 if none. [days] are ISO weekdays (Monday = 1 ... Sunday = 7); empty means one-shot:
     * the next time the clock shows [hour]:[minute]. A time skipped by daylight saving (spring forward)
     * rings at the shifted time of that same day.
     */
    fun nextTrigger(hour: Int, minute: Int, days: Set<Int>, nowMs: Long, zone: ZoneId): Long {
        val today: LocalDate = Instant.ofEpochMilli(nowMs).atZone(zone).toLocalDate()
        for (offset in 0L..8L) {
            val date = today.plusDays(offset)
            if (days.isNotEmpty() && date.dayOfWeek.value !in days) continue
            val at = ZonedDateTime.of(date, LocalTime.of(hour, minute), zone).toInstant().toEpochMilli()
            if (at > nowMs) return at
        }
        return -1L
    }
}
