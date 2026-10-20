package com.example.agenda

import android.content.Intent
import android.content.res.Configuration
import android.os.Bundle
import android.os.LocaleList
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private var speech: NativeSpeechBridge? = null
    private var entries: CaptureEntryBridge? = null
    private var calendars: DeviceCalendarBridge? = null
    private var stagingBilling: StagingBillingBridge? = null
    private var accessibility: AccessibilityBridge? = null
    private var language: AppLanguageBridge? = null
    private var locales: LocaleList? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        speech = NativeSpeechBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        entries = CaptureEntryBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        calendars = DeviceCalendarBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        stagingBilling = StagingBillingBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        accessibility = AccessibilityBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        language = AppLanguageBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        // TaskFlow's own notifications page, one switch away; Dart falls back to App info.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "taskflow/app-settings").setMethodCallHandler { call, result ->
            if (call.method != "openNotificationSettings") return@setMethodCallHandler result.notImplemented()
            try {
                startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                result.success(null)
            } catch (error: Exception) {
                result.error("unavailable", error.message, null)
            }
        }
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        locales = resources.configuration.locales
        CaptureShortcuts.publish(this)
        if (savedInstanceState == null) entries?.receive(intent)
    }
    // A new language, the app's (Idioma) or the phone's: the shortcuts and the widget follow it.
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (newConfig.locales == locales) return
        locales = newConfig.locales
        CaptureShortcuts.publish(this)
        CaptureWidget.refresh(this)
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        entries?.receive(intent)
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (speech?.permissionResponse(requestCode, grantResults) == true) return
        if (calendars?.permissionResponse(requestCode) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
    override fun onPause() { speech?.interrupt(); super.onPause() }
    override fun onDestroy() { speech?.close(); speech = null; entries?.close(); entries = null; calendars?.close(); calendars = null; stagingBilling?.close(); stagingBilling = null; accessibility?.close(); accessibility = null; language?.close(); language = null; super.onDestroy() }
}
