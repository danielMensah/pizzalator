package com.pizzalator.pizzalator

// Pure Kotlin, no android.*: the live notification's state machine, unit
// tested on the JVM. It steps through the frames lib/core/live_timer.dart
// laid out and logs the taps for replayLive; test/core/live_timer_test.dart
// holds a line-for-line Dart copy that is checked against the replay.

/** One frame of liveLegs(); [at] and [end] in ms from its leg's start. */
data class Frame(
    val at: Long,
    val end: Long?,
    val title: String,
    val text: String,
    val chime: Boolean,
    val go: String?,
)

/** A button tap, as LiveAction.fromJson reads it. */
data class Tap(val type: String, val at: Long)

/**
 * Frame times are [legStart] + [shift] + offset. Pause and +5 move the
 * frames still ahead in the leg by [shift]; [frame] is the current frame as
 * of the last action, so a shift never brings back one already over.
 * While paused, time stands still at [pausedAt].
 */
class LiveTimerState(
    val legs: List<List<Frame>>,
    var legStart: Long,
    var pausedAt: Long? = null,
    var leg: Int = 0,
    var frame: Int = 0,
    var shift: Long = 0,
    val log: MutableList<Tap> = mutableListOf(),
) {
    /** Finish was tapped. */
    val done get() = leg >= legs.size

    fun current(now: Long): Frame? = if (done) null else legs[leg][index(now)]

    /** The current timer's end; null on a waiting frame. */
    fun endAt(now: Long): Long? = current(now)?.end?.let { legStart + shift + it }

    /** When the next frame begins: null while paused or waiting for a tap. */
    fun nextBoundary(now: Long): Long? = if (pausedAt != null) null else endAt(now)

    /** Catches [frame] up with the clock; true when a boundary passed since. */
    fun advance(now: Long): Boolean {
        if (done) return false
        val i = index(now)
        return (i != frame).also { frame = i }
    }

    fun pause(now: Long) = onTimer(now) {
        pausedAt = now
        log += Tap("pause", now)
    }

    fun extend(now: Long) = onTimer(now) {
        shift += EXTEND_MS
        log += Tap("extend", now)
    }

    fun resume(now: Long): Boolean {
        val p = pausedAt ?: return false
        shift += now - p
        pausedAt = null
        log += Tap("resume", now)
        return true
    }

    /** Start, Done, next or Finish: the next leg starts now. */
    fun go(now: Long): Boolean {
        if (done || pausedAt != null) return false
        val go = legs[leg][index(now)].go ?: return false
        log += Tap(if (go == "finish") "next" else go, now)
        leg++
        frame = 0
        legStart = now
        shift = 0
        return true
    }

    /** Pause and +5 act on a running timer only. */
    private inline fun onTimer(now: Long, change: () -> Unit): Boolean {
        if (done || pausedAt != null) return false
        val i = index(now)
        if (legs[leg][i].end == null) return false
        frame = i
        change()
        return true
    }

    private fun index(now: Long): Int {
        val t = (pausedAt ?: now) - legStart - shift
        val frames = legs[leg]
        var i = frame
        while (i + 1 < frames.size && frames[i + 1].at <= t) i++
        return i
    }

    companion object {
        /** kExtendBy in lib/core/timer_run.dart. */
        const val EXTEND_MS = 5 * 60_000L

        /** mm:ss, or h:mm:ss from an hour, rounded up: the Timers screen's clock. */
        fun clock(ms: Long): String {
            val s = (ms + 999) / 1000
            fun two(n: Long) = n.toString().padStart(2, '0')
            val mmss = "${two(s / 60 % 60)}:${two(s % 60)}"
            return if (s >= 3600) "${s / 3600}:$mmss" else mmss
        }
    }
}
