package com.itsash.uth

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import org.json.JSONObject

/**
 * Foreground service (type mediaPlayback) that rings: loops the sound on the alarm audio stream,
 * vibrates, ramps the volume up and shows a full-screen notification that opens [RingActivity].
 * It runs until the challenge is solved ([stop]) or [MAX_RING_MS] passes.
 */
class AlarmService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var alarm: Alarm? = null
    private var rampStart = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ensureChannels(this)
        val json = intent?.getStringExtra(EXTRA_JSON)
        val test = intent?.getBooleanExtra(EXTRA_TEST, false) ?: false
        val parsed = try {
            json?.let { Alarm.fromJson(JSONObject(it)) }
        } catch (_: Exception) {
            null
        }
        if (json == null || parsed == null) {
            val minimal = Notification.Builder(this, CHANNEL_ALARM)
                .setSmallIcon(R.drawable.ic_stat_alarm)
                .setContentTitle("Alarm")
                .build()
            startForegroundWithType(minimal)
            stopSelf()
            return START_NOT_STICKY
        }
        alarm = parsed
        val notification = buildNotification(parsed, json, test)
        startForegroundWithType(notification)
        ringing = true
        acquireWakeLock()
        stopSound()
        startSound(parsed)
        startVibration(parsed)
        handler.removeCallbacksAndMessages(null)
        handler.postDelayed({ giveUp(parsed) }, MAX_RING_MS)
        // Best effort: when the phone is in use, show the ring screen at once (the full-screen intent covers the rest).
        try {
            startActivity(ringIntent(this, json, test).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (_: Exception) {
        }
        return START_NOT_STICKY
    }

    private fun startForegroundWithType(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(a: Alarm, json: String, test: Boolean): Notification {
        val open = PendingIntent.getActivity(
            this,
            REQUEST_RING,
            ringIntent(this, json, test),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val time = "%02d:%02d".format(a.hour, a.minute)
        return Notification.Builder(this, CHANNEL_ALARM)
            .setSmallIcon(R.drawable.ic_stat_alarm)
            .setContentTitle(if (a.label.isBlank()) "Alarm" else a.label)
            .setContentText(if (test) "Test alarm · $time" else "$time · tap to dismiss")
            .setCategory(Notification.CATEGORY_ALARM)
            .setOngoing(true)
            .setAutoCancel(false)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(open)
            .setFullScreenIntent(open, true)
            .build()
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(PowerManager::class.java)
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "uth:ring").apply { acquire(MAX_RING_MS + 10_000) }
    }

    private fun candidates(sound: String?): List<Uri> {
        val list = mutableListOf<Uri>()
        if (!sound.isNullOrEmpty()) list.add(Uri.parse(sound))
        RingtoneManager.getActualDefaultRingtoneUri(this, RingtoneManager.TYPE_ALARM)?.let { list.add(it) }
        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)?.let { list.add(it) }
        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)?.let { list.add(it) }
        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)?.let { list.add(it) }
        return list
    }

    private fun startSound(a: Alarm) {
        val audio = getSystemService(AudioManager::class.java)
        // A muted alarm stream would make the whole app pointless: lift it to at least 60 percent.
        val max = audio.getStreamMaxVolume(AudioManager.STREAM_ALARM)
        val floor = (max * 0.6).toInt().coerceAtLeast(1)
        if (audio.getStreamVolume(AudioManager.STREAM_ALARM) < floor) {
            audio.setStreamVolume(AudioManager.STREAM_ALARM, floor, 0)
        }
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .build()
        for (uri in candidates(a.sound)) {
            var p: MediaPlayer? = null
            try {
                p = MediaPlayer()
                p.setAudioAttributes(attrs)
                p.setDataSource(this, uri)
                p.isLooping = true
                p.prepare()
                val v = if (a.gradual) RAMP_START else 1f
                p.setVolume(v, v)
                p.start()
                player = p
                break
            } catch (_: Exception) {
                runCatching { p?.release() }
                // Missing or unreadable ringtone: try the next candidate.
            }
        }
        if (a.gradual && player != null) {
            rampStart = System.currentTimeMillis()
            handler.post(ramp)
        }
    }

    private val ramp = object : Runnable {
        override fun run() {
            val p = player ?: return
            val t = ((System.currentTimeMillis() - rampStart).toFloat() / RAMP_MS).coerceIn(0f, 1f)
            val v = RAMP_START + (1f - RAMP_START) * t
            try {
                p.setVolume(v, v)
            } catch (_: Exception) {
                return
            }
            if (t < 1f) handler.postDelayed(this, 1000)
        }
    }

    @Suppress("DEPRECATION")
    private fun startVibration(a: Alarm) {
        if (!a.vibrate) return
        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator ?: return
        val attrs = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build()
        vibrator.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 800, 500), 0), attrs)
    }

    private fun stopSound() {
        handler.removeCallbacks(ramp)
        player?.let {
            try {
                it.stop()
            } catch (_: Exception) {
            }
            it.release()
        }
        player = null
    }

    /** Nobody solved the challenge for [MAX_RING_MS]: stop the noise, leave a note. */
    private fun giveUp(a: Alarm) {
        val nm = getSystemService(NotificationManager::class.java)
        nm.notify(
            NOTIFICATION_MISSED,
            Notification.Builder(this, CHANNEL_MISSED)
                .setSmallIcon(R.drawable.ic_stat_alarm)
                .setContentTitle("Missed alarm")
                .setContentText(if (a.label.isBlank()) "%02d:%02d".format(a.hour, a.minute) else a.label)
                .setAutoCancel(true)
                .build(),
        )
        stopSelf()
    }

    override fun onDestroy() {
        ringing = false
        handler.removeCallbacksAndMessages(null)
        stopSound()
        (getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator)?.cancel()
        wakeLock?.let { if (it.isHeld) it.release() }
        super.onDestroy()
    }

    companion object {
        const val EXTRA_JSON = "alarmJson"
        const val EXTRA_TEST = "test"
        const val CHANNEL_ALARM = "alarm"
        const val CHANNEL_MISSED = "missed"
        private const val NOTIFICATION_ID = 42
        private const val NOTIFICATION_MISSED = 43
        private const val REQUEST_RING = 200
        private const val MAX_RING_MS = 15 * 60 * 1000L
        private const val RAMP_MS = 45_000L
        private const val RAMP_START = 0.15f

        @Volatile
        var ringing = false

        fun ringIntent(context: Context, json: String, test: Boolean): Intent =
            Intent(context, RingActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                .putExtra(EXTRA_JSON, json)
                .putExtra(EXTRA_TEST, test)

        fun start(context: Context, json: String, test: Boolean) {
            if (json.isBlank()) return
            try {
                Alarm.fromJson(JSONObject(json))
            } catch (_: Exception) {
                return
            }
            context.startForegroundService(
                Intent(context, AlarmService::class.java).putExtra(EXTRA_JSON, json).putExtra(EXTRA_TEST, test),
            )
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, AlarmService::class.java))
            context.getSystemService(NotificationManager::class.java).cancel(NOTIFICATION_MISSED)
        }

        fun ensureChannels(context: Context) {
            val nm = context.getSystemService(NotificationManager::class.java)
            val alarm = NotificationChannel(CHANNEL_ALARM, "Ringing alarm", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Shown while an alarm is ringing"
                setSound(null, null)
                enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setBypassDnd(true)
            }
            val missed = NotificationChannel(CHANNEL_MISSED, "Missed alarms", NotificationManager.IMPORTANCE_DEFAULT)
            nm.createNotificationChannel(alarm)
            nm.createNotificationChannel(missed)
        }
    }
}
