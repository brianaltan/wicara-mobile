package com.example.wicara_mobile.edge

import android.content.Context
import android.os.SystemClock
import android.util.Log
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.SamplerConfig
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.time.Instant
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.Future

class LiteRtLmBridge(
    private val context: Context,
) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL_NAME = "wicara/edge_litert"
        private const val TAG = "WicaraLiteRt"
    }

    private val modelManager = ModelManager(context)
    private val lock = Any()
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val inFlightRequests = ConcurrentHashMap<String, Future<*>>()
    private val activeConversations = ConcurrentHashMap<String, Conversation>()

    @Volatile
    private var engine: Engine? = null

    @Volatile
    private var loadedModelPath: String? = null

    @Volatile
    private var loadedBackend: String = "cpu"

    @Volatile
    private var defaultMaxTokens: Int = 256

    @Volatile
    private var lastLoadMetrics: LoadMetrics? = null

    @Volatile
    private var downloadInProgress: Boolean = false

    @Volatile
    private var downloadStatus: String = "idle"

    @Volatile
    private var downloadReceivedBytes: Long = 0L

    @Volatile
    private var downloadTotalBytes: Long = -1L

    @Volatile
    private var downloadError: String? = null

    @Volatile
    private var downloadModelPath: String? = null

    @Volatile
    private var downloadSha256: String? = null

    @Volatile
    private var downloadMs: Long? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getRuntimeStatus" -> {
                result.success(runtimeStatus())
            }
            "initializeModel" -> {
                initializeModel(call, result)
            }
            "downloadModel" -> {
                downloadModel(call, result)
            }
            "generate" -> {
                generate(call, result, forceJson = false)
            }
            "generateJson" -> {
                generate(call, result, forceJson = true)
            }
            "cancel" -> {
                cancel(call, result)
            }
            "unloadModel" -> {
                unload(result)
            }
            else -> result.notImplemented()
        }
    }

    private fun downloadModel(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        val url = (args?.get("url") as? String)?.trim().orEmpty()
        val expectedSha256 = (args?.get("sha256") as? String)?.trim()?.lowercase()
        val overwrite = args?.get("overwrite") == true
        val requestedModelPath = (args?.get("modelPath") as? String)?.trim()
        val connectTimeoutMs = (args?.get("connectTimeoutMs") as? Number)?.toInt() ?: 30_000
        val readTimeoutMs = (args?.get("readTimeoutMs") as? Number)?.toInt() ?: 120_000

        if (url.isBlank()) {
            result.error("INVALID_URL", "Model download URL must not be empty.", null)
            return
        }
        if (!url.startsWith("https://")) {
            result.error("INVALID_URL", "Model download URL must use HTTPS.", null)
            return
        }

        executor.execute {
            val targetFile = modelManager.resolveWritableModelPath(requestedModelPath)
            targetFile.parentFile?.mkdirs()
            val metadataPath = modelManager.metadataPathFor(targetFile.absolutePath)
            downloadModelPath = targetFile.absolutePath
            downloadError = null
            downloadSha256 = null
            downloadMs = null

            if (targetFile.exists() && !overwrite) {
                val existingSha = computeSha256(targetFile)
                downloadInProgress = false
                downloadStatus = "skipped"
                downloadReceivedBytes = targetFile.length()
                downloadTotalBytes = targetFile.length()
                downloadSha256 = existingSha
                downloadError = null
                downloadMs = 0L
                result.success(
                    mapOf(
                        "success" to true,
                        "skipped" to true,
                        "modelPath" to targetFile.absolutePath,
                        "metadataPath" to metadataPath,
                        "bytesDownloaded" to 0L,
                        "sha256" to existingSha,
                    ),
                )
                return@execute
            }

            val tempFile = File("${targetFile.absolutePath}.download")
            runCatching {
                if (tempFile.exists()) {
                    tempFile.delete()
                }
            }

            try {
                downloadInProgress = true
                downloadStatus = "downloading"
                downloadReceivedBytes = 0L
                downloadTotalBytes = -1L
                downloadError = null
                downloadSha256 = null
                val start = SystemClock.elapsedRealtime()
                val (bytesDownloaded, actualSha256) = downloadFile(
                    url = url,
                    targetFile = tempFile,
                    connectTimeoutMs = connectTimeoutMs,
                    readTimeoutMs = readTimeoutMs,
                    onProgress = { received, total ->
                        downloadReceivedBytes = received
                        downloadTotalBytes = total ?: -1L
                    },
                )

                if (!expectedSha256.isNullOrBlank() && actualSha256 != expectedSha256) {
                    tempFile.delete()
                    downloadInProgress = false
                    downloadStatus = "failed"
                    downloadError =
                        "Checksum mismatch. Expected $expectedSha256 but got $actualSha256."
                    result.error(
                        "SHA256_MISMATCH",
                        "Downloaded model checksum mismatch. Expected $expectedSha256 but got $actualSha256.",
                        null,
                    )
                    return@execute
                }

                if (targetFile.exists()) {
                    targetFile.delete()
                }
                tempFile.copyTo(targetFile, overwrite = true)
                tempFile.delete()

                writeMetadata(
                    modelPath = targetFile.absolutePath,
                    sha256 = actualSha256,
                    source = "downloaded",
                )

                val downloadMs = SystemClock.elapsedRealtime() - start
                this.downloadMs = downloadMs
                downloadInProgress = false
                downloadStatus = "completed"
                downloadError = null
                downloadReceivedBytes = bytesDownloaded
                if (downloadTotalBytes <= 0L) {
                    downloadTotalBytes = bytesDownloaded
                }
                downloadSha256 = actualSha256
                result.success(
                    mapOf(
                        "success" to true,
                        "skipped" to false,
                        "modelPath" to targetFile.absolutePath,
                        "metadataPath" to metadataPath,
                        "bytesDownloaded" to bytesDownloaded,
                        "sha256" to actualSha256,
                        "downloadMs" to downloadMs,
                    ),
                )
            } catch (error: Throwable) {
                runCatching {
                    tempFile.delete()
                }
                downloadInProgress = false
                downloadStatus = "failed"
                downloadError = error.message ?: "Model download failed."
                result.error(
                    "DOWNLOAD_FAILED",
                    error.message ?: "Model download failed.",
                    null,
                )
            }
        }
    }

    private fun initializeModel(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        val requestedModelPath = args?.get("modelPath") as? String
        val requestedBackend = (args?.get("backend") as? String)?.trim()?.lowercase().orEmpty()
        val backend = if (requestedBackend.isEmpty()) "cpu" else requestedBackend
        val requestedMaxTokens = (args?.get("maxTokens") as? Number)?.toInt() ?: defaultMaxTokens

        executor.execute {
            val resolved = modelManager.resolveModelPath(requestedModelPath)
            if (!resolved.exists || resolved.path.isNullOrBlank()) {
                result.error(
                    "MODEL_NOT_FOUND",
                    "LiteRT model file is missing. Place it at ${resolved.path ?: ModelManager.DEFAULT_MODEL_RELATIVE_PATH}",
                    runtimeStatus(),
                )
                return@execute
            }

            try {
                val start = SystemClock.elapsedRealtime()
                synchronized(lock) {
                    unloadLocked()
                    val engineConfig = EngineConfig(
                        modelPath = resolved.path,
                        backend = resolveBackend(backend),
                        cacheDir = context.cacheDir.absolutePath,
                    )
                    val initializedEngine = Engine(engineConfig)
                    initializedEngine.initialize()
                    engine = initializedEngine
                    loadedModelPath = resolved.path
                    loadedBackend = backend
                    defaultMaxTokens = requestedMaxTokens
                }
                val loadMs = SystemClock.elapsedRealtime() - start
                lastLoadMetrics = LoadMetrics(
                    loadMs = loadMs,
                    backend = backend,
                    modelPath = resolved.path,
                )
                result.success(
                    mapOf(
                        "success" to true,
                        "loadMs" to loadMs,
                        "backend" to backend,
                        "modelPath" to resolved.path,
                        "status" to runtimeStatus(),
                    ),
                )
            } catch (error: Throwable) {
                synchronized(lock) {
                    unloadLocked()
                }
                Log.e(
                    TAG,
                    "initializeModel failed backend=$backend modelPath=${resolved.path} requestedMaxTokens=$requestedMaxTokens error=${error.message}",
                    error,
                )
                result.error(
                    "INITIALIZE_FAILED",
                    error.message ?: "Failed to initialize LiteRT-LM engine.",
                    runtimeStatus(),
                )
            }
        }
    }

    private fun generate(call: MethodCall, result: MethodChannel.Result, forceJson: Boolean) {
        val args = call.arguments as? Map<*, *>
        val requestId = (args?.get("requestId") as? String)
            ?.takeIf { it.isNotBlank() }
            ?: "req_${System.currentTimeMillis()}"
        val schemaName = if (forceJson) (args?.get("schemaName") as? String).orEmpty() else ""

        val prompt = if (forceJson) {
            val system = (args?.get("system") as? String).orEmpty()
            val user = (args?.get("user") as? String).orEmpty()
            buildJsonPrompt(system = system, user = user, schemaName = schemaName)
        } else {
            (args?.get("prompt") as? String).orEmpty()
        }

        if (prompt.isBlank()) {
            result.error("INVALID_PROMPT", "Prompt must not be empty.", null)
            return
        }

        val requestedTemperature = (args?.get("temperature") as? Number)?.toDouble() ?: 0.3
        val requestedMaxTokens = (args?.get("maxTokens") as? Number)?.toInt() ?: defaultMaxTokens
        Log.d(
            TAG,
            "generate start requestId=$requestId forceJson=$forceJson schema=$schemaName promptChars=${prompt.length} maxTokens=$requestedMaxTokens temp=$requestedTemperature",
        )

        val task = executor.submit {
            try {
                val start = SystemClock.elapsedRealtime()
                val responseText = synchronized(lock) {
                    val activeEngine = engine
                        ?: throw IllegalStateException(
                            "LiteRT model is not initialized. Call initializeModel first.",
                        )
                    val samplerConfig = SamplerConfig(
                        topK = 40,
                        topP = 0.9,
                        temperature = requestedTemperature,
                        seed = 0,
                    )
                    val conversation = activeEngine.createConversation(
                        ConversationConfig(samplerConfig = samplerConfig),
                    )
                    activeConversations[requestId] = conversation
                    try {
                        val responseMessage = conversation.sendMessage(
                            prompt,
                            mapOf(
                                "temperature" to requestedTemperature,
                                "max_tokens" to requestedMaxTokens,
                                "maxNumTokens" to requestedMaxTokens,
                            ),
                        )
                        extractMessageText(responseMessage)
                    } finally {
                        activeConversations.remove(requestId)
                        // LiteRT currently supports a single active session per engine.
                        // Always close conversation after each request to avoid session leak.
                        runCatching { conversation.close() }
                    }
                }

                val totalMs = SystemClock.elapsedRealtime() - start
                val metrics = GenerationMetrics(
                    totalMs = totalMs,
                    inputChars = prompt.length,
                    outputChars = responseText.length,
                    outputCharsPerSecond = if (totalMs <= 0L) {
                        0.0
                    } else {
                        (responseText.length * 1000.0) / totalMs
                    },
                )

                val basePayload = mapOf(
                    "text" to responseText,
                    "finishReason" to "completed",
                    "metrics" to metrics.toMap(),
                    "runtime" to "litert_lm",
                    "modelId" to "gemma-4-e2b-it-litertlm",
                    "executionLocation" to "device",
                    "fallback" to false,
                    "requestId" to requestId,
                    "requestedTemperature" to requestedTemperature,
                    "requestedMaxTokens" to requestedMaxTokens,
                    "backend" to loadedBackend,
                    "modelPath" to loadedModelPath,
                )

                if (!forceJson) {
                    result.success(basePayload)
                } else {
                    result.success(
                        basePayload + mapOf(
                            "rawText" to responseText,
                            "parsedJsonString" to extractJsonString(responseText),
                        ),
                    )
                }
                Log.d(
                    TAG,
                    "generate done requestId=$requestId forceJson=$forceJson totalMs=$totalMs outputChars=${responseText.length}",
                )
            } catch (error: Throwable) {
                Log.e(
                    TAG,
                    "generate failed requestId=$requestId forceJson=$forceJson: ${error.message}",
                    error,
                )
                result.error(
                    "GENERATION_FAILED",
                    error.message ?: "LiteRT generation failed.",
                    runtimeStatus(),
                )
            } finally {
                inFlightRequests.remove(requestId)
            }
        }

        inFlightRequests[requestId] = task
    }

    private fun cancel(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        val requestId = (args?.get("requestId") as? String).orEmpty()
        if (requestId.isBlank()) {
            result.success(mapOf("cancelled" to false, "reason" to "missing_request_id"))
            return
        }
        val conversation = activeConversations.remove(requestId)
        runCatching {
            conversation?.cancelProcess()
            conversation?.close()
        }
        val running = inFlightRequests.remove(requestId)
        val cancelled = running?.cancel(true) ?: false
        result.success(mapOf("cancelled" to cancelled, "requestId" to requestId))
    }

    private fun unload(result: MethodChannel.Result) {
        executor.execute {
            synchronized(lock) {
                unloadLocked()
            }
            result.success(mapOf("success" to true))
        }
    }

    private fun unloadLocked() {
        activeConversations.values.forEach { conversation ->
            runCatching {
                conversation.cancelProcess()
                conversation.close()
            }
        }
        activeConversations.clear()

        inFlightRequests.values.forEach { it.cancel(true) }
        inFlightRequests.clear()

        engine?.close()
        engine = null
        loadedModelPath = null
        loadedBackend = "cpu"
    }

    private fun runtimeStatus(): Map<String, Any?> {
        val resolved = modelManager.resolveModelPath(loadedModelPath)
        val totalBytes = if (downloadTotalBytes > 0L) downloadTotalBytes else null
        val progress = if (totalBytes != null && totalBytes > 0L) {
            (downloadReceivedBytes.toDouble() / totalBytes.toDouble()).coerceIn(0.0, 1.0)
        } else {
            null
        }
        return mapOf(
            "available" to isLiteRtDependencyAvailable(),
            "runtime" to "litert_lm",
            "loaded" to (engine != null),
            "backend" to loadedBackend,
            "modelPath" to loadedModelPath,
            "defaultModelPath" to resolved.path,
            "defaultModelExists" to resolved.exists,
            "modelFileBytes" to if (resolved.path.isNullOrBlank()) null else runCatching {
                File(resolved.path).length()
            }.getOrNull(),
            "modelFileLastModifiedMs" to if (resolved.path.isNullOrBlank()) null else runCatching {
                File(resolved.path).lastModified()
            }.getOrNull(),
            "metadataPath" to modelManager.metadataPathFor(loadedModelPath ?: resolved.path),
            "executionLocation" to if (engine != null) "device" else "not_ready",
            "loadMetrics" to lastLoadMetrics?.toMap(),
            "download" to mapOf(
                "inProgress" to downloadInProgress,
                "status" to downloadStatus,
                "receivedBytes" to downloadReceivedBytes,
                "totalBytes" to totalBytes,
                "progress" to progress,
                "error" to downloadError,
                "modelPath" to downloadModelPath,
                "sha256" to downloadSha256,
                "downloadMs" to downloadMs,
            ),
            "deviceInfo" to modelManager.deviceInfoMap(),
        )
    }

    private fun isLiteRtDependencyAvailable(): Boolean {
        return try {
            Class.forName("com.google.ai.edge.litertlm.Engine")
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun resolveBackend(backend: String): Backend {
        return when (backend.lowercase()) {
            "gpu" -> Backend.GPU()
            "npu" -> Backend.NPU(context.applicationInfo.nativeLibraryDir)
            else -> Backend.CPU()
        }
    }

    private fun extractMessageText(message: Any?): String {
        if (message == null) return ""

        return runCatching {
            val method = message.javaClass.methods.firstOrNull {
                it.name == "getText" && it.parameterCount == 0
            }
            val value = method?.invoke(message)?.toString().orEmpty()
            if (value.isBlank()) message.toString() else value
        }.getOrElse {
            message.toString()
        }
    }

    private fun buildJsonPrompt(
        system: String,
        user: String,
        schemaName: String,
    ): String {
        val schemaPart = if (schemaName.isBlank()) "" else "Schema: $schemaName\n"
        return buildString {
            appendLine("You must output valid JSON only.")
            if (system.isNotBlank()) {
                appendLine(system.trim())
            }
            append(schemaPart)
            append(user.trim())
        }.trim()
    }

    private fun extractJsonString(rawText: String): String {
        val start = rawText.indexOf('{')
        val end = rawText.lastIndexOf('}')
        if (start >= 0 && end > start) {
            return rawText.substring(start, end + 1)
        }
        return rawText.trim()
    }

    private fun writeMetadata(modelPath: String, sha256: String, source: String) {
        val metadataPath = modelManager.metadataPathFor(modelPath) ?: return
        val metadataFile = File(metadataPath)
        metadataFile.parentFile?.mkdirs()
        val payload = JSONObject(
            mapOf(
                "model_id" to "gemma-4-e2b-it-litertlm",
                "runtime" to "litert-lm",
                "source" to source,
                "sha256" to sha256,
                "last_loaded_at" to Instant.now().toString(),
            ),
        )
        metadataFile.writeText(payload.toString(2))
    }

    private fun computeSha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val read = input.read(buffer)
                if (read <= 0) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    private fun downloadFile(
        url: String,
        targetFile: File,
        connectTimeoutMs: Int,
        readTimeoutMs: Int,
        onProgress: (receivedBytes: Long, totalBytes: Long?) -> Unit,
    ): Pair<Long, String> {
        val digest = MessageDigest.getInstance("SHA-256")
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = connectTimeoutMs
            readTimeout = readTimeoutMs
            instanceFollowRedirects = true
        }

        var totalBytes = 0L
        try {
            connection.connect()
            if (connection.responseCode !in 200..299) {
                throw IllegalStateException(
                    "HTTP ${connection.responseCode} while downloading model from $url",
                )
            }
            val contentLength = connection.contentLengthLong
            val totalBytesExpected = if (contentLength > 0L) contentLength else null
            onProgress(0L, totalBytesExpected)

            BufferedInputStream(connection.inputStream).use { input ->
                FileOutputStream(targetFile).use { output ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    while (true) {
                        val read = input.read(buffer)
                        if (read <= 0) break
                        output.write(buffer, 0, read)
                        digest.update(buffer, 0, read)
                        totalBytes += read
                        onProgress(totalBytes, totalBytesExpected)
                    }
                    output.flush()
                }
            }
        } finally {
            connection.disconnect()
        }

        val sha256 = digest.digest().joinToString("") { "%02x".format(it) }
        return totalBytes to sha256
    }
}
