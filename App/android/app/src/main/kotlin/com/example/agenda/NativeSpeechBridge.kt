package com.example.agenda

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/** One foreground session. Never silently uses a network recognition service. */
class NativeSpeechBridge(private val activity: Activity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val channel = MethodChannel(messenger, "taskflow/speech")
    private val events = EventChannel(messenger, "taskflow/speech/events")
    private var sink: EventChannel.EventSink? = null
    private var recognizer: SpeechRecognizer? = null
    private var activeRun: Int? = null
    private var permissionResult: MethodChannel.Result? = null
    private val handler = Handler(Looper.getMainLooper())
    companion object { const val PERMISSION_REQUEST = 4071 }

    init { channel.setMethodCallHandler(this); events.setStreamHandler(this) }
    override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) { sink = eventSink }
    override fun onCancel(arguments: Any?) { cancel(); sink = null }

    private fun available() = Build.VERSION.SDK_INT >= 31 && SpeechRecognizer.isOnDeviceRecognitionAvailable(activity)
    private fun intent(language: String) = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
        putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        // Keep service endpointing defaults. Short forced silence thresholds can
        // cut off a person thinking, and providers are allowed to ignore them.
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "capability" -> capability(call.argument<String>("language") ?: Locale.getDefault().toLanguageTag(), result)
                "permission" -> {
                    if (activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                        result.success(true)
                    } else if (permissionResult != null) {
                        result.error("busy", "A microphone permission request is already open.", null)
                    } else {
                        permissionResult = result
                        activity.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), PERMISSION_REQUEST)
                    }
                }
                "start" -> {
                    if (!available()) { result.error("unavailable", "On-device speech is unavailable. Record audio or type instead.", null); return }
                    if (activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                        result.error("permission", "Allow microphone access or type instead.", null); return
                    }
                    val run = call.argument<Int>("run") ?: throw IllegalArgumentException("Missing session")
                    val language = call.argument<String>("language") ?: Locale.getDefault().toLanguageTag()
                    start(run, language)
                    result.success(null)
                }
                "stop" -> { if (activeRun == call.argument<Int>("run")) recognizer?.stopListening(); result.success(null) }
                "prepareLanguage" -> {
                    if (Build.VERSION.SDK_INT < 33 || !available()) { result.success(false); return }
                    val language = call.argument<String>("language") ?: Locale.getDefault().toLanguageTag()
                    val setup = SpeechRecognizer.createOnDeviceSpeechRecognizer(activity)
                    setup.triggerModelDownload(intent(language))
                    handler.postDelayed({ setup.destroy() }, 3000)
                    result.success(true)
                }
                "cancel" -> { if (activeRun == call.argument<Int>("run")) cancel(); result.success(null) }
                else -> result.notImplemented()
            }
        } catch (_: Exception) {
            result.error("speech_unavailable", "Speech could not start. Your retained words are safe; try recording audio or typing.", null)
        }
    }

    private fun capability(language: String, result: MethodChannel.Result) {
        if (!available()) { result.success(mapOf("onDevice" to false, "language" to language)); return }
        if (Build.VERSION.SDK_INT < 33) { result.success(mapOf("onDevice" to true, "language" to language)); return }
        val probe = SpeechRecognizer.createOnDeviceSpeechRecognizer(activity)
        var answered = false
        fun finish(installed: Boolean?) {
            if (answered) return
            answered = true
            probe.destroy()
            result.success(mapOf("onDevice" to true, "language" to language, "languageInstalled" to installed))
        }
        handler.postDelayed({ finish(null) }, 2500)
        try {
            probe.checkRecognitionSupport(intent(language), activity.mainExecutor, object : RecognitionSupportCallback {
                override fun onSupportResult(support: RecognitionSupport) {
                    val installed = support.installedOnDeviceLanguages.any { it.equals(language, ignoreCase = true) }
                    finish(installed)
                }
                override fun onError(error: Int) { finish(null) }
            })
        } catch (_: Exception) { finish(null) }
    }

    private fun start(run: Int, language: String) {
        cancel()
        activeRun = run
        val current = SpeechRecognizer.createOnDeviceSpeechRecognizer(activity)
        recognizer = current
        fun emit(kind: String, text: String? = null, level: Double? = null, error: String? = null) {
            if (activeRun != run) return
            sink?.success(mapOf("run" to run, "kind" to kind, "text" to text, "level" to level, "error" to error))
        }
        fun words(bundle: Bundle?) = bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()?.take(4000)
        current.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) { emit("ready") }
            override fun onBeginningOfSpeech() { emit("speaking") }
            override fun onRmsChanged(rmsdB: Float) { emit("level", level = ((rmsdB + 2) / 12.0).coerceIn(0.0, 1.0)) }
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() { emit("ending") }
            override fun onPartialResults(partialResults: Bundle?) { words(partialResults)?.let { emit("partial", text = it) } }
            override fun onResults(results: Bundle?) { emit("final", text = words(results)) }
            override fun onError(error: Int) {
                val message = when (error) {
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Microphone access was denied. You can type instead."
                    SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No clear speech was detected. Retained words are still available."
                    SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED, SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> "On-device speech is not installed for this language. Choose another language, record audio, or type."
                    else -> "On-device speech stopped. Retained words are safe; record audio or type to continue."
                }
                emit("error", error = message)
            }
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
        try { current.startListening(intent(language)) } catch (error: Exception) { cancel(); throw error }
    }

    fun permissionResponse(requestCode: Int, grants: IntArray): Boolean {
        if (requestCode != PERMISSION_REQUEST) return false
        permissionResult?.success(grants.isNotEmpty() && grants[0] == PackageManager.PERMISSION_GRANTED)
        permissionResult = null
        return true
    }
    fun interrupt() {
        activeRun?.let { sink?.success(mapOf("run" to it, "kind" to "interrupted")) }
        cancel()
    }
    private fun cancel() {
        activeRun = null
        recognizer?.cancel()
        recognizer?.destroy()
        recognizer = null
    }
    fun close() {
        interrupt()
        permissionResult?.success(false)
        permissionResult = null
        channel.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }
}
