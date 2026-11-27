package com.mohamedibrahim.baqy

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.MediaRecorder
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.FileOutputStream

/**
 * Foreground service that handles voice recording triggered from the home screen widget.
 * Records audio, saves it to the same path that PendingRecordingStorage in Flutter reads.
 * When the user opens the app, the existing _checkPendingAudio() flow in expense_providers.dart
 * will find this file and send it to Gemini automatically.
 *
 * Actions:
 *  ACTION_START  – start recording (shows notification)
 *  ACTION_STOP   – stop recording, persist path, stop service
 *  ACTION_CANCEL – discard recording, stop service
 */
class WidgetRecordingService : Service() {

    companion object {
        const val ACTION_START  = "com.mohamedibrahim.baqy.widget.START_RECORDING"
        const val ACTION_STOP   = "com.mohamedibrahim.baqy.widget.STOP_RECORDING"
        const val ACTION_CANCEL = "com.mohamedibrahim.baqy.widget.CANCEL_RECORDING"

        const val CHANNEL_ID = "baqy_widget_recording"
        const val NOTIFICATION_ID = 7819  // Arbitrary unique ID

        /** Shared prefs key – mirrors what PendingRecordingStorage in Flutter writes */
        const val PENDING_AUDIO_PREFS = "baqy_widget_prefs"
        const val PENDING_AUDIO_KEY   = "pending_widget_audio_path"

        /** Returns true if a widget-initiated recording is pending Flutter pickup. */
        fun hasPendingWidgetRecording(context: Context): Boolean {
            val prefs = context.getSharedPreferences(PENDING_AUDIO_PREFS, Context.MODE_PRIVATE)
            val path = prefs.getString(PENDING_AUDIO_KEY, null) ?: return false
            return File(path).exists()
        }

        /** Returns the pending audio file path (or null if none). */
        fun getPendingWidgetAudioPath(context: Context): String? {
            val prefs = context.getSharedPreferences(PENDING_AUDIO_PREFS, Context.MODE_PRIVATE)
            val path = prefs.getString(PENDING_AUDIO_KEY, null) ?: return null
            return if (File(path).exists()) path else null
        }

        /** Clears the pending audio record (called by Flutter after processing). */
        fun clearPendingWidgetAudio(context: Context) {
            val prefs = context.getSharedPreferences(PENDING_AUDIO_PREFS, Context.MODE_PRIVATE)
            prefs.edit().remove(PENDING_AUDIO_KEY).apply()
            try {
                val pointerFile = File(context.cacheDir, "baqy_pending_audio_path.txt")
                if (pointerFile.exists()) pointerFile.delete()
            } catch (_: Exception) {}
        }
    }

    private var mediaRecorder: MediaRecorder? = null
    private var outputFile: File? = null

    // ─── Service lifecycle ────────────────────────────────────────────────────

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START  -> handleStart()
            ACTION_STOP   -> handleStop()
            ACTION_CANCEL -> handleCancel()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        releaseRecorder()
        super.onDestroy()
    }

    // ─── Action handlers ──────────────────────────────────────────────────────

    private fun handleStart() {
        // If already recording (service restarted), ignore.
        if (mediaRecorder != null) return

        val file = createOutputFile() ?: run { stopSelf(); return }
        outputFile = file

        startForeground(NOTIFICATION_ID, buildRecordingNotification())

        try {
            @Suppress("DEPRECATION")
            val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                MediaRecorder()
            }
            recorder.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioChannels(1)
                setAudioSamplingRate(16000)
                setAudioEncodingBitRate(32000)
                setOutputFile(file.absolutePath)
                prepare()
                start()
            }
            mediaRecorder = recorder

            // Update widget to show recording state
            BaqyVoiceWidget.updateAll(this, isRecording = true)
        } catch (e: Exception) {
            releaseRecorder()
            outputFile?.delete()
            outputFile = null
            stopSelf()
        }
    }

    private fun handleStop() {
        val file = outputFile
        try {
            mediaRecorder?.apply {
                stop()
                release()
            }
        } catch (_: Exception) {
            // MediaRecorder.stop() can throw if recording was too short (<1s)
        }
        mediaRecorder = null

        if (file != null && file.exists() && file.length() > 0) {
            val audioPath = file.absolutePath
            // Persist path so Flutter fallback can find it if process is killed
            savePendingAudioPath(audioPath)
            writeTempPointerFile(audioPath)

            // Trigger immediate background processing in Flutter if MainActivity is alive
            val activity = MainActivity.instance
            val channel = MainActivity.widgetChannel
            if (activity != null && channel != null) {
                activity.runOnUiThread {
                    channel.invokeMethod("onWidgetAudioReady", audioPath)
                }
            }
        }
        outputFile = null

        // Update widget back to idle state
        BaqyVoiceWidget.updateAll(this, isRecording = false)

        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun handleCancel() {
        try {
            mediaRecorder?.apply {
                stop()
                release()
            }
        } catch (_: Exception) {}
        mediaRecorder = null

        outputFile?.delete()
        outputFile = null

        BaqyVoiceWidget.updateAll(this, isRecording = false)

        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private fun createOutputFile(): File? {
        return try {
            val dir = cacheDir  // Same root as Flutter's getTemporaryDirectory()
            if (!dir.exists()) dir.mkdirs()
            val ts = System.currentTimeMillis()
            File(dir, "baqy_widget_rec_$ts.m4a")
        } catch (_: Exception) { null }
    }

    /**
     * Saves audio path to SharedPreferences so the Flutter MethodChannel can read it.
     * BaqyVoiceWidget's MethodChannel handler in MainActivity will pass this to Flutter.
     */
    private fun savePendingAudioPath(path: String) {
        getSharedPreferences(PENDING_AUDIO_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(PENDING_AUDIO_KEY, path)
            .apply()
    }

    /**
     * Writes the same pointer file that Flutter's PendingRecordingStorage writes,
     * so _checkPendingAudio() finds the pending file when the app opens.
     * File path: <cacheDir>/baqy_pending_audio_path.txt (matches PendingRecordingStorage._getFile())
     */
    private fun writeTempPointerFile(audioPath: String) {
        try {
            val pointerFile = File(cacheDir, "baqy_pending_audio_path.txt")
            FileOutputStream(pointerFile).use { it.write(audioPath.toByteArray()) }
        } catch (_: Exception) {}
    }

    private fun releaseRecorder() {
        try { mediaRecorder?.release() } catch (_: Exception) {}
        mediaRecorder = null
    }

    // ─── Notification ─────────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Baqy Voice Recording",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Used while recording from the home screen widget"
                setSound(null, null)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildRecordingNotification(): Notification {
        val stopIntent = Intent(this, WidgetRecordingService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 0, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val cancelIntent = Intent(this, WidgetRecordingService::class.java).apply {
            action = ACTION_CANCEL
        }
        val cancelPendingIntent = PendingIntent.getService(
            this, 1, cancelIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("باقي – جارٍ التسجيل…")
            .setContentText("اضغط إيقاف لحفظ المصروف أو إلغاء لمسح التسجيل")
            .setSmallIcon(R.drawable.ic_notification)
            .setOngoing(true)
            .setSilent(true)
            .addAction(0, "⏹ إيقاف", stopPendingIntent)
            .addAction(0, "✕ إلغاء", cancelPendingIntent)
            .build()
    }
}
