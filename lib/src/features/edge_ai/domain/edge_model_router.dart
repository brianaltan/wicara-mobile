import '../data/cloud_tutor_runtime.dart';
import '../data/deterministic_local_runtime.dart';
import '../data/litert_gemma_runtime.dart';
import 'edge_ai_models.dart';
import 'edge_ai_runtime.dart';

enum EdgeTaskType {
  intentParse,
  pretestReasoningGrade,
  tutorExplain,
  tutorHint,
  tutorEvaluate,
  quizGenerate,
  summaryGenerate,
}

enum EdgeRuntimeTarget { litertGemma4, deterministicLocal, cloudTutor }

extension EdgeRuntimeTargetX on EdgeRuntimeTarget {
  String get wireName => switch (this) {
    EdgeRuntimeTarget.litertGemma4 => 'litert_gemma4',
    EdgeRuntimeTarget.deterministicLocal => 'deterministic_local',
    EdgeRuntimeTarget.cloudTutor => 'cloud_tutor',
  };
}

class EdgeRouteDecision {
  const EdgeRouteDecision({
    required this.target,
    required this.reason,
    required this.requiresNetwork,
    required this.privacySensitive,
    required this.userVisibleFallback,
  });

  final EdgeRuntimeTarget target;
  final String reason;
  final bool requiresNetwork;
  final bool privacySensitive;
  final bool userVisibleFallback;
}

class EdgeRouteAudit {
  const EdgeRouteAudit({
    required this.runtimeTarget,
    required this.modelId,
    required this.executionLocation,
    required this.networkRequired,
    required this.fallbackUsed,
    required this.routeReason,
    required this.latencyMs,
    required this.inputChars,
    required this.outputChars,
    required this.createdAtIso8601,
  });

  final String runtimeTarget;
  final String modelId;
  final String executionLocation;
  final bool networkRequired;
  final bool fallbackUsed;
  final String routeReason;
  final int latencyMs;
  final int inputChars;
  final int outputChars;
  final String createdAtIso8601;

  Map<String, dynamic> toJson() => {
    'runtime_target': runtimeTarget,
    'model_id': modelId,
    'execution_location': executionLocation,
    'network_required': networkRequired,
    'fallback_used': fallbackUsed,
    'route_reason': routeReason,
    'latency_ms': latencyMs,
    'input_chars': inputChars,
    'output_chars': outputChars,
    'created_at': createdAtIso8601,
  };
}

class EdgeRouteResult {
  const EdgeRouteResult({
    required this.text,
    required this.decision,
    required this.audit,
  });

  final String text;
  final EdgeRouteDecision decision;
  final EdgeRouteAudit audit;

  Map<String, dynamic> get auditMetadata => audit.toJson();
}

typedef CloudTextGenerator = Future<String?> Function();

class EdgeModelRouter {
  const EdgeModelRouter({
    this.liteRtRuntime = defaultEdgeAiRuntime,
    this.deterministicRuntime = const DeterministicLocalRuntime(),
    this.cloudRuntime = const CloudTutorRuntime(),
    this.forceLocalForPilot = true,
    this.cloudFallbackAllowed = false,
  });

  final EdgeAiRuntime liteRtRuntime;
  final DeterministicLocalRuntime deterministicRuntime;
  final CloudTutorRuntime cloudRuntime;
  final bool forceLocalForPilot;
  final bool cloudFallbackAllowed;

  Future<EdgeRouteResult> routeAndGenerate({
    required EdgeTaskType task,
    required String prompt,
    required String requestId,
    double temperature = 0.3,
    int maxTokens = 220,
    bool? allowCloudFallback,
    CloudTextGenerator? cloudGenerator,
  }) async {
    final inputChars = prompt.length;
    final useCloudFallback =
        (allowCloudFallback ?? cloudFallbackAllowed) && !forceLocalForPilot;

    final initialDecision = _defaultDecision(task);
    if (initialDecision.target == EdgeRuntimeTarget.deterministicLocal) {
      final text = deterministicRuntime.generate(task: task, prompt: prompt);
      return EdgeRouteResult(
        text: text,
        decision: initialDecision,
        audit: _audit(
          runtimeTarget: initialDecision.target.wireName,
          modelId: 'deterministic-local-v1',
          executionLocation: 'device',
          networkRequired: false,
          fallbackUsed: false,
          routeReason: initialDecision.reason,
          latencyMs: 0,
          inputChars: inputChars,
          outputChars: text.length,
        ),
      );
    }

    final status = await liteRtRuntime.getStatus();
    if (status.isReady) {
      try {
        final output = await liteRtRuntime.generate(
          EdgeGenerationRequest(
            requestId: requestId,
            prompt: prompt,
            temperature: temperature,
            maxTokens: maxTokens,
          ),
        );
        return EdgeRouteResult(
          text: output.text,
          decision: initialDecision,
          audit: _audit(
            runtimeTarget: initialDecision.target.wireName,
            modelId: 'gemma-4-e2b-it-litertlm',
            executionLocation: output.executionLocation,
            networkRequired: false,
            fallbackUsed: false,
            routeReason: initialDecision.reason,
            latencyMs: output.metrics.totalMs,
            inputChars: inputChars,
            outputChars: output.text.length,
          ),
        );
      } catch (error) {
        return _fallback(
          task: task,
          prompt: prompt,
          inputChars: inputChars,
          useCloudFallback: useCloudFallback,
          cloudGenerator: cloudGenerator,
          routeReason: _routeReasonWithError(
            base: 'litert_generation_failed',
            error: error,
          ),
        );
      }
    }

    return _fallback(
      task: task,
      prompt: prompt,
      inputChars: inputChars,
      useCloudFallback: useCloudFallback,
      cloudGenerator: cloudGenerator,
      routeReason: 'litert_not_ready',
    );
  }

