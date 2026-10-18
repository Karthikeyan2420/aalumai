package com.aalumai.aalumai

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import org.json.JSONObject
import java.util.Calendar

private const val TAG = "AalumaiAlarm"

/** Intent actions and extras shared by the native alarm trigger pipeline. */
object AlarmIntent {
    const val ACTION_RING = "com.aalumai.aalumai.action.ALARM_RING"
    const val ACTION_STOP = "com.aalumai.aalumai.action.ALARM_STOP"

    /**
     * Tapping the active-alarm notification (or its full-screen intent) opens
     * the ringing screen. Routed natively to `MainActivity`, which hands the
     * alarm id to Dart, so the tap works whether the Flutter engine is alive or
     * the activity is being cold-started.
     */
    const val ACTION_OPEN_ALARM = "com.aalumai.aalumai.action.ALARM_OPEN"

    /**
     * Fired when the user dismisses the active-alarm notification. Android 14+
     * makes `FLAG_ONGOING_EVENT` notifications dismissable while the device is
     * unlocked, so the ring service re-posts it from here to keep it visible
     * for as long as the alarm is actually ringing.
     */
    const val ACTION_NOTIFICATION_DISMISSED =
        "com.aalumai.aalumai.action.ALARM_NOTIFICATION_DISMISSED"

    const val EXTRA_SLOT_ID = "slotId"
    const val EXTRA_ALARM_ID = "alarmId"
    const val EXTRA_PAYLOAD = "payload"

    /** The alarm id an [ACTION_OPEN_ALARM] intent refers to, or `null`. */
    fun openAlarmId(intent: Intent?): Int? {
        if (intent == null || intent.action != ACTION_OPEN_ALARM) return null
        return intent.getIntExtra(EXTRA_ALARM_ID, -1).takeIf { it >= 0 }
    }
}

/**
 * Everything the native side needs to ring one schedule slot.
 *
 * The payload is produced by Dart when an alarm is scheduled and mirrors
 * `AlarmPlaybackConfig` after its effective-mode fallbacks, so the ring heard
 * by the user is identical whether the Flutter engine is alive or not.
 *
 * [repeat] is `once`, `daily` or `weekly` and is only used to re-arm the slot
 * after it fires; audio itself never depends on it.
 */
data class AlarmTriggerPayload(
    val slotId: Int,
    val alarmId: Int,
    val soundUri: String,
    val volume: Int,
    val vibrate: Boolean,
    val mode: String,
    val message: String,
    val musicIntervalSec: Int,
    val voicePauseSec: Int,
    val voiceTiming: String,
    val languageCode: String,
    val voiceName: String,
    val speechRate: Float,
    val speechPitch: Float,
    val speechVolume: Float,
    val label: String,
    val hour: Int,
    val minute: Int,
    val repeat: String,
    val weekday: Int,
    val triggerAtMs: Long,
) {
    val playsMusic: Boolean
        get() = !(mode == "voiceOnly" && message.trim().isEmpty())

    val speaks: Boolean
        get() = mode != "musicOnly" && message.trim().isNotEmpty()

    val safeMusicIntervalSec: Int
        get() = musicIntervalSec.coerceIn(1, 3600)

    val safeVoicePauseSec: Int
        get() = voicePauseSec.coerceIn(1, 3600)

    fun toJson(): JSONObject = JSONObject().apply {
        put("slotId", slotId)
        put("alarmId", alarmId)
        put("soundUri", soundUri)
        put("volume", volume)
        put("vibrate", vibrate)
        put("mode", mode)
        put("message", message)
        put("musicIntervalSec", musicIntervalSec)
        put("voicePauseSec", voicePauseSec)
        put("voiceTiming", voiceTiming)
        put("languageCode", languageCode)
        put("voiceName", voiceName)
        put("speechRate", speechRate.toDouble())
        put("speechPitch", speechPitch.toDouble())
        put("speechVolume", speechVolume.toDouble())
        put("label", label)
        put("hour", hour)
        put("minute", minute)
        put("repeat", repeat)
        put("weekday", weekday)
        put("triggerAtMs", triggerAtMs)
    }

    companion object {
        fun fromJson(raw: String?): AlarmTriggerPayload? {
            if (raw.isNullOrEmpty()) return null
            return try {
                val o = JSONObject(raw)
                AlarmTriggerPayload(
                    slotId = o.optInt("slotId", -1),
                    alarmId = o.optInt("alarmId", -1),
                    soundUri = o.optString("soundUri", "classic"),
                    volume = o.optInt("volume", 100),
                    vibrate = o.optBoolean("vibrate", true),
                    mode = o.optString("mode", "musicAndVoice"),
                    message = o.optString("message", ""),
                    musicIntervalSec = o.optInt("musicIntervalSec", 10),
                    voicePauseSec = o.optInt("voicePauseSec", 5),
                    voiceTiming = o.optString("voiceTiming", "betweenSegments"),
                    languageCode = o.optString("languageCode", "en"),
                    voiceName = o.optString("voiceName", ""),
                    speechRate = o.optDouble("speechRate", 1.0).toFloat(),
                    speechPitch = o.optDouble("speechPitch", 1.0).toFloat(),
                    speechVolume = o.optDouble("speechVolume", 1.0).toFloat(),
                    label = o.optString("label", ""),
                    hour = o.optInt("hour", 7),
                    minute = o.optInt("minute", 0),
                    repeat = o.optString("repeat", "once"),
                    weekday = o.optInt("weekday", 0),
                    triggerAtMs = o.optLong("triggerAtMs", 0L),
                ).takeIf { it.slotId >= 0 }
            } catch (e: Exception) {
                Log.w(TAG, "Ignoring malformed alarm payload: $e")
                null
            }
        }
    }
}

