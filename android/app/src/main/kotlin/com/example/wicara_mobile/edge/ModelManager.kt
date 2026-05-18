package com.example.wicara_mobile.edge

import android.content.Context
import android.os.Build
import java.io.File

class ModelManager(private val context: Context) {
    companion object {
        const val DEFAULT_MODEL_RELATIVE_PATH = "models/gemma4-e2b-it/model.litertlm"
    }

    data class ResolvedModel(
        val path: String?,
        val exists: Boolean,
        val source: String,
    )

    fun resolveModelPath(explicitPath: String?): ResolvedModel {
        val normalizedExplicit = explicitPath?.trim().orEmpty()
        if (normalizedExplicit.isNotEmpty()) {
            val explicitFile = File(normalizedExplicit)
            return ResolvedModel(
                path = explicitFile.absolutePath,
                exists = explicitFile.exists() && explicitFile.isFile,
                source = "explicit",
            )
        }

        val candidates = buildList {
            add(File(context.filesDir, DEFAULT_MODEL_RELATIVE_PATH))
            context.getExternalFilesDir(null)?.let { externalDir ->
                add(File(externalDir, DEFAULT_MODEL_RELATIVE_PATH))
            }
        }

        for (candidate in candidates) {
            if (candidate.exists() && candidate.isFile) {
                return ResolvedModel(
                    path = candidate.absolutePath,
                    exists = true,
                    source = "default_found",
                )
            }
        }

        val preferred = candidates.firstOrNull()
        return ResolvedModel(
            path = preferred?.absolutePath,
            exists = false,
            source = "default_missing",
        )
    }

    fun metadataPathFor(modelPath: String?): String? {
        if (modelPath.isNullOrBlank()) return null
        val modelFile = File(modelPath)
        val parent = modelFile.parentFile ?: return null
        return File(parent, "metadata.json").absolutePath
    }

    fun defaultModelFile(): File {
        return File(context.filesDir, DEFAULT_MODEL_RELATIVE_PATH)
    }

    fun resolveWritableModelPath(explicitPath: String?): File {
        val normalizedExplicit = explicitPath?.trim().orEmpty()
        if (normalizedExplicit.isNotEmpty()) {
            return File(normalizedExplicit)
        }
        return defaultModelFile()
    }

    fun deviceInfoMap(): Map<String, Any> = mapOf(
        "manufacturer" to Build.MANUFACTURER.orEmpty(),
        "model" to Build.MODEL.orEmpty(),
        "device" to Build.DEVICE.orEmpty(),
        "product" to Build.PRODUCT.orEmpty(),
        "brand" to Build.BRAND.orEmpty(),
        "sdkInt" to Build.VERSION.SDK_INT,
        "release" to Build.VERSION.RELEASE.orEmpty(),
        "abis" to Build.SUPPORTED_ABIS.toList(),
    )
}
