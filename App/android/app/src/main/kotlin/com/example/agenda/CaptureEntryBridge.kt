package com.example.agenda

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.widget.Toast
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/** Incoming shares remain pending until Flutter has durably saved the capture. */
class CaptureEntryBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val preferences = activity.getSharedPreferences("capture_entries", Activity.MODE_PRIVATE)
    private val channel = MethodChannel(messenger, "taskflow/capture-entries")
    companion object {
        const val VOICE = "com.example.agenda.CAPTURE_VOICE"
        const val TEXT = "com.example.agenda.CAPTURE_TEXT"
        const val MEETING = "com.example.agenda.CAPTURE_MEETING"
    }
    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "pending" -> {
                    val queue = pending()
                    result.success((0 until queue.length()).map { index ->
                        val item = queue.getJSONObject(index)
                        mapOf("id" to item.getString("id"), "kind" to item.getString("kind"),
                            "text" to item.getString("text"), "capturedAt" to item.getLong("capturedAt"))
                    })
                }
                "acknowledge" -> {
                    val id = call.argument<String>("id")
                    val queue = pending()
                    val remaining = JSONArray()
                    for (i in 0 until queue.length()) {
                        val item = queue.getJSONObject(i)
                        if (item.getString("id") != id) remaining.put(item)
                    }
                    if (preferences.edit().putString("pending", remaining.toString()).commit()) result.success(null)
                    else result.error("storage", "Could not acknowledge the capture. It is still retained.", null)
                }
                "pinWidget" -> {
                    val manager = AppWidgetManager.getInstance(activity)
                    result.success(Build.VERSION.SDK_INT >= 26 && manager.isRequestPinAppWidgetSupported &&
                        manager.requestPinAppWidget(ComponentName(activity, CaptureWidget::class.java), null, null))
                }
                else -> result.notImplemented()
            }
        }
    }
    private fun pending(): JSONArray = try { JSONArray(preferences.getString("pending", "[]")) } catch (_: Exception) { JSONArray() }

    fun receive(intent: Intent?) {
        if (intent == null || intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
        val kind = when (intent.action) {
            VOICE -> "voice"
            TEXT -> "text"
            MEETING -> "meeting"
            Intent.ACTION_SEND -> if (intent.type == "text/plain") "share" else return
            else -> return
        }
        val text = if (kind == "share") try { intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()?.trim().orEmpty() } catch (_: Exception) { "" } else ""
        if (kind == "share" && text.isEmpty()) {
            Toast.makeText(activity, R.string.share_empty, Toast.LENGTH_LONG).show()
            return
        }
        if (kind == "share" && text.length > 4000) {
            Toast.makeText(activity, R.string.share_too_long, Toast.LENGTH_LONG).show()
            return
        }
        val queue = pending()
        if (queue.length() >= 16) {
            Toast.makeText(activity, R.string.share_queue_full, Toast.LENGTH_LONG).show()
            return
        }
        queue.put(JSONObject().put("id", UUID.randomUUID().toString()).put("kind", kind)
            .put("text", text).put("capturedAt", System.currentTimeMillis()))
        if (preferences.edit().putString("pending", queue.toString()).commit()) {
            // Recreating the activity must not consume the same in-memory intent again.
            intent.action = Intent.ACTION_MAIN
            intent.removeExtra(Intent.EXTRA_TEXT)
            channel.invokeMethod("changed", null)
        } else {
            Toast.makeText(activity, R.string.share_not_saved, Toast.LENGTH_LONG).show()
        }
    }
    fun close() { channel.setMethodCallHandler(null) }
}
