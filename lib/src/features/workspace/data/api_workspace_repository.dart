import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_session_store.dart';
import '../../edge_ai/domain/edge_model_router.dart';
import '../domain/local_5e_orchestrator.dart';
import '../domain/workspace_models.dart';
import '../domain/workspace_repository.dart';
import 'workspace_session_store.dart' as store;

class ApiWorkspaceRepository implements WorkspaceRepository {
  const ApiWorkspaceRepository({
    required ApiClient apiClient,
    required AuthSessionStore sessionStore,
    required store.WorkspaceSessionStore workspaceSessionStore,
    this.edgeModelRouter = const EdgeModelRouter(),
    this.edgeForceLocalForPilot = true,
    this.edgeCloudFallbackAllowed = false,
    this.edgeDebugRouteTrace = false,
  }) : _apiClient = apiClient,
       _sessionStore = sessionStore,
       _workspaceSessionStore = workspaceSessionStore;

  final ApiClient _apiClient;
  final AuthSessionStore _sessionStore;
  final store.WorkspaceSessionStore _workspaceSessionStore;
  final EdgeModelRouter edgeModelRouter;
  final bool edgeForceLocalForPilot;
  final bool edgeCloudFallbackAllowed;
  final bool edgeDebugRouteTrace;
  static const Local5EOrchestrator _orchestrator = Local5EOrchestrator();
  static final Map<String, WorkspaceSession> _workspaceCacheById =
      <String, WorkspaceSession>{};

  @override
  Future<WorkspaceSession> createOrResumeWorkspace({
    required String trackId,
    required String moduleId,
    String? workspaceSessionId,
    bool startNewSession = false,
  }) async {
    final token = _requireToken();
    try {
      final json = await _apiClient.postJson(
        '/api/v1/workspaces',
        headers: {'Authorization': 'Bearer $token'},
        body: {
          'track_id': trackId,
          'module_id': moduleId,
          'content_mode': 'chat',
          'workspace_session_id': _nullableString(workspaceSessionId),
          'start_new_session': startNewSession,
        },
      );
      final workspace = workspaceFromJson(json);
      _rememberWorkspace(workspace);
      await _workspaceSessionStore.saveAndSetActive(
        trackId: trackId,
        moduleId: moduleId,
        workspaceId: workspace.id,
      );
      return workspace;
    } on ApiClientException catch (error) {
      throw WorkspaceException(error.message);
    }
  }

  @override
  WorkspaceSessionHistory sessionHistory({
    required String trackId,
    required String moduleId,
  }) {
    final history = _workspaceSessionStore.sessionHistoryFor(
      trackId: trackId,
      moduleId: moduleId,
    );
    return WorkspaceSessionHistory(
      activeWorkspaceId: history.activeWorkspaceId,
      workspaceIds: history.workspaceIds,
    );
  }

  @override
  Future<void> setActiveSession({
    required String trackId,
    required String moduleId,
    required String workspaceId,
  }) {
    return _workspaceSessionStore.setActiveWorkspaceId(
      trackId: trackId,
      moduleId: moduleId,
      workspaceId: workspaceId,
    );
  }

  @override
  Future<List<WorkspaceSessionSummary>> fetchSessionHistory({
    required String trackId,
    required String moduleId,
  }) async {
    final token = _requireToken();
    try {
      final json = await _apiClient.getJson(
        '/api/v1/workspaces',
        headers: {'Authorization': 'Bearer $token'},
        queryParameters: {'track_id': trackId, 'module_id': moduleId},
      );
      final sessions = json['sessions'];
      return sessions is List
          ? sessions
                .whereType<Map<String, dynamic>>()
                .map(workspaceSessionSummaryFromJson)
                .toList(growable: false)
          : const [];
    } on ApiClientException catch (error) {
      throw WorkspaceException(error.message);
    }
  }

  @override
  Future<WorkspaceSession> fetchWorkspace(String workspaceId) async {
    final token = _requireToken();
    try {
      final json = await _apiClient.getJson(
        '/api/v1/workspaces/$workspaceId',
        headers: {'Authorization': 'Bearer $token'},
      );
      final workspace = workspaceFromJson(json);
      _rememberWorkspace(workspace);
      return workspace;
    } on ApiClientException catch (error) {
      throw WorkspaceException(error.message);
    }
  }

