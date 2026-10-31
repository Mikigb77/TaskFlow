package com.example.agenda

import android.app.Activity
import android.app.LocaleManager
import android.os.Build
import android.os.LocaleList
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.IllformedLocaleException
import java.util.Locale

/**
 * Ajustes › Idioma as Android's per-app language (Android 13+), so the widget, the launcher
 * shortcuts and the share messages speak the app's language, as the app and its reminders do.
 * An empty list («Como el teléfono») clears it. Below Android 13 nothing changes: those follow
 * the phone.
 *
 * The activity declares `locale` in configChanges, so the change doesn't recreate it;
 * MainActivity.onConfigurationChanged republishes the shortcuts and redraws the widget.
 * Answers the phone's own languages, which Flutter no longer sees under a per-app language.
 */
class AppLanguageBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "taskflow/app-language")

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "apply") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                result.success(null)
                return@setMethodCallHandler
            }
            val languages = call.argument<List<String>>("languages") ?: emptyList()
            try {
                val manager = activity.getSystemService(LocaleManager::class.java)
                val phone = manager.systemLocales
                val wanted = LocaleList(*languages.map { inPhoneRegion(it, phone) }.toTypedArray())
                if (manager.applicationLocales != wanted) manager.applicationLocales = wanted
                result.success((0 until phone.size()).map { phone[it].toLanguageTag() })
            } catch (_: RuntimeException) {
                result.error("language_unavailable", "The per-app language could not be set.", null)
            }
        }
    }

    /** The app's language with the phone's region, so dates, clock and first weekday stay the phone's. */
    private fun inPhoneRegion(language: String, phone: LocaleList): Locale {
        val region = if (phone.isEmpty) null else phone[0]
        return try {
            Locale.Builder().apply { if (region != null) setLocale(region) }
                .setScript("").setVariant("").setLanguage(language).build()
        } catch (_: IllformedLocaleException) {
            Locale.forLanguageTag(language)
        }
    }

    fun close() { channel.setMethodCallHandler(null) }
}
