enum EdgeRuntimeBackend { cpu, gpu, npu }

extension EdgeRuntimeBackendX on EdgeRuntimeBackend {
  String get wireName => switch (this) {
    EdgeRuntimeBackend.cpu => 'cpu',
    EdgeRuntimeBackend.gpu => 'gpu',
    EdgeRuntimeBackend.npu => 'npu',
  };
}

class EdgeRuntimeStatus {
  const EdgeRuntimeStatus({
    required this.available,
    required this.loaded,
    required this.runtime,
    required this.backend,
    required this.executionLocation,
    required this.defaultModelExists,
    this.modelPath,
    this.defaultModelPath,
    this.loadMs,
    this.download = const EdgeModelDownloadStatus(),
    this.deviceInfo = const {},
    this.raw = const {},
  });

  final bool available;
  final bool loaded;
  final String runtime;
  final String backend;
  final String executionLocation;
  final bool defaultModelExists;
  final String? modelPath;
  final String? defaultModelPath;
  final int? loadMs;
  final EdgeModelDownloadStatus download;
  final Map<String, dynamic> deviceInfo;
  final Map<String, dynamic> raw;

  bool get isReady => available && loaded;

  factory EdgeRuntimeStatus.fromMap(Map<dynamic, dynamic>? map) {
    final status = map ?? const {};
    final loadMetrics = _asMap(status['loadMetrics']);
    final loadMsAny = loadMetrics['loadMs'] ?? status['loadMs'];

    return EdgeRuntimeStatus(
      available: status['available'] == true,
      loaded: status['loaded'] == true,
      runtime: (status['runtime'] ?? 'litert_lm').toString(),
      backend: (status['backend'] ?? 'cpu').toString(),
      executionLocation: (status['executionLocation'] ?? 'not_ready')
          .toString(),
      defaultModelExists: status['defaultModelExists'] == true,
      modelPath: _asNullableString(status['modelPath']),
      defaultModelPath: _asNullableString(status['defaultModelPath']),
      loadMs: _asInt(loadMsAny),
      download: EdgeModelDownloadStatus.fromMap(_asMap(status['download'])),
      deviceInfo: _asMap(status['deviceInfo']),
      raw: status.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
}

class EdgeModelDownloadStatus {
  const EdgeModelDownloadStatus({
    this.inProgress = false,
    this.status = 'idle',
    this.receivedBytes = 0,
    this.totalBytes,
    this.error,
    this.modelPath,
    this.sha256,
    this.downloadMs,
  });

  final bool inProgress;
  final String status;
  final int receivedBytes;
  final int? totalBytes;
  final String? error;
  final String? modelPath;
  final String? sha256;
  final int? downloadMs;

  bool get hasKnownTotal => (totalBytes ?? 0) > 0;

  double? get progressValue {
    if (!hasKnownTotal) {
      return null;
    }
    final total = totalBytes!.toDouble();
    if (total <= 0) {
      return null;
    }
    return (receivedBytes / total).clamp(0, 1).toDouble();
  }

  factory EdgeModelDownloadStatus.fromMap(Map<String, dynamic>? map) {
    final data = map ?? const {};
    return EdgeModelDownloadStatus(
      inProgress: data['inProgress'] == true,
      status: (data['status'] ?? 'idle').toString(),
      receivedBytes: _asInt(data['receivedBytes']) ?? 0,
      totalBytes: _asInt(data['totalBytes']),
      error: _asNullableString(data['error']),
      modelPath: _asNullableString(data['modelPath']),
      sha256: _asNullableString(data['sha256']),
      downloadMs: _asInt(data['downloadMs']),
    );
  }
}

class EdgeGenerationRequest {
  const EdgeGenerationRequest({
    required this.requestId,
    required this.prompt,
    this.temperature = 0.3,
    this.maxTokens = 256,
  });

  final String requestId;
  final String prompt;
  final double temperature;
  final int maxTokens;
}

class EdgeGenerationMetrics {
  const EdgeGenerationMetrics({
    required this.totalMs,
    required this.inputChars,
    required this.outputChars,
    required this.outputCharsPerSecond,
  });

  final int totalMs;
  final int inputChars;
  final int outputChars;
  final double outputCharsPerSecond;

  factory EdgeGenerationMetrics.fromMap(Map<dynamic, dynamic>? map) {
    final data = map ?? const {};
    return EdgeGenerationMetrics(
      totalMs: _asInt(data['totalMs']) ?? 0,
      inputChars: _asInt(data['inputChars']) ?? 0,
      outputChars: _asInt(data['outputChars']) ?? 0,
      outputCharsPerSecond:
          (data['outputCharsPerSecond'] as num?)?.toDouble() ?? 0,
    );
  }
}

class EdgeGenerationResult {
  const EdgeGenerationResult({
    required this.requestId,
    required this.text,
    required this.finishReason,
    required this.metrics,
    required this.runtime,
    required this.executionLocation,
    required this.fallbackUsed,
    required this.raw,
  });

  final String requestId;
  final String text;
  final String finishReason;
  final EdgeGenerationMetrics metrics;
  final String runtime;
  final String executionLocation;
  final bool fallbackUsed;
  final Map<String, dynamic> raw;

  factory EdgeGenerationResult.fromMap(Map<dynamic, dynamic>? map) {
    final data = map ?? const {};
    return EdgeGenerationResult(
      requestId: (data['requestId'] ?? '').toString(),
      text: (data['text'] ?? '').toString(),
      finishReason: (data['finishReason'] ?? 'unknown').toString(),
      metrics: EdgeGenerationMetrics.fromMap(_asMap(data['metrics'])),
      runtime: (data['runtime'] ?? 'litert_lm').toString(),
      executionLocation: (data['executionLocation'] ?? 'unknown').toString(),
      fallbackUsed: data['fallback'] == true,
      raw: data.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
}

class EdgeJsonGenerationRequest {
  const EdgeJsonGenerationRequest({
    required this.requestId,
    required this.system,
    required this.user,
    required this.schemaName,
    this.temperature = 0.2,
    this.maxTokens = 320,
  });

  final String requestId;
  final String system;
  final String user;
  final String schemaName;
  final double temperature;
  final int maxTokens;
}

class EdgeJsonGenerationResult {
  const EdgeJsonGenerationResult({
    required this.rawText,
    required this.parsedJsonString,
    required this.base,
  });

  final String rawText;
  final String parsedJsonString;
  final EdgeGenerationResult base;

  factory EdgeJsonGenerationResult.fromMap(Map<dynamic, dynamic>? map) {
    final data = map ?? const {};
    return EdgeJsonGenerationResult(
      rawText: (data['rawText'] ?? '').toString(),
      parsedJsonString: (data['parsedJsonString'] ?? '').toString(),
      base: EdgeGenerationResult.fromMap(data),
    );
  }
}

class EdgeModelInstallResult {
  const EdgeModelInstallResult({
    required this.success,
    required this.skipped,
    required this.modelPath,
    required this.bytesDownloaded,
    required this.sha256,
    this.downloadMs,
    this.raw = const {},
  });

  final bool success;
  final bool skipped;
  final String modelPath;
  final int bytesDownloaded;
  final String sha256;
  final int? downloadMs;
  final Map<String, dynamic> raw;

  factory EdgeModelInstallResult.fromMap(Map<dynamic, dynamic>? map) {
    final data = map ?? const {};
    return EdgeModelInstallResult(
      success: data['success'] == true,
      skipped: data['skipped'] == true,
      modelPath: (data['modelPath'] ?? '').toString(),
      bytesDownloaded: _asInt(data['bytesDownloaded']) ?? 0,
      sha256: (data['sha256'] ?? '').toString(),
      downloadMs: _asInt(data['downloadMs']),
      raw: data.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return const {};
}

String? _asNullableString(dynamic value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