  @override
  Future<WorkspaceAppendResult> appendEvent({
    required String workspaceId,
    required String eventType,
    String textPayload = '',
    Map<String, dynamic> metadata = const {},
  }) async {
    final token = _requireToken();
    try {
      final localTutor = await _generateLocalTutorOverride(
        workspaceId: workspaceId,
        eventType: eventType,
        textPayload: textPayload,
        metadata: metadata,
      );
      final requestMetadata = <String, dynamic>{
        ...metadata,
        if (localTutor != null) 'skip_server_tutor': true,
        if (localTutor != null)
          'client_tutor_override': localTutor.overrideJson,
        if (localTutor != null) 'client_5e_state': localTutor.orchestratorState,
        if (localTutor != null && edgeDebugRouteTrace)
          'client_edge_route_audit': localTutor.routeAudit,
      };
      final json = await _apiClient.postJson(
        '/api/v1/workspaces/$workspaceId/events',
        headers: {'Authorization': 'Bearer $token'},
        body: {
          'event_type': eventType,
          'actor_type': 'learner',
          'text_payload': textPayload,
          'metadata': requestMetadata,
        },
      );
      final backendResult = appendResultFromJson(json);
      _rememberWorkspace(backendResult.workspace);
      if (localTutor == null) {
        return backendResult;
      }
      return WorkspaceAppendResult(
        event: backendResult.event,
        workspace: backendResult.workspace,
        tutorResponse: localTutor.tutorResponse,
        masteryUpdate: backendResult.masteryUpdate,
      );
    } on ApiClientException catch (error) {
      throw WorkspaceException(error.message);
    }
  }

  @override
  Future<WorkspaceSession> advancePhase({
    required String workspaceId,
    bool force = false,
  }) async {
    final token = _requireToken();
    try {
      final json = await _apiClient.postJson(
        '/api/v1/workspaces/$workspaceId/advance-phase',
        headers: {'Authorization': 'Bearer $token'},
        queryParameters: {'force': force.toString()},
      );
      return workspaceFromJson(json);
    } on ApiClientException catch (error) {
      throw WorkspaceException(error.message);
    }
  }

  @override
  Future<WorkspaceSession> startPosttest({required String workspaceId}) async {
    final token = _requireToken();
    try {
      final json = await _apiClient.postJson(
        '/api/v1/workspaces/$workspaceId/start-posttest',
        headers: {'Authorization': 'Bearer $token'},
      );
      return workspaceFromJson(json);
    } on ApiClientException catch (error) {
      throw WorkspaceException(error.message);
    }
  }

  @override
  Future<WorkspaceGenerateVideoResult> generateVideo({
    required String workspaceId,
    String generationMode = 'context_auto',
    String? templateId,
    Map<String, dynamic>? specJson,
    String language = 'en',
    String qualityProfile = 'standard',
    String? conceptId,
    Map<String, dynamic> metadata = const {},
  }) async {
    final token = _requireToken();
    final normalizedMode = generationMode.trim().toLowerCase().replaceAll(
      '-',
      '_',
    );
    final requestBody = <String, dynamic>{
      'generation_mode': normalizedMode,
      'language': language,
      'quality_profile': qualityProfile,
      'metadata': metadata,
    };
    if (normalizedMode == 'manual') {
      final normalizedTemplate = _nullableString(templateId);
      if (normalizedTemplate == null) {
        throw const WorkspaceException(
          'template_id is required for manual video generation mode.',
        );
      }
      requestBody['template_id'] = normalizedTemplate;
      requestBody['spec_json'] = specJson ?? const <String, dynamic>{};
    }
    final normalizedConceptId = _nullableString(conceptId);
    if (normalizedConceptId != null) {
      requestBody['concept_id'] = normalizedConceptId;
    }

    try {
      final json = await _apiClient.postJson(
        '/api/v1/workspaces/$workspaceId/generate-video',
        headers: {'Authorization': 'Bearer $token'},
        body: requestBody,
      );
      return generateVideoResultFromJson(json);
    } on ApiClientException catch (error) {
      throw WorkspaceException(error.message);
    }
  }

