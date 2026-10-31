package com.example.taskflow.speechprobe;

import android.app.Activity;
import android.content.Intent;
import android.media.AudioFormat;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.ParcelFileDescriptor;
import android.os.SystemClock;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;
import android.widget.TextView;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;

/** Standalone diagnostic APK. Never links to TaskFlow or opens its database. */
public final class ProbeActivity extends Activity {
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final JSONArray results = new JSONArray();
    private JSONArray cases;
    private TextView status;
    private int index;
    private SpeechRecognizer recognizer;
    private ParcelFileDescriptor source;
    private Thread writer;
    private boolean finished;
    private long started, firstPartial, ready;
    private JSONArray partials, segments;
    private int generation;
    private boolean segmented;
    private JSONObject finalBundle;
    private Runnable timeout;

    @Override public void onCreate(Bundle saved) {
        super.onCreate(saved);
        status = new TextView(this);
        status.setTextSize(22);
        status.setPadding(32, 72, 32, 32);
        setContentView(status);
        segmented = getIntent().getBooleanExtra("segmented", false);
        try (InputStream input = getAssets().open("cases.json")) {
            cases = new JSONArray(new String(input.readAllBytes(), StandardCharsets.UTF_8));
            if (!SpeechRecognizer.isOnDeviceRecognitionAvailable(this)) {
                throw new IllegalStateException("No on-device service");
            }
            next();
        } catch (Exception error) { fatal(error); }
    }

