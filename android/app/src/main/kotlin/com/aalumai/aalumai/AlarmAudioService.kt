package com.aalumai.aalumai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.content.res.AssetFileDescriptor
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import java.io.File
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

private const val TAG = "AalumaiAlarm"

/**
 * Foreground service that rings an alarm.
 *
 * This is the single owner of ring audio while it runs. It exists because a
 * scheduled alarm must produce sound even when the Flutter engine is not
 * running — the app has been swiped away or killed by the system. Starting a
 * foreground service from an exact-alarm broadcast is one of the platform's
 * documented exemptions to background-service start restrictions, and a
 * foreground service is what keeps playback alive for as long as the alarm
 * should ring.
 *
 * `AlarmRingingScreen` queries `isRinging` before it starts its own in-process
 * `AlarmAudio` player: when this service is already ringing it stays silent and
 * only asks us to stop once every challenge has been passed, so the tone can
 * never play twice. When no native trigger fired (for example the exact-alarm
 * permission was denied) the screen falls back to the Dart player unchanged.
 */
class AlarmAudioService : Service() {

    companion object {
        private const val UTTERANCE_ID = "aalumai_alarm_message"

        // Mirror `NotificationService._alarmChannel*` in Dart so the native
        // alarm notification lands on the same "Alarm" channel the Flutter side
        // already creates, and existing user customisations are preserved.
        private const val ALARM_CHANNEL_VIBRATE = "aalumai_alarm_ring_v2_vibrate"
        private const val ALARM_CHANNEL_SILENT = "aalumai_alarm_ring_v2_silent"

        @Volatile
        var isRinging = false
            private set

        @Volatile
        var ringingAlarmId = -1
            private set

        /** The live service instance, so a dismissal receiver can reach it. */
        @Volatile
        private var instance: AlarmAudioService? = null

        fun requestRing(context: Context, payload: AlarmTriggerPayload) {
            val intent = Intent(context, AlarmAudioService::class.java)
                .setAction(AlarmIntent.ACTION_RING)
                .putExtra(AlarmIntent.EXTRA_PAYLOAD, payload.toJson().toString())
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Unable to start the alarm ring service: $e")
            }
        }

        fun requestStop(context: Context) {
            val intent = Intent(context, AlarmAudioService::class.java)
                .setAction(AlarmIntent.ACTION_STOP)
            try {
                // Safe while the service is running: commands addressed to an
                // already-started foreground service are not background starts.
                context.startService(intent)
            } catch (e: Exception) {
                Log.d(TAG, "Ring service not running, nothing to stop: $e")
            }
        }

