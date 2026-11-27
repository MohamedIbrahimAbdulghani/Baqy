package com.mohamedibrahim.baqy

import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterFragmentActivity() {
    companion object {
        var instance: MainActivity? = null
        var widgetChannel: MethodChannel? = null
    }

    private val CHANNEL = "com.mohamedibrahim.baqy/file_saver"
    private val SHORTCUT_CHANNEL = "com.mohamedibrahim.baqy/shortcut"
    private val WIDGET_CHANNEL = "com.mohamedibrahim.baqy/widget"

    private var initialShortcutAction: String? = null
    private var shortcutChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        handleShortcutIntent(intent, isInitial = true)
    }

    override fun onDestroy() {
        if (instance == this) instance = null
        widgetChannel = null
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShortcutIntent(intent, isInitial = false)
    }

    private fun handleShortcutIntent(intent: Intent?, isInitial: Boolean) {
        val action = intent?.action
        // Strict security: Accept only fixed action name; ignore any unknown or missing action
        val validAction = if (action == "record_voice" || action == "com.mohamedibrahim.baqy.action.RECORD_VOICE") {
            "record_voice"
        } else {
            null
        }

        if (validAction != null) {
            if (isInitial) {
                initialShortcutAction = validAction
            }
            shortcutChannel?.invokeMethod("onShortcutTriggered", validAction)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "saveToDownloads") {
                val fileName = call.argument<String>("fileName")
                val bytes = call.argument<ByteArray>("bytes")
                val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"

                if (fileName == null || bytes == null) {
                    result.error("INVALID_ARGS", "fileName and bytes must not be null", null)
                    return@setMethodCallHandler
                }

                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val contentValues = ContentValues().apply {
                            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                        }

                        val resolver = applicationContext.contentResolver
                        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)

                        if (uri != null) {
                            resolver.openOutputStream(uri)?.use { outputStream ->
                                outputStream.write(bytes)
                                outputStream.flush()
                            }
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } else {
                        val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                        if (!downloadsDir.exists()) {
                            downloadsDir.mkdirs()
                        }
                        val file = File(downloadsDir, fileName)
                        FileOutputStream(file).use { outputStream ->
                            outputStream.write(bytes)
                            outputStream.flush()
                        }
                        result.success(true)
                    }
                } catch (e: Exception) {
                    result.error("SAVE_FAILED", e.localizedMessage, null)
                }
            } else {
                result.notImplemented()
            }
        }

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHORTCUT_CHANNEL)
        shortcutChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialShortcut" -> {
                    val action = initialShortcutAction
                    initialShortcutAction = null
                    result.success(action)
                }
                else -> result.notImplemented()
            }
        }

        // Widget channel – Flutter calls these after processing widget-initiated recordings
        val wChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
        widgetChannel = wChannel
        wChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                // Returns the audio path recorded by the widget (if any), so Flutter can process it
                "getWidgetPendingAudioPath" -> {
                    val path = WidgetRecordingService.getPendingWidgetAudioPath(this)
                    result.success(path)
                }
                // Called by Flutter after successfully processing the widget recording
                "clearWidgetPendingAudio" -> {
                    WidgetRecordingService.clearPendingWidgetAudio(this)
                    result.success(null)
                }
                // Returns whether the widget is currently recording (to avoid duplicates)
                "hasWidgetPendingRecording" -> {
                    result.success(WidgetRecordingService.hasPendingWidgetRecording(this))
                }
                else -> result.notImplemented()
            }
        }
    }
}