  @override
  Future<WorkspaceAnimationJobStatus> getAnimationStatus({
    required String jobId,
  }) async {
    final token = _requireToken();
    try {
      final json = await _apiClient.getJson(
        '/api/v1/animation/status/$jobId',
        headers: {'Authorization': 'Bearer $token'},
      );
      return animationJobStatusFromJson(json);
    } on ApiClientException catch (error) {
      throw WorkspaceException(error.message);
    }
  }

  @override
  Future<void> updateModuleState({
    required String trackId,
    required String moduleId,
    required String status,
  }) async {
    final token = _requireToken();
    try {
      await _apiClient.patchJson(
        '/api/v1/tracks/$trackId/modules/$moduleId/state',
        headers: {'Authorization': 'Bearer $token'},
        body: {'status': status},
      );
    } on ApiClientException catch (error) {
      throw WorkspaceException(error.message);
    }
  }

  String _requireToken() {
    final token = _sessionStore.accessToken;
    if (token == null || token.isEmpty) {
      throw const WorkspaceException('Please log in before opening workspace.');
    }
    return token;
  }

  void _rememberWorkspace(WorkspaceSession workspace) {
    _workspaceCacheById[workspace.id] = workspace;
    _orchestrator.ensureState(
      workspaceId: workspace.id,
      backendCurrentPhase: workspace.currentPhase,
      backendPhaseTransitionPending: workspace.phaseTransitionPending,
      backendPosttestEligible: workspace.posttestEligible,
    );
  }

  WorkspaceSession? _cachedWorkspace(String workspaceId) {
    return _workspaceCacheById[workspaceId];
  }

  Future<_LocalTutorOverride?> _generateLocalTutorOverride({
    required String workspaceId,
    required String eventType,
    required String textPayload,
    required Map<String, dynamic> metadata,
  }) async {
    if (!edgeForceLocalForPilot) {
      return null;
    }
    final normalizedEventType = eventType.trim().toLowerCase();
    final workspace = _cachedWorkspace(workspaceId);
    final backendPhase = Local5EOrchestrator.normalizePhase(
      (workspace?.currentPhase ?? _nullableString(metadata['current_phase'])) ??
          'engage',
    );
    final backendPending =
        workspace?.phaseTransitionPending == true ||
        _bool(metadata['phase_transition_pending']);
    final backendPosttestEligible =
        workspace?.posttestEligible == true ||
        _bool(metadata['posttest_eligible']);
    final phaseState = _orchestrator.ensureState(
      workspaceId: workspaceId,
      backendCurrentPhase: backendPhase,
      backendPhaseTransitionPending: backendPending,
      backendPosttestEligible: backendPosttestEligible,
    );

    final task = _taskForPhase(
      phase: phaseState.currentPhase,
      eventType: normalizedEventType,
    );
    if (task == null) {
      return null;
    }

    final prompt = _localTutorPrompt(
      phaseState: phaseState,
      eventType: normalizedEventType,
      textPayload: textPayload,
      workspace: workspace,
      metadata: metadata,
    );
    final requestId =
        'workspace_local_tutor_${workspaceId}_${DateTime.now().microsecondsSinceEpoch}';
    final routeResult = await edgeModelRouter.routeAndGenerate(
      task: task,
      prompt: prompt,
      requestId: requestId,
      temperature: 0.25,
      maxTokens: 220,
      allowCloudFallback: edgeCloudFallbackAllowed,
    );
    final parsedBeforeTransition = _parseTutorOverridePayload(
      routeResult.text,
      phase: phaseState.currentPhase,
      normalizedEventType: normalizedEventType,
      textPayload: textPayload,
      metadata: metadata,
    );
    final transition = _orchestrator.applyTutorSignal(
      workspaceId: workspaceId,
      nextPhaseReady: parsedBeforeTransition.nextPhaseReady,
      phaseReasoning: parsedBeforeTransition.phaseReasoning,
      countLearnerTurn: _countsAsLearnerTurn(normalizedEventType),
    );
    final parsed = parsedBeforeTransition.copyWith(
      nextPhaseReady: transition.nextPhaseReady,
      phaseReasoning: transition.transitionReason,
      currentPhase: transition.phaseBefore,
    );
    final tutorResponse = WorkspaceTutorResponse(
      text: parsed.text,
      intent: parsed.intent,
      nextActions: parsed.nextActions,
      nextPhaseReady: parsed.nextPhaseReady,
      phaseReasoning: parsed.phaseReasoning,
    );
    final routeAudit = <String, dynamic>{
      ...routeResult.auditMetadata,
      'phase_before': transition.phaseBefore,
      'phase_after': transition.phaseAfter,
      'transition_pending': transition.phaseTransitionPending,
      'auto_advanced': transition.autoAdvanced,
      'transition_reason': transition.transitionReason,
      'model_output_raw': routeResult.text,
      'parsed_next_phase_ready': parsed.nextPhaseReady,
    };
    return _LocalTutorOverride(
      tutorResponse: tutorResponse,
      overrideJson: parsed.toJson(),
      orchestratorState: transition.state.toClientMetadata(),
      routeAudit: routeAudit,
    );
  }