        /**
         * Re-posts the active-alarm notification after the user swiped it away,
         * for as long as the alarm is genuinely ringing. Dismissing the
         * notification never stops the alarm; only passing every challenge does.
         */
        fun onNotificationDismissed(slotId: Int) {
            val service = instance ?: return
            service.mainHandler.post {
                val current = service.payload
                if (service.ringActive && current != null && current.slotId == slotId) {
                    service.ensureAlarmNotification(current)
                }
            }
        }
    }

    private var payload: AlarmTriggerPayload? = null
    private var player: MediaPlayer? = null
    private var tts: TextToSpeech? = null
    private var focusRequest: AudioFocusRequest? = null

    private val mainHandler = Handler(Looper.getMainLooper())

    // Kotlin's `Any` does not expose wait/notify, so the sleep and utterance
    // handoffs use explicit locks with conditions instead of monitors.
    private val sleepLock = ReentrantLock()
    private val sleepSignal = sleepLock.newCondition()
    private val utteranceLock = ReentrantLock()
    private val utteranceSignal = utteranceLock.newCondition()

    @Volatile
    private var ringActive = false

    @Volatile
    private var utteranceDone = true

    private var ttsReady: CountDownLatch? = null
    private var voiceThread: Thread? = null
    private var baseVolume = 1f

    private val watchdog = object : Runnable {
        override fun run() {
            if (!ringActive) return
            val current = payload ?: return
            // Both this app and flutter_local_notifications post a notification
            // under the same slot id when an alarm fires. Whichever lands last
            // wins, so make sure the surviving one is the native notification
            // that carries the delete intent and full-screen intent.
            ensureAlarmNotification(current)
            if (current.playsMusic) reassertMusic()
            if (current.speaks && voiceThread?.isAlive != true) startVoiceLoop(current)
            mainHandler.postDelayed(this, 1000)
        }
    }

    private val vibratorTick = object : Runnable {
        override fun run() {
            if (!ringActive) return
            vibrateOnce()
            mainHandler.postDelayed(this, 1200)
        }
    }

    override fun onBind(intent: Intent?): android.os.IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        instance = this
        when (intent?.action) {
            AlarmIntent.ACTION_RING -> {
                val next = AlarmTriggerPayload.fromJson(intent.getStringExtra(AlarmIntent.EXTRA_PAYLOAD))
                if (next == null) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                startAsForeground(next)
                startRing(next)
            }
            AlarmIntent.ACTION_STOP -> {
                stopRing()
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                // Restarted by the system without a payload: there is nothing
                // meaningful to play, so do not linger as an empty service.
                stopSelf()
                return START_NOT_STICKY
            }
        }
        return START_NOT_STICKY
    }

    // ---------------------------------------------------------------- ring

    private fun startRing(next: AlarmTriggerPayload) {
        if (ringActive) stopRing()
        payload = next
        ringActive = true
        isRinging = true
        ringingAlarmId = next.alarmId
        baseVolume = next.volume.coerceIn(0, 100) / 100f

        if (next.playsMusic) startMusic(next)
        if (next.vibrate) mainHandler.post(vibratorTick)
        if (next.speaks) startVoiceLoop(next)
        mainHandler.postDelayed(watchdog, 1000)
        // If the Flutter engine is alive, let it surface the ringing screen
        // immediately. Android suppresses a full-screen intent while the device
        // is unlocked, so this is the in-app path for that case.
        AlarmTriggerPlugin.notifyRingStarted(next.alarmId)
        Log.i(TAG, "Ringing alarm ${next.alarmId} (mode ${next.mode})")
    }

    private fun stopRing() {
        ringActive = false
        isRinging = false
        ringingAlarmId = -1
        mainHandler.removeCallbacks(watchdog)
        mainHandler.removeCallbacks(vibratorTick)
        sleepLock.withLock { sleepSignal.signalAll() }
        utteranceLock.withLock {
            utteranceDone = true
            utteranceSignal.signalAll()
        }
        voiceThread?.interrupt()
        voiceThread = null
        try {
            tts?.stop()
        } catch (_: Exception) {
        }
        try {
            tts?.shutdown()
        } catch (_: Exception) {
        }
        tts = null
        releasePlayer()
        abandonFocus()
        try {
            vibrator().cancel()
        } catch (_: Exception) {
        }
        payload = null
    }

    override fun onDestroy() {
        stopRing()
        instance = null
        super.onDestroy()
    }

    // -------------------------------------------------------------- music

    private fun startMusic(current: AlarmTriggerPayload) {
        try {
            val source = resolveSource(current.soundUri)
            val mediaPlayer = MediaPlayer()
            mediaPlayer.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            mediaPlayer.setDataSource(source.absolutePath)
            mediaPlayer.isLooping = true
            mediaPlayer.setVolume(baseVolume, baseVolume)
            mediaPlayer.prepare()
            mediaPlayer.start()
            player = mediaPlayer
            requestFocus()
        } catch (e: Exception) {
            Log.e(TAG, "Alarm tone failed to start for ${current.soundUri}: $e")
            player = null
        }
    }

    private fun reassertMusic() {
        val mediaPlayer = player ?: return
        try {
            if (!mediaPlayer.isPlaying) mediaPlayer.start()
            mediaPlayer.setVolume(baseVolume, baseVolume)
        } catch (e: Exception) {
            Log.w(TAG, "Alarm tone was stopped by the platform, restarting: $e")
            val current = payload ?: return
            releasePlayer()
            startMusic(current)
        }
    }

    private fun releasePlayer() {
        try {
            player?.stop()
        } catch (_: Exception) {
        }
        try {
            player?.release()
        } catch (_: Exception) {
        }
        player = null
    }

    /**
     * Mirrors `AlarmSounds.resolveTone`: bundled tones are read straight out of
     * the Flutter asset bundle, a missing or deleted custom file falls back to
     * the default tone so an alarm can never ring into silence.
     */
    private fun resolveSource(soundUri: String): File {
        if (soundUri.startsWith(AlarmSounds.FILE_PREFIX)) {
            val path = soundUri.substring(AlarmSounds.FILE_PREFIX.length)
            if (path.isNotEmpty() && File(path).exists()) return File(path)
            return assetFile(AlarmSounds.DEFAULT_ASSET)
        }
        val preset = AlarmSounds.ASSETS[soundUri] ?: AlarmSounds.ASSETS[AlarmSounds.DEFAULT_ID]!!
        return assetFile(preset)
    }

    private fun assetFile(relativePath: String): File {
        val target = File(cacheDir, relativePath.replace('/', '_'))
        if (!target.exists() || target.length() == 0L) {
            val descriptor: AssetFileDescriptor? = try {
                assets.openFd("flutter_assets/$relativePath")
            } catch (_: Exception) {
                null
            }
            try {
                if (descriptor != null) {
                    target.outputStream().use { out ->
                        descriptor.createInputStream().use { it.copyTo(out) }
                    }
                } else {
                    assets.open("flutter_assets/$relativePath").use { input ->
                        target.outputStream().use { input.copyTo(it) }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Unable to read alarm asset $relativePath: $e")
            } finally {
                try {
                    descriptor?.close()
                } catch (_: Exception) {
                }
            }
        }
        return target
    }

    // -------------------------------------------------------- vibration

    private fun vibrator(): Vibrator =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

    private fun vibrateOnce() {
        try {
            vibrator().vibrate(VibrationEffect.createOneShot(400, VibrationEffect.DEFAULT_AMPLITUDE))
        } catch (e: Exception) {
            Log.w(TAG, "Vibration unavailable: $e")
        }
    }

    // ---------------------------------------------------------- speaking

    private fun startVoiceLoop(current: AlarmTriggerPayload) {
        if (!current.speaks) return
        val latch = CountDownLatch(1)
        ttsReady = latch
        try {
            tts = TextToSpeech(this) { status ->
                if (status == TextToSpeech.SUCCESS) configureTts(current)
                latch.countDown()
            }
        } catch (e: Exception) {
            Log.e(TAG, "TTS unavailable: $e")
            latch.countDown()
            return
        }
        voiceThread = Thread {
            try {
                latch.await()
                runVoiceLoop(current)
            } catch (_: InterruptedException) {
                // Ringing stopped while waiting.
            }
        }.also {
            it.isDaemon = true
            it.start()
        }
    }

    private fun configureTts(current: AlarmTriggerPayload) {
        val engine = tts ?: return
        try {
            engine.language = Locale(current.languageCode.ifEmpty { "en" })
            engine.setSpeechRate(current.speechRate)
            engine.setPitch(current.speechPitch)
            if (current.voiceName.isNotEmpty()) {
                val match = engine.voices?.firstOrNull { it.name == current.voiceName }
                if (match != null) engine.voice = match
            }
            engine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(id: String?) {}

                override fun onDone(id: String?) = signalUtteranceDone()

                override fun onError(id: String?) = signalUtteranceDone()

                override fun onError(id: String?, errorCode: Int) = signalUtteranceDone()
            })
        } catch (e: Exception) {
            Log.w(TAG, "Voice configuration failed, using engine defaults: $e")
        }
    }

    private fun signalUtteranceDone() {
        utteranceLock.withLock {
            utteranceDone = true
            utteranceSignal.signalAll()
        }
    }

    /**
     * Re-implements `AlarmAudio._runVoiceLoop` so the ring keeps speaking when
     * the Flutter isolate is not alive: the message repeats alone in
     * voice-only mode, and follows the configured timing relative to the music
     * otherwise, ducking the tone while it speaks.
     */
    private fun runVoiceLoop(current: AlarmTriggerPayload) {
        val text = current.message.trim()
        if (text.isEmpty()) return
        val voiceOnly = current.mode == "voiceOnly"
        val intervalMs = current.safeMusicIntervalSec * 1000L
        val pauseMs = current.safeVoicePauseSec * 1000L

        while (ringActive) {
            if (voiceOnly) {
                speak(text, muteMusic = true)
                if (!ringActive || !cancellableSleep(pauseMs)) break
                continue
            }
            when (current.voiceTiming) {
                "beforeMusic" -> {
                    speak(text, muteMusic = true)
                    if (!ringActive || !cancellableSleep(intervalMs)) break
                }
                "overMusic" -> {
                    if (!cancellableSleep(intervalMs)) break
                    speak(text, muteMusic = false)
                }
                else -> {
                    if (!cancellableSleep(intervalMs)) break
                    speak(text, muteMusic = true)
                }
            }
        }
    }

    private fun speak(text: String, muteMusic: Boolean) {
        val engine = tts
        if (!ringActive || engine == null) return
        if (payload?.playsMusic == true && player != null) {
            val ducked =
                if (muteMusic) 0f
                else (baseVolume * 0.35 * (payload?.speechVolume ?: 1f)).coerceIn(0.0, 1.0).toFloat()
            try {
                player?.setVolume(ducked, ducked)
            } catch (_: Exception) {
            }
        }
        try {
            utteranceLock.withLock { utteranceDone = false }
            engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, UTTERANCE_ID)
            val deadline = System.currentTimeMillis() + 30_000
            utteranceLock.withLock {
                var remaining = deadline - System.currentTimeMillis()
                while (!utteranceDone && remaining > 0 && ringActive) {
                    try {
                        utteranceSignal.await(remaining, TimeUnit.MILLISECONDS)
                    } catch (_: InterruptedException) {
                        break
                    }
                    remaining = deadline - System.currentTimeMillis()
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Speech failed: $e")
        } finally {
            if (ringActive && payload?.playsMusic == true) {
                try {
                    player?.setVolume(baseVolume, baseVolume)
                } catch (_: Exception) {
                }
            }
        }
    }

    /** Returns `false` when the ring stopped mid-sleep, ending the loop. */
    private fun cancellableSleep(millis: Long): Boolean {
        val deadline = System.currentTimeMillis() + millis
        sleepLock.withLock {
            var remaining = deadline - System.currentTimeMillis()
            while (remaining > 0 && ringActive) {
                try {
                    sleepSignal.await(remaining, TimeUnit.MILLISECONDS)
                } catch (_: InterruptedException) {
                    return false
                }
                remaining = deadline - System.currentTimeMillis()
            }
        }
        return ringActive
    }

    // ------------------------------------------------------------- audio

    private fun requestFocus() {
        val manager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                .setWillPauseWhenDucked(false)
                .build()
            focusRequest = request
            try {
                manager.requestAudioFocus(request)
            } catch (e: Exception) {
                Log.w(TAG, "Audio focus request failed: $e")
            }
        } else {
            @Suppress("DEPRECATION")
            manager.requestAudioFocus(
                null,
                AudioManager.STREAM_ALARM,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT,
            )
        }
    }

    private fun abandonFocus() {
        val request = focusRequest ?: return
        focusRequest = null
        try {
            val manager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            manager.abandonAudioFocusRequest(request)
        } catch (_: Exception) {
        }
    }

    // ------------------------------------------------------ notification

    private fun startAsForeground(current: AlarmTriggerPayload) {
        try {
            ensureAlarmChannel(current.vibrate)
            val notification = buildNotification(current)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    current.slotId,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
                )
            } else {
                startForeground(current.slotId, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Unable to enter the foreground for the alarm: $e")
        }
    }

    /** Android 8+ only honours a channel's sound/vibration at creation time. */
    private fun ensureAlarmChannel(vibrate: Boolean) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        val id = alarmChannelId(vibrate)
        if (manager.getNotificationChannel(id) != null) return
        val channel = NotificationChannel(
            id,
            "Alarm",
            NotificationManager.IMPORTANCE_MAX,
        ).apply {
            description = "Full-screen alarm with in-app continuous sound"
            setSound(null, null)
            enableVibration(false)
            enableLights(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun alarmChannelId(vibrate: Boolean): String =
        if (vibrate) ALARM_CHANNEL_VIBRATE else ALARM_CHANNEL_SILENT

    /**
     * The single, user-facing alarm notification. It is posted as the
     * foreground-service notification under the slot's id, so it replaces the
     * `flutter_local_notifications` one of the same id instead of stacking a
     * second notification. It carries the full-screen intent (lock-screen
     * launch) and the delete intent that restores it after a swipe.
     */
    private fun buildNotification(current: AlarmTriggerPayload): Notification {
        val text = String.format(
            Locale.getDefault(),
            "%02d:%02d",
            current.hour,
            current.minute,
        )
        val builder =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, alarmChannelId(current.vibrate))
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this).setPriority(Notification.PRIORITY_MAX)
            }
        builder
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(if (current.label.isNotEmpty()) current.label else "AALUMAI")
            .setContentText(text)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setShowWhen(true)
            .setWhen(System.currentTimeMillis())
        @Suppress("DEPRECATION")
        builder.setCategory(Notification.CATEGORY_ALARM)
        builder.setVisibility(Notification.VISIBILITY_PUBLIC)

        val open =
            PendingIntent.getActivity(
                this,
                current.slotId,
                openAlarmIntent(current),
                pendingFlags(),
            )
        builder.setContentIntent(open)
        val manager = getSystemService(NotificationManager::class.java)
        val canUseFullScreen =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE ||
                manager.canUseFullScreenIntent()
        if (canUseFullScreen) {
            builder.setFullScreenIntent(open, true)
        }

        val dismissed =
            Intent(this, AlarmNotificationDismissedReceiver::class.java)
                .setAction(AlarmIntent.ACTION_NOTIFICATION_DISMISSED)
                .putExtra(AlarmIntent.EXTRA_SLOT_ID, current.slotId)
        builder.setDeleteIntent(
            PendingIntent.getBroadcast(this, current.slotId, dismissed, pendingFlags()),
        )
        return builder.build()
    }

    private fun openAlarmIntent(current: AlarmTriggerPayload): Intent =
        Intent(this, MainActivity::class.java)
            .setAction(AlarmIntent.ACTION_OPEN_ALARM)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            .putExtra(AlarmIntent.EXTRA_ALARM_ID, current.alarmId)

    private fun pendingFlags(): Int {
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return flags
    }

    /**
     * Guarantees the surviving notification under the slot id is this one, which
     * is the only one carrying the delete intent. Cheap: it only re-posts when
     * the current notification is missing or is a foreign one (the notification
     * plugin racing to the same id), never in a loop.
     */
    private fun ensureAlarmNotification(current: AlarmTriggerPayload) {
        try {
            val manager = getSystemService(NotificationManager::class.java)
            val existing =
                manager.activeNotifications
                    ?.firstOrNull { it.id == current.slotId }
                    ?.notification
            if (existing != null && existing.deleteIntent != null) return
            startAsForeground(current)
        } catch (e: Exception) {
            Log.w(TAG, "Unable to refresh the alarm notification: $e")
        }
    }
}

/** Bundled tone ids and their asset paths, mirroring `AlarmSounds` in Dart. */
object AlarmSounds {
    const val FILE_PREFIX = "file:"
    const val DEFAULT_ID = "classic"
    const val DEFAULT_ASSET = "assets/audio/alarm_classic.wav"

    val ASSETS = mapOf(
        "classic" to "assets/audio/alarm_classic.wav",
        "gentle" to "assets/audio/alarm_gentle.wav",
        "urgent" to "assets/audio/alarm_urgent.wav",
    )
}
