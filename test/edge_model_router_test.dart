import 'package:flutter_test/flutter_test.dart';
import 'package:wicara_mobile/src/features/edge_ai/data/cloud_tutor_runtime.dart';
import 'package:wicara_mobile/src/features/edge_ai/data/deterministic_local_runtime.dart';
import 'package:wicara_mobile/src/features/edge_ai/domain/edge_ai_models.dart';
import 'package:wicara_mobile/src/features/edge_ai/domain/edge_ai_runtime.dart';
import 'package:wicara_mobile/src/features/edge_ai/domain/edge_model_router.dart';

void main() {
  group('EdgeModelRouter', () {
    test('covers all task types with deterministic or LiteRT route', () async {
      const router = EdgeModelRouter(
        liteRtRuntime: _FakeRuntime(ready: true),
        deterministicRuntime: DeterministicLocalRuntime(),
        cloudRuntime: CloudTutorRuntime(),
      );

      for (final task in EdgeTaskType.values) {
        final result = await router.routeAndGenerate(
          task: task,
          prompt: 'jelaskan turunan singkat',
          requestId: 'req_${task.name}',
        );
        expect(result.text.trim().isNotEmpty, isTrue, reason: task.name);
        expect(result.audit.runtimeTarget.trim().isNotEmpty, isTrue);
        expect(result.audit.executionLocation.trim().isNotEmpty, isTrue);
      }
    });

    test('falls back to deterministic local when LiteRT not ready', () async {
      const router = EdgeModelRouter(
        liteRtRuntime: _FakeRuntime(ready: false),
        deterministicRuntime: DeterministicLocalRuntime(),
        cloudRuntime: CloudTutorRuntime(),
      );

      final result = await router.routeAndGenerate(
        task: EdgeTaskType.tutorExplain,
        prompt: 'apa itu turunan',
        requestId: 'req_not_ready',
      );

      expect(result.decision.target, EdgeRuntimeTarget.deterministicLocal);
      expect(result.audit.fallbackUsed, isTrue);
      expect(result.audit.executionLocation, 'device');
    });

    test('uses explicit cloud fallback when allowed', () async {
      const router = EdgeModelRouter(
        liteRtRuntime: _FakeRuntime(ready: false),
        deterministicRuntime: DeterministicLocalRuntime(),
        cloudRuntime: CloudTutorRuntime(),
        forceLocalForPilot: false,
        cloudFallbackAllowed: true,
      );

      final result = await router.routeAndGenerate(
        task: EdgeTaskType.tutorExplain,
        prompt: 'apa itu turunan',
        requestId: 'req_cloud',
        allowCloudFallback: true,
        cloudGenerator: () async => 'Cloud fallback response',
      );

      expect(result.decision.target, EdgeRuntimeTarget.cloudTutor);
      expect(result.audit.executionLocation, 'cloud');
      expect(result.audit.fallbackUsed, isTrue);
      expect(result.text, 'Cloud fallback response');
    });
  });
}

class _FakeRuntime implements EdgeAiRuntime {
  const _FakeRuntime({required this.ready});

  final bool ready;

  @override
  Future<void> cancel(String requestId) async {}

  @override
  Future<EdgeGenerationResult> generate(EdgeGenerationRequest request) async {
    return EdgeGenerationResult(
      requestId: request.requestId,
      text: 'LiteRT response for ${request.prompt}',
      finishReason: 'completed',
      metrics: const EdgeGenerationMetrics(
        totalMs: 25,
        inputChars: 20,
        outputChars: 30,
        outputCharsPerSecond: 120.0,
      ),
      runtime: 'litert_lm',
      executionLocation: 'device',
      fallbackUsed: false,
      raw: const {},
    );
  }

  @override
  Future<EdgeJsonGenerationResult> generateJson(
    EdgeJsonGenerationRequest request,
  ) async {
    final base = await generate(
      EdgeGenerationRequest(requestId: request.requestId, prompt: request.user),
    );
    return EdgeJsonGenerationResult(
      rawText: '{"ok":true}',
      parsedJsonString: '{"ok":true}',
      base: base,
    );
  }

  @override
  Future<EdgeRuntimeStatus> getStatus() async {
    return EdgeRuntimeStatus(
      available: true,
      loaded: ready,
      runtime: 'litert_lm',
      backend: 'cpu',
      executionLocation: ready ? 'device' : 'not_ready',
      defaultModelExists: true,
    );
  }

  @override
  Future<EdgeRuntimeStatus> initialize({
    String? modelPath,
    EdgeRuntimeBackend backend = EdgeRuntimeBackend.cpu,
    int maxTokens = 256,
  }) async {
    return getStatus();
  }

  @override
  Future<EdgeModelInstallResult> installModel({
    required String url,
    String? sha256,
    bool overwrite = false,
    String? modelPath,
  }) async {
    return const EdgeModelInstallResult(
      success: true,
      skipped: true,
      modelPath: '/tmp/model.litertlm',
      bytesDownloaded: 0,
      sha256: '',
    );
  }

  @override
  Future<void> unload() async {}
}
