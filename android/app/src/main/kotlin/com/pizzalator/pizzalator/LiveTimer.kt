package com.pizzalator.pizzalator

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import org.json.JSONArray
import org.json.JSONObject

/**
 * The live notification while the app is hidden (lib/services/live_timer.dart):
 * posts the current frame of [LiveTimerState], keeps one exact alarm on its
 * next boundary and records the button taps for Dart to replay. State lives
 * in SharedPreferences, so taps, alarms and reboots work with the app's
 * process gone.
 */
object LiveTimer {
    private const val ID = 1
    private const val LIVE = "timer_live"
    private const val END = "timer_end"

    // Broadcast actions; the index is each PendingIntent's request code.
    private const val TICK = "com.pizzalator.timer.TICK"
    private const val PAUSE = "com.pizzalator.timer.PAUSE"
    private const val RESUME = "com.pizzalator.timer.RESUME"
    private const val EXTEND = "com.pizzalator.timer.EXTEND"
    private const val GO = "com.pizzalator.timer.GO"
    private val actions = listOf(TICK, PAUSE, RESUME, EXTEND, GO)

    private val alarm = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ALARM)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    /** Held until it finishes: a collected MediaPlayer stops mid-ding. */
    private var player: MediaPlayer? = null

    /** A fresh run from Dart: forgets the last one, taps included. */
    fun show(ctx: Context, legs: String, startedAt: Long, pausedAt: Long?) {
        channels(ctx)
        prefs(ctx).edit().clear().putString("legs", legs).apply()
        update(ctx, LiveTimerState(parseLegs(legs), startedAt, pausedAt))
    }

    /** Cancels the notification and alarm; hands back the taps as JSON. */
    fun stop(ctx: Context): String {
        val log = prefs(ctx).getString("log", null) ?: "[]"
        prefs(ctx).edit().clear().apply()
        ctx.getSystemService(NotificationManager::class.java).cancel(ID)
        ctx.getSystemService(AlarmManager::class.java).cancel(broadcast(ctx, TICK))
        return log
    }

    /** A button, the boundary alarm, a reboot or an app update. */
    fun handle(ctx: Context, action: String?) {
        val s = load(ctx) ?: return
        val now = System.currentTimeMillis()
        when (action) {
            PAUSE -> s.pause(now)
            RESUME -> s.resume(now)
            EXTEND -> s.extend(now)
            GO -> s.go(now)
        }
        update(ctx, s, now)
    }

    /** The ding, now, on the alarm stream: it sounds on silent too. */
    fun chime(ctx: Context) {
        player?.release()
        val session = ctx.getSystemService(AudioManager::class.java).generateAudioSessionId()
        player = MediaPlayer.create(ctx, R.raw.timer_ding, alarm, session)?.apply {
            // Errors end in onCompletion too.
            setOnCompletionListener {
                it.release()
                if (player === it) player = null
            }
            start()
        }
    }

    private fun update(ctx: Context, s: LiveTimerState, now: Long = System.currentTimeMillis()) {
        // Rings once per boundary passed, also one passed while off or late.
        val ring = s.advance(now) && s.current(now)?.chime == true
        save(ctx, s)
        post(ctx, s, now, ring)
        val am = ctx.getSystemService(AlarmManager::class.java)
        val tick = broadcast(ctx, TICK)
        val at = s.nextBoundary(now) ?: return am.cancel(tick)
        // USE_EXACT_ALARM (33+) is granted at install; on 31-32 the user can
        // revoke SCHEDULE_EXACT_ALARM, and then late beats never.
        if (Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, tick)
        } else {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, tick)
        }
    }

    private fun post(ctx: Context, s: LiveTimerState, now: Long, ring: Boolean) {
        val nm = ctx.getSystemService(NotificationManager::class.java)
        // Finished: nothing to show; the log waits for Dart.
        val f = s.current(now) ?: return nm.cancel(ID)
        val end = s.endAt(now)
        val paused = s.pausedAt
        val text = if (paused != null && end != null) "${LiveTimerState.clock(end - paused)} left" else f.text
        val b = builder(ctx, ring)
            .setSmallIcon(R.drawable.ic_stat_timer)
            .setContentTitle(f.title)
            .setContentText(text)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(
                // Brings back the running app (singleTop), coming back on screen.
                PendingIntent.getActivity(
                    ctx, 0, Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                ),
            )
        val counting = end != null && paused == null
        if (counting) {
            b.setWhen(end!!).setShowWhen(true).setUsesChronometer(true).setChronometerCountDown(true)
        } else {
            b.setShowWhen(false)
        }
        when {
            paused != null -> b.addAction(button(ctx, "Resume", RESUME))
            end != null -> b.addAction(button(ctx, "Pause", PAUSE)).addAction(button(ctx, "+5 min", EXTEND))
            else -> {
                val label = when (f.go) {
                    "start" -> "Start"
                    "finish" -> "Finish"
                    else -> "Done, next"
                }
                b.addAction(button(ctx, label, GO))
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.BAKLAVA) {
            // Live Update: the status bar chip and the top of the shade. Its
            // setter is API 36.1; the extra it sets works from 36, as
            // NotificationCompat does it.
            b.addExtras(Bundle().apply { putBoolean("android.requestPromotedOngoing", true) })
            if (!counting) b.setShortCriticalText(if (paused != null) "Paused" else "Ready")
        }
        // A repost of the same id would update silently: cancel first.
        if (ring) nm.cancel(ID)
        nm.notify(ID, b.build())
    }

    @Suppress("DEPRECATION")
    private fun builder(ctx: Context, ring: Boolean): Notification.Builder =
        if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(ctx, if (ring) END else LIVE)
        } else {
            Notification.Builder(ctx).apply {
                if (ring) setSound(ding(ctx), alarm).setPriority(Notification.PRIORITY_HIGH)
            }
        }

    /**
     * Channels are immutable once made: a new sound or importance needs a
     * new channel id. The ding is named, not by its resource id, which can
     * change between builds.
     */
    private fun channels(ctx: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = ctx.getSystemService(NotificationManager::class.java)
        nm.deleteNotificationChannel("timers") // flutter_local_notifications'
        // Not IMPORTANCE_MIN: a Live Update needs the status bar.
        nm.createNotificationChannel(
            NotificationChannel(LIVE, "Running timer", NotificationManager.IMPORTANCE_LOW).apply {
                setShowBadge(false)
            },
        )
        nm.createNotificationChannel(
            NotificationChannel(END, "Timer ends", NotificationManager.IMPORTANCE_HIGH).apply {
                setSound(ding(ctx), alarm)
                enableVibration(true)
            },
        )
    }

    private fun ding(ctx: Context) = Uri.parse("android.resource://${ctx.packageName}/raw/timer_ding")

    private fun broadcast(ctx: Context, action: String) = PendingIntent.getBroadcast(
        ctx, actions.indexOf(action), Intent(ctx, LiveTimerReceiver::class.java).setAction(action),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    private fun button(ctx: Context, label: String, action: String) = Notification.Action.Builder(
        Icon.createWithResource(ctx, R.drawable.ic_stat_timer), label, broadcast(ctx, action),
    ).build()

    private fun prefs(ctx: Context) = ctx.getSharedPreferences("live_timer", Context.MODE_PRIVATE)

    private fun save(ctx: Context, s: LiveTimerState) {
        val log = JSONArray()
        for (t in s.log) log.put(JSONObject().put("type", t.type).put("at", t.at))
        val e = prefs(ctx).edit()
            .putInt("leg", s.leg)
            .putInt("frame", s.frame)
            .putLong("legStart", s.legStart)
            .putLong("shift", s.shift)
            .putString("log", log.toString())
        s.pausedAt?.let { e.putLong("pausedAt", it) } ?: e.remove("pausedAt")
        e.apply()
    }

    private fun load(ctx: Context): LiveTimerState? {
        val p = prefs(ctx)
        val legs = p.getString("legs", null) ?: return null
        val log = JSONArray(p.getString("log", "[]"))
        return LiveTimerState(
            parseLegs(legs),
            legStart = p.getLong("legStart", 0),
            pausedAt = if (p.contains("pausedAt")) p.getLong("pausedAt", 0) else null,
            leg = p.getInt("leg", 0),
            frame = p.getInt("frame", 0),
            shift = p.getLong("shift", 0),
            log = MutableList(log.length()) {
                log.getJSONObject(it).run { Tap(getString("type"), getLong("at")) }
            },
        )
    }

    /** LiveFrame.toJson's fields. */
    private fun parseLegs(json: String): List<List<Frame>> {
        val legs = JSONArray(json)
        return List(legs.length()) { i ->
            val leg = legs.getJSONArray(i)
            List(leg.length()) { j ->
                leg.getJSONObject(j).run {
                    Frame(
                        at = getLong("at"),
                        end = if (isNull("end")) null else getLong("end"),
                        title = getString("title"),
                        text = getString("text"),
                        chime = getBoolean("chime"),
                        go = if (isNull("go")) null else getString("go"),
                    )
                }
            }
        }
    }
}

/** Notification buttons, the boundary alarm, boot and app updates. */
class LiveTimerReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) = LiveTimer.handle(ctx, intent.action)
}
