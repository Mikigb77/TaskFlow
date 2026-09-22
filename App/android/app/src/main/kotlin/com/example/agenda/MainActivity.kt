package com.example.agenda

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    private var speech: NativeSpeechBridge? = null
    private var entries: CaptureEntryBridge? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        speech = NativeSpeechBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        entries = CaptureEntryBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) entries?.receive(intent)
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        entries?.receive(intent)
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (speech?.permissionResponse(requestCode, grantResults) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
    override fun onPause() { speech?.interrupt(); super.onPause() }
    override fun onDestroy() { speech?.close(); speech = null; entries?.close(); entries = null; super.onDestroy() }
}
