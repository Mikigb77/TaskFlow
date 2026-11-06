package com.example.agenda

import android.content.Context
import android.content.Intent
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat

/**
 * The launcher's capture shortcuts (dictate, type, and record a meeting), published from code on every start.
 *
 * A static shortcuts.xml needs the app's package as a literal string: a string resource
 * there is never resolved, so the shortcuts pointed nowhere and the launcher refused to
 * start them. The staging build has its own package, and the package is due to change
 * before the Play upload (App/docs/PACKAGE_ID.md). An intent built from this context names
 * the right one in every build. Republishing each start, and whenever the language changes,
 * keeps the labels in the app's language (the per-app language on Android 13+, see
 * AppLanguageBridge).
 *
 * The short label is one word: at large text the launcher shows it whole, where the long
 * one was cut to «Dictar un…». The launcher shows the long label wherever it fits.
 *
 * On Android 8+ each icon resource is an adaptive icon (drawable-anydpi-v26), which a
 * resource icon keeps: the launcher fills its own circle with the mint, where the plain
 * vector of Android 7 (drawable/) came out as a small disc inside a white one (UX-2112).
 */
object CaptureShortcuts {
    fun publish(context: Context) {
        val shortcuts = listOf(
            shortcut(context, "capture_voice", R.string.capture_voice_short, R.string.capture_voice, R.drawable.capture_shortcut_voice, CaptureEntryBridge.VOICE),
            shortcut(context, "capture_text", R.string.capture_text_short, R.string.capture_text, R.drawable.capture_shortcut_text, CaptureEntryBridge.TEXT),
            shortcut(context, "capture_meeting", R.string.capture_meeting_short, R.string.capture_meeting, R.drawable.capture_shortcut_meeting, CaptureEntryBridge.MEETING),
        )
        // The launcher's rate limit, or a launcher without shortcuts, must never stop the app.
        try { ShortcutManagerCompat.setDynamicShortcuts(context, shortcuts) } catch (_: Exception) { }
    }

    private fun shortcut(context: Context, id: String, shortLabel: Int, longLabel: Int, icon: Int, action: String) =
        ShortcutInfoCompat.Builder(context, id)
            .setShortLabel(context.getString(shortLabel))
            .setLongLabel(context.getString(longLabel))
            .setIcon(IconCompat.createWithResource(context, icon))
            .setIntent(Intent(context, MainActivity::class.java).setAction(action))
            .build()
}