/**
 * Persists every armed slot in `SharedPreferences` so the exact alarms can be
 * re-created after a reboot or a package update, without needing the Flutter
 * database (which is unreadable until the app process runs).
 */
object AlarmTriggerStore {
    private const val PREFS = "aalumai_alarm_triggers"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun put(context: Context, payload: AlarmTriggerPayload) {
        prefs(context)
            .edit()
            .putString(payload.slotId.toString(), payload.toJson().toString())
            .apply()
    }

    fun get(context: Context, slotId: Int): AlarmTriggerPayload? =
        AlarmTriggerPayload.fromJson(prefs(context).getString(slotId.toString(), null))

    fun remove(context: Context, slotId: Int) {
        prefs(context).edit().remove(slotId.toString()).apply()
    }

    fun all(context: Context): List<AlarmTriggerPayload> {
        val out = ArrayList<AlarmTriggerPayload>()
        for ((_, value) in prefs(context).all) {
            val payload = AlarmTriggerPayload.fromJson(value as? String) ?: continue
            out.add(payload)
        }
        return out
    }

    /** Drops every armed slot belonging to [alarmId]. */
    fun removeAllForAlarm(context: Context, alarmId: Int) {
        val editor = prefs(context).edit()
        for (payload in all(context)) {
            if (payload.alarmId == alarmId) editor.remove(payload.slotId.toString())
        }
        editor.apply()
    }

    fun clearAll(context: Context) {
        prefs(context).edit().clear().apply()
    }
}