  String _localTutorPrompt({
    required Local5EState phaseState,
    required String eventType,
    required String textPayload,
    required WorkspaceSession? workspace,
    required Map<String, dynamic> metadata,
  }) {
    final learnerText = textPayload.trim().isEmpty
        ? '(tidak ada teks eksplisit, lihat metadata event)'
        : textPayload.trim();
    final responseLanguage = _responseLanguageName(
      workspace?.learnerLanguage ??
          _nullableString(metadata['learner_language']),
    );
    final topic = _topicForPrompt(workspace);
    final history = _historyForPrompt(workspace);
    final phase = phaseState.currentPhase;
    final nextPhase =
        Local5EOrchestrator.nextPhaseCandidate(phase) ?? '(final)';
    final phaseInstruction = _phasePromptInstruction(
      phase: phase,
      isFirstPhaseTurn: phaseState.currentPhaseTurnCount <= 0,
      responseLanguage: responseLanguage,
    );
    final transitionCriteria = _phaseTransitionCriteria(phase);
    return '''
You are WICARA tutor for STEAM 5E learning.
Respond ONLY in $responseLanguage.
Keep response concise and tied to the student's latest message.
Do not produce long generic mini-lectures.
One clear pedagogical move per turn.

Current phase: $phase
Next phase candidate: $nextPhase
Topic: $topic
Event type: $eventType
Phase transition criteria: $transitionCriteria

Conversation summary:
$history

Latest learner message:
$learnerText

Phase instruction:
$phaseInstruction

Output MUST be valid JSON object only:
{
  "text": "1-3 concise sentences",
  "intent": "spark_curiosity|probe_understanding|explain|recommend_practice|evaluate_response|ask_followup|use_canvas_feedback",
  "next_actions": ["aksi_1","aksi_2"],
  "next_phase_ready": false,
  "phase_reasoning": "short reason for ready/not-ready"
}

Rules:
- If current phase is evaluate, always set next_phase_ready=false.
- If not ready, keep phase_reasoning specific to learner gap.
- Avoid repeating identical opening style.
Metadata event: ${jsonEncode(metadata)}
''';
  }