    private void next() {
        if (index == cases.length()) {
            save(true);
            status.setText("Speech probe complete: " + results.length() + " cases.\nSee files/results.json.");
            return;
        }
        try {
            JSONObject item = cases.getJSONObject(index);
            status.setText("Synthetic speech: " + item.getString("id") + "\n" + (index + 1) + "/" + cases.length());
            finished = false;
            firstPartial = -1;
            ready = -1;
            partials = new JSONArray();
            segments = new JSONArray();
            finalBundle = new JSONObject();
            final int run = ++generation;
            ParcelFileDescriptor[] pipe = ParcelFileDescriptor.createPipe();
            source = pipe[0];
            final ParcelFileDescriptor sink = pipe[1];
            final String asset = item.getString("id") + ".pcm";
            recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(this);
            recognizer.setRecognitionListener(new RecognitionListener() {
                @Override public void onReadyForSpeech(Bundle params) {
                    if (generation == run && !finished) ready = SystemClock.elapsedRealtime() - started;
                }
                @Override public void onBeginningOfSpeech() {}
                @Override public void onRmsChanged(float level) {}
                @Override public void onBufferReceived(byte[] bytes) {}
                @Override public void onEndOfSpeech() {}
                @Override public void onEvent(int type, Bundle params) {}
                @Override public void onPartialResults(Bundle bundle) {
                    String text = words(bundle);
                    if (generation != run || finished || text.isEmpty()) return;
                    if (firstPartial < 0) firstPartial = SystemClock.elapsedRealtime() - started;
                    if (partials.length() == 0 || !text.equals(partials.optString(partials.length() - 1))) {
                        partials.put(text);
                    }
                }
                @Override public void onSegmentResults(Bundle bundle) {
                    if (generation != run || finished) return;
                    String text = words(bundle);
                    if (!text.isEmpty()) segments.put(text);
                }
                @Override public void onEndOfSegmentedSession() {
                    if (generation == run) finishCase("", null);
                }
                @Override public void onResults(Bundle bundle) {
                    if (generation == run && !finished) {
                        finalBundle = describe(bundle);
                        finishCase(words(bundle), null);
                    }
                }
                @Override public void onError(int error) {
                    if (generation == run) finishCase("", "android_error_" + error);
                }
            });
            Intent intent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                    .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    .putExtra(RecognizerIntent.EXTRA_LANGUAGE, item.getString("language"))
                    .putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    .putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                    .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, source)
                    .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
                    .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
                    .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, 16000);
            // The default request uses TaskFlow's endpointing and no bias words.
            // Explicit segmentation is a separate diagnostic mode for file input.
            if (segmented) intent.putExtra(RecognizerIntent.EXTRA_SEGMENTED_SESSION, RecognizerIntent.EXTRA_AUDIO_SOURCE);
            started = SystemClock.elapsedRealtime();
            timeout = () -> finishCase("", "probe_timeout_25s");
            handler.postDelayed(timeout, 25000);
            recognizer.startListening(intent);
            writer = new Thread(() -> {
                try (InputStream audio = getAssets().open(asset);
                     OutputStream output = new ParcelFileDescriptor.AutoCloseOutputStream(sink)) {
                    byte[] chunk = new byte[640]; // 20 ms, PCM16 / mono / 16 kHz.
                    long sent = 0;
                    int count;
                    while (!Thread.currentThread().isInterrupted() && (count = audio.read(chunk)) != -1) {
                        output.write(chunk, 0, count);
                        sent += count;
                        long wait = started + sent * 1000 / 32000 - SystemClock.elapsedRealtime();
                        if (wait > 0) Thread.sleep(wait);
                    }
                } catch (java.io.IOException | InterruptedException expectedAtEndpoint) {
                    // An endpoint closes the pipe even when a paused fixture has audio left.
                }
            }, "synthetic-audio-source");
            writer.start();
        } catch (Exception error) { finishCase("", error.getClass().getSimpleName()); }
    }

    private static String words(Bundle bundle) {
        ArrayList<String> values = bundle == null ? null : bundle.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
        return values == null || values.isEmpty() ? "" : values.get(0);
    }

    private static JSONObject describe(Bundle bundle) {
        JSONObject description = new JSONObject();
        if (bundle == null) return description;
        for (String key : bundle.keySet()) {
            try {
                Object value = bundle.get(key);
                description.put(key, value == null ? JSONObject.NULL : String.valueOf(value));
            } catch (Exception ignored) {}
        }
        return description;
    }

    private void finishCase(String transcript, String error) {
        if (finished) return;
        finished = true;
        try {
            JSONObject result = new JSONObject(cases.getJSONObject(index).toString());
            result.put("transcript", transcript);
            result.put("segments", segments);
            result.put("final_bundle", finalBundle);
            result.put("ready_ms", ready < 0 ? JSONObject.NULL : ready);
            result.put("partials", partials);
            result.put("first_partial_ms", firstPartial < 0 ? JSONObject.NULL : firstPartial);
            result.put("elapsed_ms", SystemClock.elapsedRealtime() - started);
            result.put("error", error == null ? JSONObject.NULL : error);
            results.put(result);
            save(false);
        } catch (Exception failure) { fatal(failure); return; }
        release();
        index++;
        handler.postDelayed(this::next, 1000);
    }

    private void save(boolean complete) {
        try {
            JSONObject report = new JSONObject();
            report.put("complete", complete);
            report.put("source", "synthetic_pcm_file_via_android_extra_audio_source");
            report.put("on_device_only", true);
            report.put("explicit_segmented_input", segmented);
            report.put("sdk", android.os.Build.VERSION.SDK_INT);
            report.put("results", results);
            Files.write(new java.io.File(getFilesDir(), "results.json").toPath(), report.toString(2).getBytes(StandardCharsets.UTF_8));
        } catch (Exception failure) { status.setText("Cannot save report: " + failure.getClass().getSimpleName()); }
    }

    private void fatal(Exception error) {
        release();
        status.setText("Speech probe failed: " + error.getClass().getSimpleName() + ": " + error.getMessage());
    }

    private void release() {
        if (timeout != null) handler.removeCallbacks(timeout);
        if (writer != null) { writer.interrupt(); writer = null; }
        if (recognizer != null) { recognizer.cancel(); recognizer.destroy(); recognizer = null; }
        if (source != null) { try { source.close(); } catch (Exception ignored) {} source = null; }
    }

    @Override public void onDestroy() { handler.removeCallbacksAndMessages(null); release(); super.onDestroy(); }
}
