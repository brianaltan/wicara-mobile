import 'edge_ai_models.dart';

abstract interface class EdgeAiRuntime {
  Future<EdgeRuntimeStatus> getStatus();

  Future<EdgeRuntimeStatus> initialize({
    String? modelPath,
    EdgeRuntimeBackend backend = EdgeRuntimeBackend.cpu,
    int maxTokens = 256,
  });

  Future<EdgeModelInstallResult> installModel({
    required String url,
    String? sha256,
    bool overwrite = false,
    String? modelPath,
  });

  Future<EdgeGenerationResult> generate(EdgeGenerationRequest request);

  Future<EdgeJsonGenerationResult> generateJson(
    EdgeJsonGenerationRequest request,
  );

  Future<void> cancel(String requestId);

  Future<void> unload();
}