  _TutorOverridePayload _parseTutorOverridePayload(
    String raw, {
    required String phase,
    required String normalizedEventType,
    required String textPayload,
    required Map<String, dynamic> metadata,
  }) {
    final trimmed = raw.trim();
    final extracted = _extractJsonObject(trimmed);
    if (extracted != null) {
      try {
        final decoded = jsonDecode(extracted);
        if (decoded is Map<String, dynamic>) {
          final text = _string(decoded['text']);
          final fallbackText = text.isEmpty
              ? _deterministicTutorText(
                  phase: phase,
                  eventType: normalizedEventType,
                  textPayload: textPayload,
                )
              : text;
          final intent = _string(decoded['intent']).isNotEmpty
              ? _string(decoded['intent'])
              : _defaultIntentForPhase(phase, normalizedEventType);
          final nextActions = _stringList(decoded['next_actions']);
          final fallbackActions = nextActions.isEmpty
              ? _defaultNextActionsForPhase(phase, intent: intent)
              : nextActions;
          final parsedReady =
              _bool(decoded['next_phase_ready']) ||
              _heuristicNextPhaseReady(
                phase: phase,
                eventType: normalizedEventType,
                metadata: metadata,
                learnerText: textPayload,
                tutorText: fallbackText,
              );
          final nextPhaseReady = phase == 'evaluate' ? false : parsedReady;
          final phaseReasoning =
              _nullableString(decoded['phase_reasoning']) ??
              (nextPhaseReady
                  ? 'learner_signals_ready_for_next_phase'
                  : 'needs_more_guided_progress_in_current_phase');
          return _TutorOverridePayload(
            currentPhase: phase,
            text: fallbackText,
            intent: intent,
            nextActions: fallbackActions,
            nextPhaseReady: nextPhaseReady,
            phaseReasoning: phaseReasoning,
          );
        }
      } catch (_) {
        // Fall through to deterministic payload.
      }
    }

    final text = _deterministicTutorText(
      phase: phase,
      eventType: normalizedEventType,
      textPayload: textPayload,
    );
    final intent = _defaultIntentForPhase(phase, normalizedEventType);
    final parsedReady = _heuristicNextPhaseReady(
      phase: phase,
      eventType: normalizedEventType,
      metadata: metadata,
      learnerText: textPayload,
      tutorText: text,
    );
    final nextPhaseReady = phase == 'evaluate' ? false : parsedReady;
    return _TutorOverridePayload(
      currentPhase: phase,
      text: text,
      intent: intent,
      nextActions: _defaultNextActionsForPhase(phase, intent: intent),
      nextPhaseReady: nextPhaseReady,
      phaseReasoning: nextPhaseReady
          ? 'local_fallback_detected_ready_for_next_phase'
          : 'local_fallback_not_ready_for_phase_transition',
    );
  }

  EdgeTaskType? _taskForPhase({
    required String phase,
    required String eventType,
  }) {
    if (eventType == 'canvas_sent') {
      return EdgeTaskType.tutorHint;
    }
    if (eventType == 'quiz_answer' || phase == 'evaluate') {
      return EdgeTaskType.tutorEvaluate;
    }
    if (phase == 'explore') {
      return EdgeTaskType.tutorHint;
    }
    return EdgeTaskType.tutorExplain;
  }

  String _phasePromptInstruction({
    required String phase,
    required bool isFirstPhaseTurn,
    required String responseLanguage,
  }) {
    return switch (phase) {
      'engage' =>
        'Activate prior knowledge with one focused question. ${isFirstPhaseTurn ? 'You may use one brief real-world hook.' : 'Do not restart with a generic new scenario.'} Do not explain full concept yet.',
      'explore' =>
        'Give one mini challenge or micro experiment. Ask learner to observe and respond.',
      'explain' =>
        'Explain concept based on learner message, concise and concrete, with one check-in question.',
      'elaborate' =>
        'Give one application case in a new context and ask for short reasoning.',
      'evaluate' =>
        'Check understanding, give feedback, and one clear next step. Keep it short.',
      _ => 'Respond as a concise Socratic tutor in $responseLanguage.',
    };
  }

  String _phaseTransitionCriteria(String phase) {
    return switch (phase) {
      'engage' =>
        'Learner shows initial curiosity/prior knowledge and is ready for discovery task.',
      'explore' =>
        'Learner attempts exploration and shares observation, ready for explicit explanation.',
      'explain' =>
        'Learner restates key concept and connects to one worked idea/example.',
      'elaborate' =>
        'Learner applies concept to new case with reasonable reasoning.',
      'evaluate' => 'Final phase, keep next_phase_ready=false.',
      _ => 'Use pedagogical judgement based on learner readiness.',
    };
  }

  String _topicForPrompt(WorkspaceSession? workspace) {
    final topic = (workspace?.currentTopic ?? '').trim();
    return topic.isEmpty ? 'this module topic' : topic;
  }

  String _historyForPrompt(WorkspaceSession? workspace, {int maxTurns = 10}) {
    final events = workspace?.events ?? const <WorkspaceEvent>[];
    if (events.isEmpty) {
      return '(no prior conversation)';
    }
    final start = events.length > maxTurns * 2
        ? events.length - maxTurns * 2
        : 0;
    final lines = <String>[];
    for (final event in events.skip(start)) {
      final text = event.textPayload.trim();
      if (text.isEmpty) {
        continue;
      }
      final role = event.actorType == 'learner' ? 'Student' : 'Tutor';
      lines.add('$role: $text');
    }
    return lines.isEmpty ? '(no prior conversation)' : lines.join('\n');
  }