  Future<EdgeRouteResult> _fallback({
    required EdgeTaskType task,
    required String prompt,
    required int inputChars,
    required bool useCloudFallback,
    required CloudTextGenerator? cloudGenerator,
    required String routeReason,
  }) async {
    if (useCloudFallback && cloudGenerator != null) {
      try {
        final cloudText = await cloudRuntime.generate(
          task: task,
          prompt: prompt,
          cloudGenerator: cloudGenerator,
        );
        final decision = EdgeRouteDecision(
          target: EdgeRuntimeTarget.cloudTutor,
          reason: '$routeReason:explicit_cloud_fallback',
          requiresNetwork: true,
          privacySensitive: true,
          userVisibleFallback: true,
        );
        return EdgeRouteResult(
          text: cloudText,
          decision: decision,
          audit: _audit(
            runtimeTarget: decision.target.wireName,
            modelId: 'cloud-tutor-backend',
            executionLocation: 'cloud',
            networkRequired: true,
            fallbackUsed: true,
            routeReason: decision.reason,
            latencyMs: 0,
            inputChars: inputChars,
            outputChars: cloudText.length,
          ),
        );
      } catch (_) {
        // Continue to deterministic fallback.
      }
    }

    final text = deterministicRuntime.generate(task: task, prompt: prompt);
    final decision = EdgeRouteDecision(
      target: EdgeRuntimeTarget.deterministicLocal,
      reason: '$routeReason:deterministic_local_fallback',
      requiresNetwork: false,
      privacySensitive: true,
      userVisibleFallback: true,
    );
    return EdgeRouteResult(
      text: text,
      decision: decision,
      audit: _audit(
        runtimeTarget: decision.target.wireName,
        modelId: 'deterministic-local-v1',
        executionLocation: 'device',
        networkRequired: false,
        fallbackUsed: true,
        routeReason: decision.reason,
        latencyMs: 0,
        inputChars: inputChars,
        outputChars: text.length,
      ),
    );
  }

  EdgeRouteDecision _defaultDecision(EdgeTaskType task) {
    return switch (task) {
      EdgeTaskType.intentParse => const EdgeRouteDecision(
        target: EdgeRuntimeTarget.deterministicLocal,
        reason: 'intent_parse_keyword_first',
        requiresNetwork: false,
        privacySensitive: false,
        userVisibleFallback: false,
      ),
      EdgeTaskType.tutorHint => const EdgeRouteDecision(
        target: EdgeRuntimeTarget.litertGemma4,
        reason: 'core_tutoring_hint_local_default',
        requiresNetwork: false,
        privacySensitive: true,
        userVisibleFallback: true,
      ),
      EdgeTaskType.tutorExplain => const EdgeRouteDecision(
        target: EdgeRuntimeTarget.litertGemma4,
        reason: 'core_tutoring_explain_privacy_latency',
        requiresNetwork: false,
        privacySensitive: true,
        userVisibleFallback: true,
      ),
      EdgeTaskType.tutorEvaluate => const EdgeRouteDecision(
        target: EdgeRuntimeTarget.litertGemma4,
        reason: 'core_tutoring_evaluate_local_default',
        requiresNetwork: false,
        privacySensitive: true,
        userVisibleFallback: true,
      ),
      EdgeTaskType.pretestReasoningGrade => const EdgeRouteDecision(
        target: EdgeRuntimeTarget.litertGemma4,
        reason: 'pretest_reasoning_grade_local_default',
        requiresNetwork: false,
        privacySensitive: true,
        userVisibleFallback: true,
      ),
      EdgeTaskType.quizGenerate => const EdgeRouteDecision(
        target: EdgeRuntimeTarget.litertGemma4,
        reason: 'quiz_generation_local_default',
        requiresNetwork: false,
        privacySensitive: false,
        userVisibleFallback: true,
      ),
      EdgeTaskType.summaryGenerate => const EdgeRouteDecision(
        target: EdgeRuntimeTarget.litertGemma4,
        reason: 'summary_generation_local_default',
        requiresNetwork: false,
        privacySensitive: true,
        userVisibleFallback: true,
      ),
    };
  }

  EdgeRouteAudit _audit({
    required String runtimeTarget,
    required String modelId,
    required String executionLocation,
    required bool networkRequired,
    required bool fallbackUsed,
    required String routeReason,
    required int latencyMs,
    required int inputChars,
    required int outputChars,
  }) {
    return EdgeRouteAudit(
      runtimeTarget: runtimeTarget,
      modelId: modelId,
      executionLocation: executionLocation,
      networkRequired: networkRequired,
      fallbackUsed: fallbackUsed,
      routeReason: routeReason,
      latencyMs: latencyMs,
      inputChars: inputChars,
      outputChars: outputChars,
      createdAtIso8601: DateTime.now().toUtc().toIso8601String(),
    );
  }

  String _routeReasonWithError({required String base, required Object error}) {
    final raw = error.toString().replaceAll('\n', ' ').trim();
    if (raw.isEmpty) {
      return base;
    }
    final compact = raw.length > 80 ? '${raw.substring(0, 80)}...' : raw;
    return '$base:$compact';
  }
}