/** Thin wrapper over `AlarmManager` for the per-slot exact triggers. */
object AlarmTriggerScheduler {
    fun pendingIntent(context: Context, slotId: Int): PendingIntent {
        val intent = Intent(context, AlarmTriggerReceiver::class.java)
            .setAction(AlarmIntent.ACTION_RING)
            .putExtra(AlarmIntent.EXTRA_SLOT_ID, slotId)
        return PendingIntent.getBroadcast(
            context,
            slotId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /**
     * Arms [payload] for its absolute trigger time, falling back to an inexact
     * alarm when the OS withholds exact-alarm access so the ring is never lost.
     */
    fun schedule(context: Context, payload: AlarmTriggerPayload) {
        if (payload.triggerAtMs <= 0L) return
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = pendingIntent(context, payload.slotId)
        val canExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || manager.canScheduleExactAlarms()
        try {
            if (canExact) {
                manager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    payload.triggerAtMs,
                    pending,
                )
            } else {
                manager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    payload.triggerAtMs,
                    pending,
                )
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "Exact alarm denied, falling back to inexact: $e")
            try {
                manager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    payload.triggerAtMs,
                    pending,
                )
            } catch (e2: Exception) {
                Log.e(TAG, "Unable to arm alarm slot ${payload.slotId}: $e2")
            }
        }
    }

    fun cancel(context: Context, slotId: Int) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        manager.cancel(pendingIntent(context, slotId))
        pendingIntent(context, slotId).cancel()
    }

    /**
     * Next absolute trigger for a repeating [payload], or `null` when the slot
     * is one-shot. Mirrors `AlarmTime.next` from the Dart planner.
     */
    fun nextTriggerAt(payload: AlarmTriggerPayload, now: Long): Long? {
        if (payload.repeat != "daily" && payload.repeat != "weekly") return null
        val calendar = Calendar.getInstance().apply {
            timeInMillis = now
            set(Calendar.HOUR_OF_DAY, payload.hour)
            set(Calendar.MINUTE, payload.minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (payload.repeat == "daily") {
            if (calendar.timeInMillis <= now) calendar.add(Calendar.DAY_OF_MONTH, 1)
            return calendar.timeInMillis
        }
        // ISO weekday is 1 = Monday … 7 = Sunday; Calendar is 1 = Sunday … 7 = Saturday.
        val target = if (payload.weekday == 7) Calendar.SUNDAY else payload.weekday + 1
        var guard = 0
        while ((calendar.get(Calendar.DAY_OF_WEEK) != target || calendar.timeInMillis <= now) && guard < 8) {
            calendar.add(Calendar.DAY_OF_MONTH, 1)
            guard++
        }
        return calendar.timeInMillis
    }
}

/** Re-arms a repeating slot and starts the ring service. */
class AlarmTriggerReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val slotId = intent.getIntExtra(AlarmIntent.EXTRA_SLOT_ID, -1)
        if (slotId < 0) return
        val payload = AlarmTriggerStore.get(context, slotId) ?: run {
            Log.w(TAG, "Trigger for unknown slot $slotId")
            return
        }

        val nextAt = AlarmTriggerScheduler.nextTriggerAt(payload, System.currentTimeMillis())
        if (nextAt == null) {
            AlarmTriggerStore.remove(context, slotId)
        } else {
            val rearm = payload.copy(triggerAtMs = nextAt)
            AlarmTriggerStore.put(context, rearm)
            AlarmTriggerScheduler.schedule(context, rearm)
        }

        Log.i(TAG, "Alarm triggered for slot $slotId (alarm ${payload.alarmId})")
        AlarmAudioService.requestRing(context, payload)
    }
}

/**
 * Re-creates the exact triggers after a reboot, a package update or a wall
 * clock change. It only ever re-arms `AlarmManager`; ringing at boot is left to
 * the stored trigger time, which keeps this receiver clear of the Android 14
 * restrictions on launching foreground services from `BOOT_COMPLETED`.
 */
class AlarmBootReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        // Deliberately no ACTION_LOCKED_BOOT_COMPLETED: the trigger store lives
        // in credential-encrypted preferences, which are unreadable until the
        // user has unlocked the device for the first time after boot.
        val relevant = setOf(
            android.content.Intent.ACTION_BOOT_COMPLETED,
            android.content.Intent.ACTION_MY_PACKAGE_REPLACED,
            android.content.Intent.ACTION_TIME_CHANGED,
            android.content.Intent.ACTION_TIMEZONE_CHANGED,
        )
        if (action !in relevant) return

        val now = System.currentTimeMillis()
        for (payload in AlarmTriggerStore.all(context)) {
            if (payload.triggerAtMs > now) {
                AlarmTriggerScheduler.schedule(context, payload)
                continue
            }
            val nextAt = AlarmTriggerScheduler.nextTriggerAt(payload, now)
            if (nextAt == null) {
                AlarmTriggerStore.remove(context, payload.slotId)
            } else {
                val rearm = payload.copy(triggerAtMs = nextAt)
                AlarmTriggerStore.put(context, rearm)
                AlarmTriggerScheduler.schedule(context, rearm)
            }
        }
    }
}

/**
 * Restores the active-alarm notification after the user swipes it away.
 *
 * The ring service owns the notification and hands it a delete intent; on
 * Android 14+ an ongoing notification is dismissable while the device is
 * unlocked, so this re-posts it for as long as the alarm is genuinely ringing.
 * Dismissing the notification never stops the alarm: only passing every
 * challenge does.
 */
class AlarmNotificationDismissedReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != AlarmIntent.ACTION_NOTIFICATION_DISMISSED) return
        val slotId = intent.getIntExtra(AlarmIntent.EXTRA_SLOT_ID, -1)
        if (slotId < 0) return
        AlarmAudioService.onNotificationDismissed(slotId)
    }
}