  String? _extractJsonObject(String raw) {
    if (raw.isEmpty) {
      return null;
    }
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) {
      return null;
    }
    return raw.substring(start, end + 1);
  }

  bool _heuristicNextPhaseReady({
    required String phase,
    required String eventType,
    required Map<String, dynamic> metadata,
    required String learnerText,
    required String tutorText,
  }) {
    if (phase == 'evaluate') {
      return false;
    }
    if (eventType == 'quiz_answer' && metadata['is_correct'] == true) {
      return true;
    }
    final learnerWordCount = learnerText
        .trim()
        .split(RegExp(r'\s+'))
        .where((token) => token.trim().isNotEmpty)
        .length;
    if (eventType == 'text' && learnerWordCount >= 7) {
      return true;
    }
    final normalized = tutorText.toLowerCase();
    return normalized.contains('lanjut ke fase berikut') ||
        normalized.contains('siap lanjut') ||
        normalized.contains('ready untuk fase berikut');
  }

  String _defaultIntentForPhase(String phase, String eventType) {
    if (eventType == 'canvas_sent') {
      return 'use_canvas_feedback';
    }
    return switch (phase) {
      'engage' => 'spark_curiosity',
      'explore' => 'probe_understanding',
      'explain' => 'explain',
      'elaborate' => 'recommend_practice',
      'evaluate' => 'evaluate_response',
      _ => 'ask_followup',
    };
  }

  List<String> _defaultNextActionsForPhase(
    String phase, {
    required String intent,
  }) {
    final normalizedIntent = intent.trim().toLowerCase();
    if (normalizedIntent == 'use_canvas_feedback') {
      return const ['refine_canvas', 'explain_steps'];
    }
    return switch (phase) {
      'engage' => const ['explore_topic', 'ask_question', 'use_canvas'],
      'explore' => const ['try_answer', 'ask_clarification', 'use_canvas'],
      'explain' => const ['summarize', 'answer_quiz', 'use_canvas'],
      'elaborate' => const ['apply_concept', 'answer_quiz'],
      'evaluate' => const [
        'review_explanation',
        'retry_quiz',
        'continue_next_module',
      ],
      _ => const ['ask_followup'],
    };
  }

  String _deterministicTutorText({
    required String phase,
    required String eventType,
    required String textPayload,
  }) {
    final learnerText = textPayload.trim();
    if (learnerText.isEmpty && eventType == 'canvas_sent') {
      return 'Canvas kamu sudah terekam. Jelaskan satu langkah utama yang kamu pakai, lalu kita cek bareng.';
    }
    if (phase == 'evaluate' || eventType == 'quiz_answer') {
      return 'Bagus, sekarang jelaskan kenapa pilihanmu masuk akal dalam satu langkah inti.';
    }
    if (phase == 'engage') {
      return 'Oke, kita mulai dari pemahaman awalmu. Menurutmu bagian mana dari konsep ini yang paling bikin bingung?';
    }
    if (phase == 'explore') {
      return 'Coba lakukan satu percobaan kecil dari idemu tadi, lalu ceritakan observasi utamanya.';
    }
    if (phase == 'explain') {
      return 'Mari kita rapikan konsepnya dari jawabanmu: jelaskan inti idemu dalam satu aturan sederhana.';
    }
    if (phase == 'elaborate') {
      return 'Sekarang terapkan konsep ini ke kasus baru yang mirip, lalu jelaskan langkah pertamamu.';
    }
    return learnerText.isEmpty
        ? 'Ayo lanjut. Sebutkan satu hal yang masih membingungkan supaya kita pecah jadi langkah kecil.'
        : learnerText;
  }

  String _responseLanguageName(String? languageCode) {
    final normalized = _string(languageCode).toLowerCase().replaceAll('_', '-');
    if (normalized == 'id' ||
        normalized == 'id-id' ||
        normalized == 'indonesian' ||
        normalized == 'bahasa-indonesia') {
      return 'Bahasa Indonesia';
    }
    return 'English';
  }

  bool _countsAsLearnerTurn(String eventType) {
    return eventType == 'text' ||
        eventType == 'quiz_answer' ||
        eventType == 'canvas_sent';
  }
}

