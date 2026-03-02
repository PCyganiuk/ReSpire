package com.paveuu.respire

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

// ─── Constants (must match training config) ──────────────────────────────────

private const val CHANNEL     = "com.paveuu.respire.breathing_classifier"
private const val MODEL_FILE  = "best_model_epoch_31.onnx"
private const val BUFFER_SIZE = 154350          // ~3.5 s @ 44 100 Hz
private const val TAIL_FRAMES = 17              // ~200 ms of frames to average

// ─── MainActivity ────────────────────────────────────────────────────────────

class MainActivity : FlutterActivity() {

    private lateinit var classifier: BreathClassifierWrapper

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        classifier = BreathClassifierWrapper(applicationContext)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "classifyAudio" -> {
                    val bytes = call.argument<ByteArray>("audioData")
                    if (bytes == null) {
                        result.error("INVALID_ARGS", "audioData is null", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val classIndex = classifier.classify(bytes)
                        result.success(classIndex)
                    } catch (e: Exception) {
                        result.error("CLASSIFICATION_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        classifier.close()
    }
}

// ─── Wrapper ─────────────────────────────────────────────────────────────────

/**
 * Loads the ONNX model once and exposes [classify].
 *
 * Model contract (matches export_onnx.py):
 *   input  "audio_input" : Float32[154350]       — 1-D, no batch dimension
 *   output "logits"      : Float32[1, T, 3]      — frame-level logits
 *
 * Classes: 0 = Exhale, 1 = Inhale, 2 = Silence
 */
class BreathClassifierWrapper(private val context: Context) {

    private val env: OrtEnvironment = OrtEnvironment.getEnvironment()
    private val session: OrtSession

    init {
        val modelPath = copyAssetToCache(MODEL_FILE)
        copyAssetToCache("$MODEL_FILE.data")
        session = env.createSession(modelPath, OrtSession.SessionOptions())
    }

    /**
     * @param audioBytes Raw little-endian Int16 PCM, exactly BUFFER_SIZE samples.
     * @return Class index: 0 = Exhale, 1 = Inhale, 2 = Silence
     */
    fun classify(audioBytes: ByteArray): Int {
        // 1. PCM Int16 → Float32 in [-1, 1]
        val shortBuf = ByteBuffer
            .wrap(audioBytes)
            .order(ByteOrder.LITTLE_ENDIAN)
            .asShortBuffer()
        val floatData = FloatArray(shortBuf.remaining()) { shortBuf.get() / 32768f }

        // 2. Build input tensor — shape [154350], no batch dim (matches export script)
        val inputTensor = OnnxTensor.createTensor(
            env,
            FloatBuffer.wrap(floatData),
            longArrayOf(floatData.size.toLong())
        )

        // 3. Run inference
        val outputs = session.run(mapOf("audio_input" to inputTensor))

        // 4. Extract logits — output name is "logits" (set in export_onnx.py)
        val logitsBuf = (outputs["logits"].get() as OnnxTensor).floatBuffer
        val allLogits = FloatArray(logitsBuf.remaining()).also { logitsBuf.get(it) }

        // 5. Shape is [1, T, 3] — flatten to [T * 3]
        val numClasses = 3
        val numFrames  = allLogits.size / numClasses

        // 6. Average softmax over the last TAIL_FRAMES frames for stable prediction
        val startFrame = maxOf(0, numFrames - TAIL_FRAMES)
        val avgProb    = FloatArray(numClasses)

        for (f in startFrame until numFrames) {
            val offset    = f * numClasses
            val expValues = FloatArray(numClasses) { Math.exp(allLogits[offset + it].toDouble()).toFloat() }
            val sum       = expValues.sum()
            for (c in 0 until numClasses) {
                avgProb[c] += expValues[c] / sum
            }
        }

        // 7. Return argmax
        return avgProb.indices.maxByOrNull { avgProb[it] } ?: 2
    }

    fun close() {
        session.close()
        env.close()
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    /** Copies a file from assets/ to the app cache so ONNX Runtime can open it by path. */
    private fun copyAssetToCache(filename: String): String {
        val dest = File(context.cacheDir, filename)
        if (!dest.exists()) {
            context.assets.open(filename).use { input ->
                FileOutputStream(dest).use { output -> input.copyTo(output) }
            }
        }
        return dest.absolutePath
    }
}