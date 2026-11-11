package com.example.agenda

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.ContentValues
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
import java.util.TimeZone
import java.util.concurrent.Executors

/**
 * Reads the OS calendar provider, and, only after the person turns on «Add my
 * tasks to my calendar» and allows WRITE_CALENDAR, adds, changes and removes
 * the events TaskFlow made for its tasks. It never touches any other event.
 */
class DeviceCalendarBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "taskflow/device_calendars")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val preferences = activity.getSharedPreferences("calendar_access", Activity.MODE_PRIVATE)
    private var pending: MethodChannel.Result? = null
    private var pendingWrite: MethodChannel.Result? = null
    private var observing = false
    private var closed = false
    private val permissionCode = 4923
    private val writePermissionCode = 4924
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
                "writeStatus" -> result.success(writeStatus())
                "requestWritePermission" -> {
                    if (writeGranted()) result.success("granted")
                    else if (pendingWrite != null || pending != null) result.error("calendar_busy", "A calendar permission request is already open.", null)
                    else {
                        pendingWrite = result
                        preferences.edit().putBoolean("askedWrite", true).apply()
                        activity.requestPermissions(arrayOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR), writePermissionCode)
                    }
                }
                "write" -> {
                    val writes = call.argument<List<Map<String, Any?>>>("writes")
                    if (writes == null || writes.size > 100) result.error("calendar_write", "Send up to 100 changes at once.", null)
                    else if (!writeGranted()) result.error("calendar_permission", "Calendar access is unavailable.", null)
                    else query(result, write = true) { writes.map { apply(it) } }
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
    private fun writeGranted() = granted() && PermissionChecker.checkSelfPermission(activity, Manifest.permission.WRITE_CALENDAR) == PermissionChecker.PERMISSION_GRANTED
    private fun writeStatus(): String = if (writeGranted()) "granted" else if (preferences.getBoolean("askedWrite", false) &&
        !activity.shouldShowRequestPermissionRationale(Manifest.permission.WRITE_CALENDAR)) "blocked" else "denied"
    private fun status(): String = if (granted()) "granted" else if (preferences.getBoolean("asked", false) &&
        !activity.shouldShowRequestPermissionRationale(Manifest.permission.READ_CALENDAR)) "blocked" else "denied"

    fun permissionResponse(code: Int): Boolean {
        if (code == writePermissionCode) {
            observe()
            pendingWrite?.success(writeStatus())
            pendingWrite = null
            return true
        }
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

    private fun query(result: MethodChannel.Result, write: Boolean = false, operation: () -> Any) {
        if (!granted()) { result.error("calendar_permission", "Calendar access is unavailable.", null); return }
        worker.execute {
            try {
                val value = operation()
                main.post {
                    if (!closed) {
                        if (granted() || write) result.success(value)
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
            CalendarContract.Calendars.ACCOUNT_TYPE, CalendarContract.Calendars.NAME,
            CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL, CalendarContract.Calendars.OWNER_ACCOUNT,
            CalendarContract.Calendars.IS_PRIMARY)
        val rows = mutableListOf<Map<String, Any>>()
        var truncated = false
        activity.contentResolver.query(CalendarContract.Calendars.CONTENT_URI, columns,
            "${CalendarContract.Calendars.VISIBLE}=1 AND ${CalendarContract.Calendars.SYNC_EVENTS}=1", null,
            "${CalendarContract.Calendars.CALENDAR_DISPLAY_NAME} COLLATE NOCASE")?.use { cursor ->
            while (cursor.moveToNext()) {
                if (rows.size == 200) { truncated = true; break }
                val account = cursor.getString(2) ?: ""
                val owner = cursor.getString(7) ?: ""
                // Contributors and above may add events: the account's own calendars.
                val writable = cursor.getInt(6) >= CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR
                val primary = (!cursor.isNull(8) && cursor.getInt(8) != 0) || (owner.isNotEmpty() && owner.equals(account, ignoreCase = true))
                rows.add(mapOf("id" to cursor.getLong(0).toString(), "name" to (cursor.getString(1) ?: ""),
                    "account" to account, "color" to cursor.getInt(3),
                    "accountType" to (cursor.getString(4) ?: ""), "sourceId" to (cursor.getString(5) ?: ""),
                    "writable" to writable, "primary" to primary, "type" to ""))
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

    /** One change to an event TaskFlow added: an insert answers the new id ("" when it failed); others "ok" or "gone". */
    private fun apply(write: Map<String, Any?>): String {
        val calendar = (write["calendar"] as? String)?.toLongOrNull() ?: return ""
        val event = (write["event"] as? String)?.toLongOrNull()
        return try {
            when (write["op"]) {
                "delete" -> {
                    if (event != null) activity.contentResolver.delete(ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, event),
                        "${CalendarContract.Events.CALENDAR_ID}=?", arrayOf(calendar.toString()))
                    "ok"
                }
                "update" -> {
                    if (event == null || !exists(event, calendar)) "gone"
                    else if (activity.contentResolver.update(ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, event),
                            values(write, calendar), null, null) > 0) "ok" else "gone"
                }
                "insert" -> activity.contentResolver.insert(CalendarContract.Events.CONTENT_URI, values(write, calendar))
                    ?.lastPathSegment ?: ""
                else -> ""
            }
        } catch (_: SecurityException) {
            throw SecurityException("Calendar access was removed.")
        } catch (_: Exception) { if (write["op"] == "insert") "" else "gone" }
    }

    private fun exists(event: Long, calendar: Long): Boolean =
        activity.contentResolver.query(CalendarContract.Events.CONTENT_URI, arrayOf(CalendarContract.Events._ID),
            "${CalendarContract.Events._ID}=? AND ${CalendarContract.Events.CALENDAR_ID}=? AND ${CalendarContract.Events.DELETED}=0",
            arrayOf(event.toString(), calendar.toString()), null)?.use { it.moveToFirst() } ?: false

    private fun values(write: Map<String, Any?>, calendar: Long): ContentValues {
        val allDay = write["allDay"] == true
        return ContentValues().apply {
            put(CalendarContract.Events.CALENDAR_ID, calendar)
            put(CalendarContract.Events.TITLE, (write["title"] as? String ?: "").take(500))
            put(CalendarContract.Events.DTSTART, (write["start"] as Number).toLong())
            put(CalendarContract.Events.DTEND, (write["end"] as Number).toLong())
            put(CalendarContract.Events.ALL_DAY, if (allDay) 1 else 0)
            // All-day events are stored at UTC midnights, as the provider requires.
            put(CalendarContract.Events.EVENT_TIMEZONE, if (allDay) "UTC" else TimeZone.getDefault().id)
        }
    }

    fun close() {
        closed = true
        pending?.error("calendar_closed", "The calendar screen closed. Try again.", null)
        pending = null
        pendingWrite?.error("calendar_closed", "The calendar screen closed. Try again.", null)
        pendingWrite = null
        if (observing) activity.contentResolver.unregisterContentObserver(observer)
        observing = false
        channel.setMethodCallHandler(null)
        worker.shutdownNow()
    }

    companion object { private const val DAY = 86_400_000L }
}