WorkspaceSessionSummary workspaceSessionSummaryFromJson(
  Map<String, dynamic> json,
) {
  return WorkspaceSessionSummary(
    id: _string(json['id']),
    trackId: _string(json['track_id']),
    moduleId: _string(json['module_id']),
    title: _string(json['title']),
    preview: _string(json['preview']),
    messageCount: _int(json['message_count']),
    createdAt: _string(json['created_at']),
    updatedAt: _string(json['updated_at']),
  );
}

WorkspaceSession workspaceFromJson(Map<String, dynamic> json) {
  final events = json['events'];
  final latestMedia = json['latest_media'];
  final learnerLanguage = _string(json['learner_language']);
  return WorkspaceSession(
    id: _string(json['id']),
    trackId: _string(json['track_id']),
    moduleId: _string(json['module_id']),
    currentTopic: _string(json['current_topic']),
    currentTopicDescription: _string(json['current_topic_description']),
    learnerLanguage: learnerLanguage.isEmpty ? 'en' : learnerLanguage,
    contentMode: _string(json['content_mode']),
    status: _string(json['status']),
    currentPhase: _string(json['current_phase']).isNotEmpty
        ? _string(json['current_phase'])
        : 'engage',
    phaseTransitionPending: _bool(json['phase_transition_pending']),
    posttestEligible: _bool(json['posttest_eligible']),
    events: events is List
        ? events
              .whereType<Map<String, dynamic>>()
              .map(workspaceEventFromJson)
              .toList(growable: false)
        : const [],
    latestMedia: latestMedia is Map<String, dynamic>
        ? workspaceMediaArtifactFromJson(latestMedia)
        : null,
  );
}

WorkspaceEvent workspaceEventFromJson(Map<String, dynamic> json) {
  final metadata = json['metadata'];
  return WorkspaceEvent(
    id: _string(json['id']),
    workspaceId: _string(json['workspace_id']),
    eventIndex: _int(json['event_index']),
    eventType: _string(json['event_type']),
    actorType: _string(json['actor_type']),
    textPayload: _string(json['text_payload']),
    metadata: metadata is Map<String, dynamic> ? metadata : const {},
  );
}

WorkspaceAppendResult appendResultFromJson(Map<String, dynamic> json) {
  final tutorResponse = json['tutor_response'];
  final masteryUpdate = json['mastery_update'];
  return WorkspaceAppendResult(
    event: workspaceEventFromJson(_map(json['event'])),
    tutorResponse: tutorResponse is Map<String, dynamic>
        ? WorkspaceTutorResponse(
            text: _string(tutorResponse['text']),
            intent: _string(tutorResponse['intent']),
            nextActions: _stringList(tutorResponse['next_actions']),
            nextPhaseReady: _bool(tutorResponse['next_phase_ready']),
            phaseReasoning: _nullableString(tutorResponse['phase_reasoning']),
          )
        : null,
    masteryUpdate: masteryUpdate is Map<String, dynamic>
        ? WorkspaceMasteryUpdate(
            conceptId: _nullableString(masteryUpdate['concept_id']),
            masteryScore: _doubleOrNull(masteryUpdate['mastery_score']),
            confidenceScore: _doubleOrNull(masteryUpdate['confidence_score']),
            evidenceCount: _intOrNull(masteryUpdate['evidence_count']),
            status: _nullableString(masteryUpdate['status']),
            delta: _doubleOrNull(masteryUpdate['delta']) ?? 0,
            reason: _string(masteryUpdate['reason']),
          )
        : null,
    workspace: workspaceFromJson(_map(json['workspace'])),
  );
}

WorkspaceGenerateVideoResult generateVideoResultFromJson(
  Map<String, dynamic> json,
) {
  return WorkspaceGenerateVideoResult(
    queue: workspaceAnimationQueueFromJson(_map(json['queue'])),
    event: workspaceEventFromJson(_map(json['event'])),
    workspace: workspaceFromJson(_map(json['workspace'])),
  );
}

