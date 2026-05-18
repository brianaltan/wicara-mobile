import '../../../core/network/api_client.dart';
import '../../auth/data/auth_session_store.dart';
import '../domain/workspace_models.dart';
import '../domain/workspace_repository.dart';
import 'workspace_session_store.dart' as store;

class ApiWorkspaceRepository implements WorkspaceRepository {
  const ApiWorkspaceRepository({
    required ApiClient apiClient,
    required AuthSessionStore sessionStore,
    required store.WorkspaceSessionStore workspaceSessionStore,
  }) : _apiClient = apiClient,
       _sessionStore = sessionStore,
       _workspaceSessionStore = workspaceSessionStore;

  final ApiClient _apiClient;
  final AuthSessionStore _sessionStore;
  final store.WorkspaceSessionStore _workspaceSessionStore;

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
      return workspaceFromJson(json);
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
      final json = await _apiClient.postJson(
        '/api/v1/workspaces/$workspaceId/events',
        headers: {'Authorization': 'Bearer $token'},
        body: {
          'event_type': eventType,
          'actor_type': 'learner',
          'text_payload': textPayload,
          'metadata': metadata,
        },
      );
      return appendResultFromJson(json);
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
