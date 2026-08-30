package com.paveuu.respire

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

private const val CHANNEL     = "com.paveuu.respire.breathing_classifier"
private const val MODEL_FILE  = "best_model_epoch_18_new.onnx"
private const val BUFFER_SIZE = 154350          // ~3.5 s @ 44 100 Hz
private const val TAIL_FRAMES = 17

class MainActivity : FlutterActivity() {

    private var classifier: BreathClassifierWrapper? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        try {
            classifier = BreathClassifierWrapper(applicationContext)
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to initialize classifier: ${e.message}")
        }

        MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "classifyAudio" -> {
                    val bytes = call.argument<ByteArray>("audioData")
                    val threshold = call.argument<Double>("threshold")?.toFloat() ?: 0.6f
                    if (bytes == null) {
                        result.error("INVALID_ARGS", "audioData is null", null)
                        return@setMethodCallHandler
                    }
                    val currentClassifier = classifier
                    if (currentClassifier == null) {
                        result.error("CLASSIFIER_NOT_READY", "Model failed to initialize", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val classIndex = currentClassifier.classify(bytes, threshold)
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
        classifier?.close()
    }
}

// ─── Wrapper ─────────────────────────────────────────────────────────────────

/**
 * Loads the ONNX model once and exposes [classify].
 *
 * Model contract (matches export_onnx.py):
 *   input  "audio_input" : Float32[154350]       — 1-D, no batch dimension
 *   output "logits"      : Float32[1, T, 2]      — frame-level logits
 *
 * Classes: 0 = Exhale, 1 = Everything else
 */
class BreathClassifierWrapper(private val context: Context) {

    private val env: OrtEnvironment = OrtEnvironment.getEnvironment()
    private val session: OrtSession

    private val sessionOptions = OrtSession.SessionOptions().apply {
        addConfigEntry("session.execution_provider", "qnn")  // Mobile NPU support
    }

    init {
        val modelPath = copyAssetToCache(MODEL_FILE)
        try {
            copyAssetToCache("$MODEL_FILE.data")
        } catch (e: Exception) {
            Log.i("BreathClassifier", "No .data file found for model, proceeding without it.")
        }
        session = env.createSession(modelPath, sessionOptions)
    }

    /**
     * @param audioBytes Raw little-endian Int16 PCM, exactly BUFFER_SIZE samples.
     * @param threshold Probability threshold for exhale detection.
     * @return Class index: 0 = Everything else, 1 = Exhale
     */
    fun classify(audioBytes: ByteArray, threshold: Float): Int {
        try {
            // 1. PCM Int16 → Float32 in [-1, 1]
            val shortBuf = ByteBuffer
                .wrap(audioBytes)
                .order(ByteOrder.LITTLE_ENDIAN)
                .asShortBuffer()
            
            var maxAmp = 0f
            val floatData = FloatArray(shortBuf.remaining()) {
                val s = shortBuf.get() / 32768f
                val absS = if (s < 0) -s else s
                if (absS > maxAmp) maxAmp = absS
                s
            }

            // 2. Build input tensor — shape [1, 154350] as expected by the model
            val inputTensor = OnnxTensor.createTensor(
                env,
                FloatBuffer.wrap(floatData),
                longArrayOf(1, floatData.size.toLong())
            )

            // 3. Run inference & ensure resources are closed
            inputTensor.use { tensor ->
                val outputs = session.run(mapOf("audio_input" to tensor))
                outputs.use { result ->
                    // 4. Extract logits
                    val outputValue = result.get("logits")
                    if (!outputValue.isPresent) {
                        Log.e("BreathClassifier", "Output 'logits' not found")
                        return 0
                    }

                    val logitsTensor = outputValue.get() as OnnxTensor
                    val logitsBuf    = logitsTensor.floatBuffer
                    val allLogits    = FloatArray(logitsBuf.remaining()).also { logitsBuf.get(it) }

                    val numClasses = 2
                    val numFrames  = allLogits.size / numClasses
                    if (numFrames == 0) return 0

                    // 6. Average softmax over the last TAIL_FRAMES frames
                    val startFrame = maxOf(0, numFrames - TAIL_FRAMES)
                    val processedFrames = numFrames - startFrame
                    val avgProb    = FloatArray(numClasses)

                    for (f in startFrame until numFrames) {
                        val offset = f * numClasses
                        val l0 = allLogits[offset]
                        val l1 = allLogits[offset + 1]

                        val maxL  = if (l0 > l1) l0 else l1
                        val exp0  = Math.exp((l0 - maxL).toDouble()).toFloat()
                        val exp1  = Math.exp((l1 - maxL).toDouble()).toFloat()
                        val sum   = exp0 + exp1

                        if (sum > 0) {
                            avgProb[0] += exp0 / sum
                            avgProb[1] += exp1 / sum
                        }
                    }

                    if (processedFrames > 0) {
                        avgProb[0] /= processedFrames
                        avgProb[1] /= processedFrames
                    }

                    Log.d("BreathClassifier", "MaxAmp: ${String.format("%.4f", maxAmp)}, Prob: Exhale=${String.format("%.3f", avgProb[0])}, Other=${String.format("%.3f", avgProb[1])}")

                    return if (avgProb[0] > threshold) 0 else 1
                }
            }
        } catch (e: Exception) {
            Log.e("BreathClassifier", "Error during classification: ${e.message}")
            throw e
        }
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
