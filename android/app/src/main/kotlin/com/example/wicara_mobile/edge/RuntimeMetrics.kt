package com.example.wicara_mobile.edge

data class LoadMetrics(
    val loadMs: Long,
    val backend: String,
    val modelPath: String,
)

data class GenerationMetrics(
    val totalMs: Long,
    val inputChars: Int,
    val outputChars: Int,
    val outputCharsPerSecond: Double,
)

fun LoadMetrics.toMap(): Map<String, Any> = mapOf(
    "loadMs" to loadMs,
    "backend" to backend,
    "modelPath" to modelPath,
)

fun GenerationMetrics.toMap(): Map<String, Any> = mapOf(
    "totalMs" to totalMs,
    "inputChars" to inputChars,
    "outputChars" to outputChars,
    "outputCharsPerSecond" to outputCharsPerSecond,
)
