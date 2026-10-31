package com.example.agenda

import android.content.Context
import android.os.Build
import android.view.accessibility.AccessibilityManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Reads the user's preferred time to interact with text and an action button. */
class AccessibilityBridge(context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "taskflow/accessibility")

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "recommendedActionTimeout") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val original = call.argument<Int>("originalTimeoutMillis")
            if (original == null || original <= 0) {
                result.error("invalid_timeout", "A positive timeout is required.", null)
                return@setMethodCallHandler
            }
            try {
                val manager = context.getSystemService(AccessibilityManager::class.java)
                val recommended = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && manager != null) {
                    manager.getRecommendedTimeoutMillis(
                        original,
                        AccessibilityManager.FLAG_CONTENT_TEXT or AccessibilityManager.FLAG_CONTENT_CONTROLS
                    )
                } else original
                result.success(recommended.coerceAtLeast(original))
            } catch (_: RuntimeException) {
                result.error("timeout_unavailable", "The recommended timeout is unavailable.", null)
            }
        }
    }

    fun close() { channel.setMethodCallHandler(null) }
}
