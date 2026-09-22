package com.paveuu.respire

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

private const val CHANNEL =
    "com.paveuu.respire.breathing_classifier"

private const val AUDIO_CHANNEL =
    "com.paveuu.respire.audio"

private const val MODEL_FILE =
    "best_model_epoch_18_new.onnx"

private const val BUFFER_SIZE =
    154350

private const val TAIL_FRAMES =
    17

class MainActivity : FlutterActivity() {

    private var classifier: BreathClassifierWrapper? = null

    private lateinit var audioManager: AudioManager

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        audioManager =
            getSystemService(Context.AUDIO_SERVICE) as AudioManager

        try {
            classifier =
                BreathClassifierWrapper(applicationContext)
        } catch (e: Exception) {
            Log.e(
                "MainActivity",
                "Failed to initialize classifier: ${e.message}",
                e
            )
        }

        setupBreathingClassifierChannel(flutterEngine)
        setupAudioChannel(flutterEngine)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ONNX classifier channel
    // ─────────────────────────────────────────────────────────────────────────

    private fun setupBreathingClassifierChannel(
        flutterEngine: FlutterEngine
    ) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "classifyAudio" -> {
                    val bytes =
                        call.argument<ByteArray>("audioData")

                    val threshold =
                        call.argument<Double>("threshold")
                            ?.toFloat()
                            ?: 0.6f

                    if (bytes == null) {
                        result.error(
                            "INVALID_ARGS",
                            "audioData is null",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    val currentClassifier =
                        classifier

                    if (currentClassifier == null) {
                        result.error(
                            "CLASSIFIER_NOT_READY",
                            "Model failed to initialize",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        val classIndex =
                            currentClassifier.classify(
                                bytes,
                                threshold
                            )

                        result.success(classIndex)

                    } catch (e: Exception) {
                        result.error(
                            "CLASSIFICATION_ERROR",
                            e.message,
                            null
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Audio device channel
    // ─────────────────────────────────────────────────────────────────────────

    private fun setupAudioChannel(
        flutterEngine: FlutterEngine
    ) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AUDIO_CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "getPreferredInputDevice" -> {
                    try {
                        val device =
                            getPreferredInputDevice()

                        if (device == null) {
                            result.success(null)
                        } else {
                            result.success(
                                deviceToMap(device)
                            )
                        }

                    } catch (e: Exception) {
                        Log.e(
                            "AudioDevice",
                            "Failed to get preferred input device",
                            e
                        )

                        result.error(
                            "AUDIO_DEVICE_ERROR",
                            e.message,
                            null
                        )
                    }
                }

                "getInputDevices" -> {
                    try {
                        result.success(
                            getInputDevices()
                                .map(::deviceToMap)
                        )
                    } catch (e: Exception) {
                        Log.e(
                            "AudioDevice",
                            "Failed to enumerate input devices",
                            e
                        )

                        result.error(
                            "AUDIO_DEVICE_ERROR",
                            e.message,
                            null
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    /**
     * Returns currently connected audio input devices.
     *
     * AudioManager.GET_DEVICES_INPUTS ensures that we only inspect
     * devices that Android exposes as capture/input devices.
     */
    private fun getInputDevices(): List<AudioDeviceInfo> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return emptyList()
        }

        return audioManager.getDevices(
            AudioManager.GET_DEVICES_INPUTS
        ).toList()
    }

    /**
     * Select the preferred microphone.
     *
     * Priority:
     *
     * 1. USB microphone
     * 2. USB headset
     * 3. Wired headset (3.5 mm)
     * 4. Bluetooth SCO headset
     * 5. Analog line input
     * 6. USB accessory
     * 7. Built-in microphone
     * 8. Any remaining input device
     */
    private fun getPreferredInputDevice():
            AudioDeviceInfo? {

        val devices = getInputDevices()

        if (devices.isEmpty()) {
            Log.w(
                "AudioDevice",
                "Android reports no input devices"
            )
            return null
        }

        for (device in devices) {
            Log.d(
                "AudioDevice",
                "Input device: " +
                        "id=${device.id}, " +
                        "type=${device.type}, " +
                        "name=${device.productName}, " +
                        "address=${device.address}"
            )
        }

        val priority = listOf(
            AudioDeviceInfo.TYPE_USB_DEVICE,

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                AudioDeviceInfo.TYPE_USB_HEADSET
            else
                -1,

            AudioDeviceInfo.TYPE_WIRED_HEADSET,

            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                AudioDeviceInfo.TYPE_LINE_ANALOG
            else
                -1,

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                AudioDeviceInfo.TYPE_USB_ACCESSORY
            else
                -1,

            AudioDeviceInfo.TYPE_BUILTIN_MIC
        )

        for (type in priority) {
            if (type == -1) {
                continue
            }

            val device =
                devices.firstOrNull {
                    it.type == type
                }

            if (device != null) {
                Log.i(
                    "AudioDevice",
                    "Selected input device: " +
                            "id=${device.id}, " +
                            "type=${device.type}, " +
                            "name=${device.productName}"
                )

                return device
            }
        }

        // Last-resort fallback.
        val fallback = devices.first()

        Log.i(
            "AudioDevice",
            "Using first available input device: " +
                    "id=${fallback.id}, " +
                    "type=${fallback.type}, " +
                    "name=${fallback.productName}"
        )

        return fallback
    }

    private fun deviceToMap(
        device: AudioDeviceInfo
    ): Map<String, Any?> {

        val category =
            getDeviceCategory(device)

        return mapOf(
            "id" to device.id.toString(),

            "label" to (
                    device.productName?.toString()
                        ?: category
                    ),

            "type" to category,

            "androidType" to device.type,

            "address" to device.address,

            "isExternal" to (
                    category != "builtin"
                    )
        )
    }

    private fun getDeviceCategory(
        device: AudioDeviceInfo
    ): String {

        return when (device.type) {

            AudioDeviceInfo.TYPE_USB_DEVICE ->
                "usb"

            AudioDeviceInfo.TYPE_USB_HEADSET ->
                "usb"

            AudioDeviceInfo.TYPE_WIRED_HEADSET ->
                "wired"

            AudioDeviceInfo.TYPE_BLUETOOTH_SCO ->
                "bluetooth"

            AudioDeviceInfo.TYPE_LINE_ANALOG ->
                "analog"

            AudioDeviceInfo.TYPE_USB_ACCESSORY ->
                "usb"

            AudioDeviceInfo.TYPE_BUILTIN_MIC ->
                "builtin"

            else ->
                "other"
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Lifecycle
    // ─────────────────────────────────────────────────────────────────────────

    override fun onDestroy() {
        super.onDestroy()

        classifier?.close()
        classifier = null
    }
}

// ─── Wrapper ─────────────────────────────────────────────────────────────────

/**
 * Loads the ONNX model once and exposes [classify].
 *
 * Model contract (matches export_onnx.py):
 *   input  "audio_input" : Float32[154350]
 *   output "logits"      : Float32[1, T, 2]
 *
 * Classes:
 *   0 = Exhale
 *   1 = Everything else
 */
class BreathClassifierWrapper(
    private val context: Context
) {

    private val env: OrtEnvironment =
        OrtEnvironment.getEnvironment()

    private val session: OrtSession

    private val sessionOptions =
        OrtSession.SessionOptions().apply {
            addConfigEntry(
                "session.execution_provider",
                "qnn"
            )
        }

    init {
        val modelPath =
            copyAssetToCache(MODEL_FILE)

        try {
            copyAssetToCache("$MODEL_FILE.data")
        } catch (e: Exception) {
            Log.i(
                "BreathClassifier",
                "No .data file found for model, " +
                        "proceeding without it."
            )
        }

        session =
            env.createSession(
                modelPath,
                sessionOptions
            )
    }

    /**
     * @param audioBytes Raw little-endian Int16 PCM,
     * exactly BUFFER_SIZE samples.
     *
     * @param threshold Probability threshold for
     * exhale detection.
     *
     * @return Class index:
     * 0 = Exhale
     * 1 = Everything else
     */
    fun classify(
        audioBytes: ByteArray,
        threshold: Float
    ): Int {

        try {

            // 1. PCM Int16 → Float32 in [-1, 1]
            val shortBuf =
                ByteBuffer
                    .wrap(audioBytes)
                    .order(ByteOrder.LITTLE_ENDIAN)
                    .asShortBuffer()

            var maxAmp = 0f

            val floatData =
                FloatArray(shortBuf.remaining()) {

                    val s =
                        shortBuf.get() / 32768f

                    val absS =
                        if (s < 0) -s else s

                    if (absS > maxAmp) {
                        maxAmp = absS
                    }

                    s
                }

            // 2. Build input tensor
            // shape [1, 154350]
            val inputTensor =
                OnnxTensor.createTensor(
                    env,
                    FloatBuffer.wrap(floatData),
                    longArrayOf(
                        1,
                        floatData.size.toLong()
                    )
                )

            // 3. Run inference
            inputTensor.use { tensor ->

                val outputs =
                    session.run(
                        mapOf(
                            "audio_input" to tensor
                        )
                    )

                outputs.use { result ->

                    // 4. Extract logits
                    val outputValue =
                        result.get("logits")

                    if (!outputValue.isPresent) {

                        Log.e(
                            "BreathClassifier",
                            "Output 'logits' not found"
                        )

                        return 0
                    }

                    val logitsTensor =
                        outputValue.get() as OnnxTensor

                    val logitsBuf =
                        logitsTensor.floatBuffer

                    val allLogits =
                        FloatArray(
                            logitsBuf.remaining()
                        ).also {
                            logitsBuf.get(it)
                        }

                    val numClasses = 2

                    val numFrames =
                        allLogits.size / numClasses

                    if (numFrames == 0) {
                        return 0
                    }

                    // 5. Average softmax over
                    // the last TAIL_FRAMES frames.
                    val startFrame =
                        maxOf(
                            0,
                            numFrames - TAIL_FRAMES
                        )

                    val processedFrames =
                        numFrames - startFrame

                    val avgProb =
                        FloatArray(numClasses)

                    for (
                    f in startFrame until numFrames
                    ) {

                        val offset =
                            f * numClasses

                        val l0 =
                            allLogits[offset]

                        val l1 =
                            allLogits[offset + 1]

                        val maxL =
                            if (l0 > l1) l0 else l1

                        val exp0 =
                            Math.exp(
                                (l0 - maxL).toDouble()
                            ).toFloat()

                        val exp1 =
                            Math.exp(
                                (l1 - maxL).toDouble()
                            ).toFloat()

                        val sum =
                            exp0 + exp1

                        if (sum > 0) {

                            avgProb[0] +=
                                exp0 / sum

                            avgProb[1] +=
                                exp1 / sum
                        }
                    }

                    if (processedFrames > 0) {

                        avgProb[0] /=
                            processedFrames

                        avgProb[1] /=
                            processedFrames
                    }

                    Log.d(
                        "BreathClassifier",
                        "MaxAmp: ${
                            String.format(
                                "%.4f",
                                maxAmp
                            )
                        }, " +
                                "Prob: Exhale=${
                                    String.format(
                                        "%.3f",
                                        avgProb[0]
                                    )
                                }, " +
                                "Other=${
                                    String.format(
                                        "%.3f",
                                        avgProb[1]
                                    )
                                }"
                    )

                    return if (
                        avgProb[0] > threshold
                    ) {
                        0
                    } else {
                        1
                    }
                }
            }

        } catch (e: Exception) {

            Log.e(
                "BreathClassifier",
                "Error during classification: ${e.message}",
                e
            )

            throw e
        }
    }

    fun close() {
        session.close()
        env.close()
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    /**
     * Copies a file from assets/ to the app cache so
     * ONNX Runtime can open it by path.
     */
    private fun copyAssetToCache(
        filename: String
    ): String {

        val dest =
            File(
                context.cacheDir,
                filename
            )

        if (!dest.exists()) {

            context.assets
                .open(filename)
                .use { input ->

                    FileOutputStream(dest)
                        .use { output ->

                            input.copyTo(output)
                        }
                }
        }

        return dest.absolutePath
    }
}