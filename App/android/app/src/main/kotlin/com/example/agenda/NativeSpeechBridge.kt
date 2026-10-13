package com.example.agenda

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.os.SystemClock
import android.speech.RecognitionListener
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.Locale

/**
 * One foreground listening session. It ends only when the user stops, cancels
 * or leaves the app; a pause in speech never ends it. Never silently uses a
 * network recognition service.
 *
 * Android 13+: TaskFlow records the microphone itself and feeds the on-device
 * recognizer through a pipe in a segmented session, so each pause commits a
 * `segment` and listening goes on. Stopping closes the pipe; the recognizer
 * flushes the last segment and ends the session.
 * Android 12, or a recognizer that ends a session by itself: a new session
 * starts at once and its words keep appending.
 *
 * Events to Dart: ready, partial, segment, level, ended (only after stop or an
 * interruption) and error (only what can't recover).
 */
class NativeSpeechBridge(private val activity: Activity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val channel = MethodChannel(messenger, "taskflow/speech")
    private val events = EventChannel(messenger, "taskflow/speech/events")
    private var sink: EventChannel.EventSink? = null
    private var activeRun: Int? = null
    private var language = ""
    // Words this person is likely to say: dates, times, their projects and people.
    private var hints = ArrayList<String>()
    private var stopRequested = false
    private var attempt: Attempt? = null
    // Consecutive attempts that ended at once without hearing anything. A
    // recognizer that keeps doing that is broken, not waiting for speech.
    private var quickEnds = 0
    private var permissionResult: MethodChannel.Result? = null
    private val handler = Handler(Looper.getMainLooper())
    companion object {
        const val PERMISSION_REQUEST = 4071
        const val SAMPLE_RATE = 16000
        const val MAX_QUICK_ENDS = 3
        const val STOPPED = "On-device speech stopped. Retained words are safe; record audio or type to continue."
    }

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
                        result.success("granted")
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
                    start(run, language, ArrayList(call.argument<List<String>>("hints") ?: emptyList()))
                    result.success(null)
                }
                "stop" -> { if (activeRun == call.argument<Int>("run")) stop(); result.success(null) }
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

    private fun emit(run: Int, kind: String, text: String? = null, level: Double? = null, error: String? = null) {
        if (activeRun != run) return
        sink?.success(mapOf("run" to run, "kind" to kind, "text" to text, "level" to level, "error" to error))
    }

    private fun start(run: Int, language: String, hints: ArrayList<String>) {
        cancel()
        activeRun = run
        this.language = language
        this.hints = hints
        try { begin(run) } catch (error: Exception) { cancel(); throw error }
    }

    /** Opens one recognizer session within the run. A run may need several. */
    private fun begin(run: Int) {
        val next = Attempt(run)
        attempt = next
        next.begin()
    }

    /** The user is done: let the recognizer finish the words it has heard. */
    private fun stop() {
        val run = activeRun ?: return
        stopRequested = true
        val current = attempt
        if (current == null || current.over) end(run, "ended") else current.finishAudio()
    }

    /** A session ended. Unless the user stopped, listening goes on in a new one. */
    private fun attemptOver(over: Attempt) {
        val run = over.run
        if (activeRun != run || attempt !== over) return
        if (stopRequested) { end(run, "ended"); return }
        val quick = !over.ready || (!over.heard && SystemClock.elapsedRealtime() - over.began < 1000)
        quickEnds = if (quick) quickEnds + 1 else 0
        if (quickEnds > MAX_QUICK_ENDS) { end(run, "error", STOPPED); return }
        handler.post {
            if (activeRun != run || attempt !== over) return@post
            over.release()
            if (stopRequested) { end(run, "ended"); return@post }
            try { begin(run) } catch (_: Exception) { end(run, "error", STOPPED) }
        }
    }

    /** Ends the run with its last event; nothing from it reaches Dart afterwards. */
    private fun end(run: Int, kind: String, error: String? = null) {
        if (activeRun != run) return
        emit(run, kind, error = error)
        val finished = attempt
        activeRun = null
        attempt = null
        stopRequested = false
        quickEnds = 0
        // Not from inside the recognizer's own callback.
        handler.post { finished?.release() }
    }

    private inner class Attempt(val run: Int) : RecognitionListener {
        private val recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(activity)
        private var feed: MicrophoneFeed? = null
        val began = SystemClock.elapsedRealtime()
        var ready = false
        var heard = false
        var over = false
        private var released = false

        fun begin() {
            recognizer.setRecognitionListener(this)
            val request = intent(language)
            if (Build.VERSION.SDK_INT >= 33) {
                // How much this helps depends on the recognizer.
                if (hints.isNotEmpty()) request.putExtra(RecognizerIntent.EXTRA_BIASING_STRINGS, hints)
                feed = MicrophoneFeed.open()?.also {
                    request.putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, it.source)
                    request.putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
                    request.putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
                    request.putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, SAMPLE_RATE)
                    request.putExtra(RecognizerIntent.EXTRA_SEGMENTED_SESSION, RecognizerIntent.EXTRA_AUDIO_SOURCE)
                }
            }
            try { recognizer.startListening(request) } catch (error: Exception) { release(); throw error }
        }

        /** With our own audio, ending it is the stop; otherwise ask the recognizer. */
        fun finishAudio() {
            val audio = feed
            if (audio != null) audio.finish() else recognizer.stopListening()
        }

        fun release() {
            over = true
            if (released) return
            released = true
            feed?.close()
            feed = null
            try { recognizer.cancel() } catch (_: Exception) {}
            recognizer.destroy()
        }

        private fun current() = !over && attempt === this && activeRun == run
        private fun words(bundle: Bundle?) =
            bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()?.take(4000)?.takeIf { it.isNotBlank() }
        private fun finished() {
            if (!current()) return
            over = true
            attemptOver(this)
        }

        override fun onReadyForSpeech(params: Bundle?) { if (current()) { ready = true; emit(run, "ready") } }
        override fun onBeginningOfSpeech() {}
        override fun onRmsChanged(rmsdB: Float) { if (current()) emit(run, "level", level = ((rmsdB + 2) / 12.0).coerceIn(0.0, 1.0)) }
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEndOfSpeech() {}
        override fun onPartialResults(partialResults: Bundle?) {
            if (!current()) return
            words(partialResults)?.let { heard = true; emit(run, "partial", text = it) }
        }
        override fun onSegmentResults(segmentResults: Bundle) {
            if (!current()) return
            words(segmentResults)?.let { heard = true; emit(run, "segment", text = it) }
        }
        override fun onEndOfSegmentedSession() { finished() }
        override fun onResults(results: Bundle?) {
            if (!current()) return
            words(results)?.let { heard = true; emit(run, "segment", text = it) }
            finished()
        }
        override fun onError(error: Int) {
            if (!current()) return
            when (error) {
                SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS ->
                    end(run, "error", "Microphone access was denied. You can type instead.")
                SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED, SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE ->
                    end(run, "error", "On-device speech is not installed for this language. Choose another language, record audio, or type.")
                // ERROR_SPEECH_TIMEOUT and ERROR_NO_MATCH mean "keep waiting";
                // other errors get a new session too, bounded by quickEnds.
                else -> finished()
            }
        }
        override fun onEvent(eventType: Int, params: Bundle?) {}
    }

    /** Streams the microphone as 16 kHz mono PCM 16-bit into a pipe the recognizer reads. */
    private class MicrophoneFeed private constructor(
        private val record: AudioRecord,
        val source: ParcelFileDescriptor,
        private val sink: ParcelFileDescriptor,
    ) {
        @Volatile private var running = true
        private val writer = Thread {
            try {
                ParcelFileDescriptor.AutoCloseOutputStream(sink).use { output ->
                    val chunk = ByteArray(640) // 20 ms of PCM16, mono, 16 kHz.
                    while (running) {
                        val count = record.read(chunk, 0, chunk.size)
                        if (count < 0) break
                        if (count > 0) output.write(chunk, 0, count)
                    }
                }
            } catch (_: IOException) {
                // The recognizer closed its end; there is nobody left to feed.
            } finally {
                try { record.stop() } catch (_: IllegalStateException) {}
                record.release()
            }
        }.apply { name = "TaskFlowSpeechFeed"; isDaemon = true }

        /** Closes the write end once the audio so far is written: the recognizer reaches the end. */
        fun finish() { running = false }

        /** Drops the audio and our read end at once. */
        fun close() {
            running = false
            try { source.close() } catch (_: IOException) {}
        }

        companion object {
            @SuppressLint("MissingPermission") // Checked before every run.
            fun open(): MicrophoneFeed? {
                val minimum = AudioRecord.getMinBufferSize(SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
                if (minimum <= 0) return null
                val record = try {
                    AudioRecord(MediaRecorder.AudioSource.VOICE_RECOGNITION, SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO,
                        AudioFormat.ENCODING_PCM_16BIT, maxOf(minimum, 3200) * 2)
                } catch (_: Exception) { return null }
                if (record.state != AudioRecord.STATE_INITIALIZED) { record.release(); return null }
                val pipe = try { ParcelFileDescriptor.createPipe() } catch (_: IOException) { record.release(); return null }
                try {
                    record.startRecording()
                } catch (_: IllegalStateException) {
                    record.release()
                    pipe.forEach { try { it.close() } catch (_: IOException) {} }
                    return null
                }
                // Words said before the recognizer is ready wait in the pipe.
                return MicrophoneFeed(record, pipe[0], pipe[1]).also { it.writer.start() }
            }
        }
    }

    fun permissionResponse(requestCode: Int, grants: IntArray): Boolean {
        if (requestCode != PERMISSION_REQUEST) return false
        val answer = when {
            grants.isEmpty() -> "denied" // Dismissed without an answer.
            grants[0] == PackageManager.PERMISSION_GRANTED -> "granted"
            // Android won't ask again: only Settings can turn the microphone on.
            !activity.shouldShowRequestPermissionRationale(Manifest.permission.RECORD_AUDIO) -> "blocked"
            else -> "denied"
        }
        permissionResult?.success(answer)
        permissionResult = null
        return true
    }
    fun interrupt() {
        activeRun?.let { end(it, "ended") }
        cancel()
    }
    private fun cancel() {
        activeRun = null
        stopRequested = false
        quickEnds = 0
        attempt?.release()
        attempt = null
    }
    fun close() {
        interrupt()
        permissionResult?.success("denied")
        permissionResult = null
        channel.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }
}
