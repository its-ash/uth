package com.itsash.uth

import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZonedDateTime
import org.junit.Assert.assertEquals
import org.junit.Test

class AlarmMathTest {

    private val utc = ZoneId.of("UTC")
    private val ny = ZoneId.of("America/New_York")

    private fun ms(zone: ZoneId, y: Int, mo: Int, d: Int, h: Int, mi: Int): Long =
        ZonedDateTime.of(LocalDateTime.of(y, mo, d, h, mi), zone).toInstant().toEpochMilli()

    @Test
    fun oneShotLaterTodayRingsToday() {
        // 2026-06-10 is a Wednesday.
        val now = ms(utc, 2026, 6, 10, 6, 0)
        assertEquals(ms(utc, 2026, 6, 10, 7, 30), AlarmMath.nextTrigger(7, 30, emptySet(), now, utc))
    }

    @Test
    fun oneShotAlreadyPassedRingsTomorrow() {
        val now = ms(utc, 2026, 6, 10, 8, 0)
        assertEquals(ms(utc, 2026, 6, 11, 7, 30), AlarmMath.nextTrigger(7, 30, emptySet(), now, utc))
    }

    @Test
    fun exactlyNowIsNotInTheFuture() {
        val now = ms(utc, 2026, 6, 10, 7, 30)
        assertEquals(ms(utc, 2026, 6, 11, 7, 30), AlarmMath.nextTrigger(7, 30, emptySet(), now, utc))
    }

    @Test
    fun repeatDaysPickNextMatchingWeekday() {
        val now = ms(utc, 2026, 6, 10, 8, 0) // Wednesday
        // Monday + Friday: next is Friday the 12th.
        assertEquals(ms(utc, 2026, 6, 12, 7, 0), AlarmMath.nextTrigger(7, 0, setOf(1, 5), now, utc))
        // Only Wednesday, already passed: next Wednesday.
        assertEquals(ms(utc, 2026, 6, 17, 7, 0), AlarmMath.nextTrigger(7, 0, setOf(3), now, utc))
        // Wednesday still ahead today.
        assertEquals(ms(utc, 2026, 6, 10, 9, 0), AlarmMath.nextTrigger(9, 0, setOf(3), now, utc))
    }

    @Test
    fun springForwardGapRingsOnTheSameDay() {
        // New York 2026-03-08: 02:00 -> 03:00. 02:30 does not exist and rings at 03:30 EDT.
        val now = ms(ny, 2026, 3, 8, 0, 10)
        val expected = ms(ny, 2026, 3, 8, 3, 30)
        assertEquals(expected, AlarmMath.nextTrigger(2, 30, emptySet(), now, ny))
        assertEquals(expected, AlarmMath.nextTrigger(2, 30, setOf(7), now, ny)) // Sunday
    }

    @Test
    fun wallClockTimeSurvivesDaylightSaving() {
        // Saturday evening before the change: 07:00 on Sunday is 22 real hours away (23 on the wall clock).
        val now = ms(ny, 2026, 3, 7, 8, 0)
        val next = AlarmMath.nextTrigger(7, 0, setOf(7), now, ny)
        assertEquals(ms(ny, 2026, 3, 8, 7, 0), next)
        assertEquals(22L * 3600_000L, next - now)
    }

    @Test
    fun fallBackOverlapRingsOnce() {
        // New York 2026-11-01: 01:30 happens twice; the first one (EDT) wins, a later "now" gets the day after.
        val now = ms(ny, 2026, 11, 1, 0, 0)
        val first = AlarmMath.nextTrigger(1, 30, emptySet(), now, ny)
        assertEquals(ZonedDateTime.of(LocalDateTime.of(2026, 11, 1, 1, 30), ny).toInstant().toEpochMilli(), first)
        val after = AlarmMath.nextTrigger(1, 30, emptySet(), first + 1, ny)
        assertEquals(ms(ny, 2026, 11, 2, 1, 30), after)
    }
}