WorkspaceAnimationQueue workspaceAnimationQueueFromJson(
  Map<String, dynamic> json,
) {
  final errorDetails = json['error_details'];
  return WorkspaceAnimationQueue(
    jobId: _string(json['job_id']),
    artifactId: _string(json['artifact_id']),
    status: _string(json['status']),
    errorDetails: errorDetails is Map<String, dynamic> ? errorDetails : null,
  );
}

WorkspaceAnimationJobStatus animationJobStatusFromJson(
  Map<String, dynamic> json,
) {
  final errorDetails = json['error_details'];
  return WorkspaceAnimationJobStatus(
    jobId: _string(json['job_id']),
    status: _string(json['status']),
    progress: _clampedProgress(json['progress']),
    message: _string(json['message']),
    artifactId: _string(json['artifact_id']),
    videoUrl: _nullableString(json['video_url']),
    thumbnailUrl: _nullableString(json['thumbnail_url']),
    error: _nullableString(json['error']),
    errorDetails: errorDetails is Map<String, dynamic> ? errorDetails : null,
  );
}

WorkspaceMediaArtifact workspaceMediaArtifactFromJson(
  Map<String, dynamic> json,
) {
  final notes = json['notes'];
  return WorkspaceMediaArtifact(
    id: _string(json['id']),
    title: _string(json['title']),
    subtitle: _string(json['subtitle']),
    status: _string(json['status']),
    durationSeconds: _int(json['duration_seconds']),
    durationLabel: _string(json['duration_label']),
    transcript: _string(json['transcript']),
    notes: notes is List
        ? notes.map((item) => _string(item)).toList(growable: false)
        : const [],
    thumbnailUrl: _nullableString(json['thumbnail_url']),
    videoUrl: _nullableString(json['video_url']),
    playbackUrl: _nullableString(json['playback_url']),
    createdAt: _nullableString(json['created_at']),
  );
}

Map<String, dynamic> _map(Object? value) {
  return value is Map<String, dynamic> ? value : const {};
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .map((item) => _string(item))
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String _string(Object? value) => (value ?? '').toString().trim();

String? _nullableString(Object? value) {
  final text = _string(value);
  return text.isEmpty ? null : text;
}

int _int(Object? value) => int.tryParse((value ?? '').toString()) ?? 0;

int _clampedProgress(Object? value) {
  final parsed = _int(value);
  if (parsed < 0) {
    return 0;
  }
  if (parsed > 100) {
    return 100;
  }
  return parsed;
}

int? _intOrNull(Object? value) => int.tryParse((value ?? '').toString());

double? _doubleOrNull(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse((value ?? '').toString());
}

bool _bool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final normalized = _string(value).toLowerCase();
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

class _LocalTutorOverride {
  const _LocalTutorOverride({
    required this.tutorResponse,
    required this.overrideJson,
    required this.orchestratorState,
    required this.routeAudit,
  });

  final WorkspaceTutorResponse tutorResponse;
  final Map<String, dynamic> overrideJson;
  final Map<String, dynamic> orchestratorState;
  final Map<String, dynamic> routeAudit;
}

class _TutorOverridePayload {
  const _TutorOverridePayload({
    required this.currentPhase,
    required this.text,
    required this.intent,
    required this.nextActions,
    required this.nextPhaseReady,
    required this.phaseReasoning,
  });

  final String currentPhase;
  final String text;
  final String intent;
  final List<String> nextActions;
  final bool nextPhaseReady;
  final String phaseReasoning;

  _TutorOverridePayload copyWith({
    String? currentPhase,
    String? text,
    String? intent,
    List<String>? nextActions,
    bool? nextPhaseReady,
    String? phaseReasoning,
  }) {
    return _TutorOverridePayload(
      currentPhase: currentPhase ?? this.currentPhase,
      text: text ?? this.text,
      intent: intent ?? this.intent,
      nextActions: nextActions ?? this.nextActions,
      nextPhaseReady: nextPhaseReady ?? this.nextPhaseReady,
      phaseReasoning: phaseReasoning ?? this.phaseReasoning,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_phase': currentPhase,
      'text': text,
      'intent': intent,
      'next_actions': nextActions,
      'next_phase_ready': nextPhaseReady,
      'phase_reasoning': phaseReasoning,
    };
  }
}
