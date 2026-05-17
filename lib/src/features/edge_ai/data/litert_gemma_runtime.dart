import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/edge_ai_models.dart';
import '../domain/edge_ai_runtime.dart';

const _edgeMethodChannel = MethodChannel('wicara/edge_litert');

const EdgeAiRuntime defaultEdgeAiRuntime = LiteRtGemmaRuntime();

class LiteRtGemmaRuntime implements EdgeAiRuntime {
  const LiteRtGemmaRuntime({MethodChannel channel = _edgeMethodChannel})
    : _channel = channel;

  final MethodChannel _channel;

  bool get _isAndroidTarget =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<EdgeRuntimeStatus> getStatus() async {
    if (!_isAndroidTarget) {
      return const EdgeRuntimeStatus(
        available: false,
        loaded: false,
        runtime: 'litert_lm',
        backend: 'cpu',
        executionLocation: 'unsupported_platform',
        defaultModelExists: false,
      );
    }
    final map = await _invokeMap('getRuntimeStatus');
    return EdgeRuntimeStatus.fromMap(map);
  }

  @override
  Future<EdgeRuntimeStatus> initialize({
    String? modelPath,
    EdgeRuntimeBackend backend = EdgeRuntimeBackend.cpu,
    int maxTokens = 256,
  }) async {
    _ensureAndroidTarget();
    await _channel.invokeMethod<dynamic>('initializeModel', {
      'modelPath': modelPath,
      'backend': backend.wireName,
      'maxTokens': maxTokens,
    });
    return getStatus();
  }

  @override
  Future<EdgeModelInstallResult> installModel({
    required String url,
    String? sha256,
    bool overwrite = false,
    String? modelPath,
  }) async {
    _ensureAndroidTarget();
    final map = await _invokeMap('downloadModel', {
      'url': url,
      'sha256': sha256,
      'overwrite': overwrite,
      'modelPath': modelPath,
    });
    return EdgeModelInstallResult.fromMap(map);
  }

  @override
  Future<EdgeGenerationResult> generate(EdgeGenerationRequest request) async {
    _ensureAndroidTarget();
    final map = await _invokeMap('generate', {
      'requestId': request.requestId,
      'prompt': request.prompt,
      'temperature': request.temperature,
      'maxTokens': request.maxTokens,
    });
    return EdgeGenerationResult.fromMap(map);
  }

  @override
  Future<EdgeJsonGenerationResult> generateJson(
    EdgeJsonGenerationRequest request,
  ) async {
    _ensureAndroidTarget();
    final map = await _invokeMap('generateJson', {
      'requestId': request.requestId,
      'system': request.system,
      'user': request.user,
      'schemaName': request.schemaName,
    });
    return EdgeJsonGenerationResult.fromMap(map);
  }

  @override
  Future<void> cancel(String requestId) async {
    _ensureAndroidTarget();
    await _channel.invokeMethod<dynamic>('cancel', {'requestId': requestId});
  }

  @override
  Future<void> unload() async {
    _ensureAndroidTarget();
    await _channel.invokeMethod<dynamic>('unloadModel');
  }

  Future<Map<dynamic, dynamic>> _invokeMap(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    final value = await _channel.invokeMethod<dynamic>(method, arguments);
    if (value is Map<dynamic, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<dynamic, dynamic>();
    }
    return const {};
  }

  void _ensureAndroidTarget() {
    if (_isAndroidTarget) {
      return;
    }
    throw UnsupportedError(
      'LiteRT-LM runtime hanya tersedia di Android. Jalankan dengan `flutter run -d <android_device_id>`.',
    );
  }
}
