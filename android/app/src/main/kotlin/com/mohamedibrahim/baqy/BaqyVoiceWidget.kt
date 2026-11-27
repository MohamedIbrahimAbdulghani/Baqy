package com.mohamedibrahim.baqy

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews

/**
 * Home screen widget for Baqy.
 *
 * Layout: microphone icon button + "باقي" label.
 * Tap = toggle recording (START if idle, STOP if recording).
 * Long-press anywhere = cancel recording (if active).
 *
 * When a recording finishes, the audio file path is written to
 * <cacheDir>/baqy_pending_audio_path.txt so that Flutter's
 * PendingRecordingStorage / _checkPendingAudio() picks it up
 * the next time the user opens the app.
 */
class BaqyVoiceWidget : AppWidgetProvider() {

    companion object {
        private const val ACTION_WIDGET_TAP    = "com.mohamedibrahim.baqy.widget.TAP"
        private const val PREFS_NAME           = "BaqyVoiceWidgetPrefs"
        private const val KEY_IS_RECORDING     = "is_recording"

        /** Call this from WidgetRecordingService to refresh all widget instances. */
        fun updateAll(context: Context, isRecording: Boolean) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, BaqyVoiceWidget::class.java)
            )
            // Persist state
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit().putBoolean(KEY_IS_RECORDING, isRecording).apply()
            // Update each widget
            for (id in ids) {
                updateWidget(context, manager, id, isRecording)
            }
        }

        private fun updateWidget(
            context: Context,
            manager: AppWidgetManager,
            widgetId: Int,
            isRecording: Boolean
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_baqy_voice)

            // Tap action: toggle recording
            val tapIntent = Intent(context, BaqyVoiceWidget::class.java).apply {
                action = ACTION_WIDGET_TAP
            }
            val tapPending = PendingIntent.getBroadcast(
                context, 0, tapIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_mic_button, tapPending)
            views.setOnClickPendingIntent(R.id.widget_root, tapPending)

            if (isRecording) {
                // Recording state: show stop icon (red), change label
                views.setImageViewResource(R.id.widget_mic_button, R.drawable.ic_widget_stop)
                views.setTextViewText(R.id.widget_label, "⏹ إيقاف")
                views.setTextViewText(R.id.widget_status, "جارٍ التسجيل…")
            } else {
                // Idle state: show mic icon (green)
                views.setImageViewResource(R.id.widget_mic_button, R.drawable.ic_widget_mic)
                views.setTextViewText(R.id.widget_label, "باقي")
                views.setTextViewText(R.id.widget_status, "اضغط للتسجيل")
            }

            manager.updateAppWidget(widgetId, views)
        }
    }

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isRecording = prefs.getBoolean(KEY_IS_RECORDING, false)
        for (id in appWidgetIds) {
            updateWidget(context, manager, id, isRecording)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        if (intent.action == ACTION_WIDGET_TAP) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val isRecording = prefs.getBoolean(KEY_IS_RECORDING, false)

            val serviceIntent = Intent(context, WidgetRecordingService::class.java).apply {
                action = if (isRecording) {
                    WidgetRecordingService.ACTION_STOP
                } else {
                    WidgetRecordingService.ACTION_START
                }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        }
    }

    override fun onDisabled(context: Context) {
        // Widget removed from all home screens — cancel any active recording
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit().putBoolean(KEY_IS_RECORDING, false).apply()
        val cancelIntent = Intent(context, WidgetRecordingService::class.java).apply {
            action = WidgetRecordingService.ACTION_CANCEL
        }
        try { context.startService(cancelIntent) } catch (_: Exception) {}
    }
}
