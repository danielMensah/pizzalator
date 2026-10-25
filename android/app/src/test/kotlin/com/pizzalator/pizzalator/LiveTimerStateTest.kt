package com.pizzalator.pizzalator

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

private const val MIN = 60_000L
private const val T0 = 1_000_000_000_000L
private fun at(minutes: Int) = T0 + minutes * MIN

// The legs liveLegs() lays out for Rest A (30) then Rest B (15), chained,
// then Fold, the last step: test/core/live_timer_test.dart drives the same
// machine in Dart against replayLive.
private val legs = listOf(
    listOf(
        Frame(0, 30 * MIN, "Rest A", "Next: Rest B", false, null),
        Frame(30 * MIN, 45 * MIN, "Rest B", "Rest over · Next: Fold", true, null),
        Frame(45 * MIN, null, "Rest over", "Next: Fold", true, "next"),
    ),
    listOf(Frame(0, null, "Fold", "Tap Finish when finished", false, "finish")),
)

class LiveTimerStateTest {
    private fun state(pausedAt: Long? = null) = LiveTimerState(legs, T0, pausedAt)

    @Test
    fun framesFollowTheClock() {
        val s = state()
        assertEquals("Rest A", s.current(at(0))!!.title)
        assertEquals(at(30), s.nextBoundary(at(0)))
        assertEquals("Rest B", s.current(at(30))!!.title) // the end begins the next
        assertEquals(at(45), s.nextBoundary(at(31)))
        assertEquals("next", s.current(at(50))!!.go)
        assertNull("waits for the tap", s.nextBoundary(at(50)))
    }

    @Test
    fun advanceReportsEachBoundaryOnce() {
        val s = state()
        assertFalse(s.advance(at(1)))
        assertTrue(s.advance(at(30)))
        assertFalse(s.advance(at(31)))
        assertTrue(s.advance(at(60)))
    }

    @Test
    fun extendJustAfterAChainedTimerBeginsKeepsIt() {
        val s = state()
        assertTrue(s.extend(at(32)))
        assertEquals("Rest B", s.current(at(33))!!.title)
        assertEquals(at(50), s.endAt(at(33)))
        assertEquals("Rest over", s.current(at(50))!!.title)
    }

    @Test
    fun pauseFreezesAndResumeShiftsTheRestOfTheLeg() {
        val s = state()
        assertTrue(s.pause(at(10)))
        assertEquals("Rest A", s.current(at(100))!!.title)
        assertNull(s.nextBoundary(at(100)))
        assertEquals(20 * MIN, s.endAt(at(100))!! - s.pausedAt!!)
        assertTrue(s.resume(at(60)))
        assertEquals(at(80), s.nextBoundary(at(60)))
        assertEquals(at(95), s.nextBoundary(at(81)))
    }

    @Test
    fun buttonsOnlyActOnTheirFrames() {
        val s = state()
        assertFalse(s.resume(at(1)))
        assertFalse("a timer is running", s.go(at(1)))
        assertTrue(s.pause(at(2)))
        assertFalse(s.pause(at(3)))
        assertFalse(s.extend(at(3)))
        assertTrue(s.resume(at(4)))
        assertFalse("waiting", s.pause(at(60)))
        assertFalse(s.extend(at(60)))
        assertEquals(listOf(Tap("pause", at(2)), Tap("resume", at(4))), s.log)
    }

    @Test
    fun goStartsTheNextLegFromTheTapAndFinishLogsNext() {
        val s = state()
        assertTrue(s.go(at(50)))
        assertEquals("Fold", s.current(at(50))!!.title)
        assertTrue(s.go(at(52)))
        assertTrue(s.done)
        assertNull(s.current(at(53)))
        assertNull(s.nextBoundary(at(53)))
        assertFalse(s.go(at(54)))
        assertEquals(listOf(Tap("next", at(50)), Tap("next", at(52))), s.log)
    }

    @Test
    fun startsPaused() {
        val s = state(pausedAt = T0)
        assertEquals("Rest A", s.current(at(10))!!.title)
        assertNull(s.nextBoundary(at(10)))
        assertTrue(s.resume(at(10)))
        assertEquals(at(40), s.nextBoundary(at(10)))
    }

    @Test
    fun clockReadsLikeTheTimersScreen() {
        assertEquals("20:00", LiveTimerState.clock(20 * MIN))
        assertEquals("01:02", LiveTimerState.clock(61_001)) // rounds up
        assertEquals("1:00:00", LiveTimerState.clock(59 * MIN + 59_500))
        assertEquals("25:04:01", LiveTimerState.clock(25 * 60 * MIN + 4 * MIN + 1))
    }
}
