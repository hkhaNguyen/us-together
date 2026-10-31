package com.hkha.us_together

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Photos shared into the app from another one ("Chia sẻ" in the gallery)
 * wait here until Dart asks for them with `takeShared`; if the app is
 * already running, Dart is told with `shared` first.
 */
class MainActivity : FlutterActivity() {
    private val pending = mutableListOf<Uri>()
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "us_together/share").apply {
            setMethodCallHandler { call, result ->
                if (call.method != "takeShared") return@setMethodCallHandler result.notImplemented()
                val uris = pending.toList()
                pending.clear()
                // Photos can be large: read them off the UI thread.
                Thread {
                    val photos = uris.mapNotNull { uri ->
                        runCatching { contentResolver.openInputStream(uri)?.use { it.readBytes() } }.getOrNull()
                    }
                    runOnUiThread { result.success(photos) }
                }.start()
            }
        }
        collect(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (collect(intent)) channel?.invokeMethod("shared", null)
    }

    /** Queues the photos [intent] shares, if any; true when it shared some. */
    private fun collect(intent: Intent?): Boolean {
        val uris = intent?.sharedStreams().orEmpty()
        pending += uris
        // Handled: a later configuration change mustn't share them again.
        if (uris.isNotEmpty()) intent?.action = Intent.ACTION_MAIN
        return uris.isNotEmpty()
    }

    @Suppress("DEPRECATION")
    private fun Intent.sharedStreams(): List<Uri> = when (action) {
        Intent.ACTION_SEND -> listOfNotNull(getParcelableExtra(Intent.EXTRA_STREAM) as? Uri)
        Intent.ACTION_SEND_MULTIPLE -> getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM).orEmpty()
        else -> emptyList()
    }
}
