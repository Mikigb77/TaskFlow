package com.example.agenda

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.Intent
import androidx.core.content.PermissionChecker
import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.CalendarContract
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** Reads the OS calendar provider. This bridge has no insert/update/delete path. */
class DeviceCalendarBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "taskflow/device_calendars")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val preferences = activity.getSharedPreferences("calendar_access", Activity.MODE_PRIVATE)
    private var pending: MethodChannel.Result? = null
    private var observing = false
    private var closed = false
    private val permissionCode = 4923
    private val observer = object : ContentObserver(main) {
        override fun onChange(selfChange: Boolean) {
            if (!closed) channel.invokeMethod("changed", null)
        }
    }

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> { observe(); result.success(status()) }
                "requestPermission" -> {
                    if (granted()) { observe(); result.success("granted") }
                    else if (pending != null) result.error("calendar_busy", "A calendar permission request is already open.", null)
                    else {
                        pending = result
                        preferences.edit().putBoolean("asked", true).apply()
                        activity.requestPermissions(arrayOf(Manifest.permission.READ_CALENDAR), permissionCode)
                    }
                }
                "settings" -> {
                    activity.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${activity.packageName}")))
                    result.success(null)
                }
                "calendars" -> query(result) { calendars() }
                "events" -> {
                    val start = call.argument<Number>("start")?.toLong()
                    val end = call.argument<Number>("end")?.toLong()
                    val ids = call.argument<List<String>>("calendars")?.distinct()
                    if (start == null || end == null || end <= start || end - start > 3 * DAY ||
                        ids == null || ids.isEmpty() || ids.size > 50 || ids.any { it.toLongOrNull() == null }) {
                        result.error("calendar_range", "Choose up to 50 calendars and a bounded date range.", null)
                    } else query(result) { events(start, end, ids) }
                }
                "open" -> {
                    val id = call.argument<String>("id")?.toLongOrNull()
                    val start = call.argument<Number>("start")?.toLong()
                    val end = call.argument<Number>("end")?.toLong()
                    if (!granted()) result.error("calendar_permission", "Calendar access is unavailable.", null)
                    else if (id == null || start == null || end == null) result.error("calendar_event", "Invalid calendar event.", null)
                    else try {
                        activity.startActivity(Intent(Intent.ACTION_VIEW, ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, id))
                            .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, start).putExtra(CalendarContract.EXTRA_EVENT_END_TIME, end))
                        result.success(null)
                    } catch (_: Exception) { result.error("calendar_open", "No calendar app could open this event.", null) }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun granted() = PermissionChecker.checkSelfPermission(activity, Manifest.permission.READ_CALENDAR) == PermissionChecker.PERMISSION_GRANTED
    private fun status(): String = if (granted()) "granted" else if (preferences.getBoolean("asked", false) &&
        !activity.shouldShowRequestPermissionRationale(Manifest.permission.READ_CALENDAR)) "blocked" else "denied"

    fun permissionResponse(code: Int): Boolean {
        if (code != permissionCode) return false
        observe()
        pending?.success(status())
        pending = null
        return true
    }

    private fun observe() {
        if (granted() && !observing) {
            try {
                activity.contentResolver.registerContentObserver(CalendarContract.CONTENT_URI, true, observer)
                observing = true
            } catch (_: SecurityException) { /* Access may be revoked between checks. */ }
        } else if (!granted() && observing) {
            activity.contentResolver.unregisterContentObserver(observer)
            observing = false
        }
    }

    private fun query(result: MethodChannel.Result, operation: () -> Any) {
        if (!granted()) { result.error("calendar_permission", "Calendar access is unavailable.", null); return }
        worker.execute {
            try {
                val value = operation()
                main.post {
                    if (!closed) {
                        if (granted()) result.success(value)
                        else result.error("calendar_permission", "Calendar access was removed.", null)
                    }
                }
            } catch (_: SecurityException) {
                main.post { if (!closed) result.error("calendar_permission", "Calendar access was removed.", null) }
            } catch (_: Exception) {
                main.post { if (!closed) result.error("calendar_read", "Calendars could not be read. Try refreshing.", null) }
            }
        }
    }

    private fun calendars(): Any {
        val columns = arrayOf(CalendarContract.Calendars._ID, CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
            CalendarContract.Calendars.ACCOUNT_NAME, CalendarContract.Calendars.CALENDAR_COLOR,
            CalendarContract.Calendars.ACCOUNT_TYPE, CalendarContract.Calendars.NAME)
        val rows = mutableListOf<Map<String, Any>>()
        var truncated = false
        activity.contentResolver.query(CalendarContract.Calendars.CONTENT_URI, columns,
            "${CalendarContract.Calendars.VISIBLE}=1 AND ${CalendarContract.Calendars.SYNC_EVENTS}=1", null,
            "${CalendarContract.Calendars.CALENDAR_DISPLAY_NAME} COLLATE NOCASE")?.use { cursor ->
            while (cursor.moveToNext()) {
                if (rows.size == 200) { truncated = true; break }
                rows.add(mapOf("id" to cursor.getLong(0).toString(), "name" to (cursor.getString(1) ?: ""),
                    "account" to (cursor.getString(2) ?: ""), "color" to cursor.getInt(3),
                    "accountType" to (cursor.getString(4) ?: ""), "sourceId" to (cursor.getString(5) ?: "")))
            }
        }
        return mapOf("items" to rows, "truncated" to truncated)
    }

    private fun events(start: Long, end: Long, ids: List<String>): Any {
        // All-day dates are encoded at UTC midnight. The extra day on either
        // side ensures they survive even when the device is UTC-12 or UTC+14.
        val builder = CalendarContract.Instances.CONTENT_URI.buildUpon()
        ContentUris.appendId(builder, start - DAY)
        ContentUris.appendId(builder, end + DAY)
        val columns = arrayOf(CalendarContract.Instances.EVENT_ID, CalendarContract.Instances.CALENDAR_ID,
            CalendarContract.Instances.TITLE, CalendarContract.Instances.EVENT_LOCATION,
            CalendarContract.Instances.BEGIN, CalendarContract.Instances.END, CalendarContract.Instances.ALL_DAY,
            CalendarContract.Instances.EVENT_TIMEZONE, CalendarContract.Instances.UID_2445)
        val rows = mutableListOf<Map<String, Any>>()
        var truncated = false
        val selection = "${CalendarContract.Instances.CALENDAR_ID} IN (${ids.joinToString(",") { "?" }}) AND " +
            "${CalendarContract.Events.DELETED}=0 AND (${CalendarContract.Events.STATUS} IS NULL OR ${CalendarContract.Events.STATUS}!=${CalendarContract.Events.STATUS_CANCELED})"
        activity.contentResolver.query(builder.build(), columns, selection, ids.toTypedArray(),
            "${CalendarContract.Instances.BEGIN} ASC, ${CalendarContract.Instances.EVENT_ID} ASC")?.use { cursor ->
            while (cursor.moveToNext()) {
                if (rows.size == 1000) { truncated = true; break }
                rows.add(mapOf("id" to cursor.getLong(0).toString(), "calendarId" to cursor.getLong(1).toString(),
                    "title" to (cursor.getString(2) ?: "").take(500), "location" to (cursor.getString(3) ?: "").take(1000),
                    "start" to cursor.getLong(4), "end" to cursor.getLong(5), "allDay" to (cursor.getInt(6) != 0),
                    "timezone" to (cursor.getString(7) ?: ""), "uid" to (cursor.getString(8) ?: "")))
            }
        }
        return mapOf("items" to rows, "truncated" to truncated)
    }

    fun close() {
        closed = true
        pending?.error("calendar_closed", "The calendar screen closed. Try again.", null)
        pending = null
        if (observing) activity.contentResolver.unregisterContentObserver(observer)
        observing = false
        channel.setMethodCallHandler(null)
        worker.shutdownNow()
    }

    companion object { private const val DAY = 86_400_000L }
}
