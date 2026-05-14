import '../../../core/network/api_client.dart';
import '../../auth/data/auth_session_store.dart';
import '../domain/workspace_models.dart';
import '../domain/workspace_repository.dart';
import 'workspace_session_store.dart';

class ApiWorkspaceRepository implements WorkspaceRepository {
  const ApiWorkspaceRepository({
    required ApiClient apiClient,
    required AuthSessionStore sessionStore,
    required WorkspaceSessionStore workspaceSessionStore,
  }) : _apiClient = apiClient,
       _sessionStore = sessionStore,
       _workspaceSessionStore = workspaceSessionStore;

  final ApiClient _apiClient;
  final AuthSessionStore _sessionStore;
  final WorkspaceSessionStore _workspaceSessionStore;

  @override
  Future<WorkspaceSession> createOrResumeWorkspace({
    required String trackId,
    required String moduleId,
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
        },
      );
      final workspace = workspaceFromJson(json);
      await _workspaceSessionStore.save(
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

WorkspaceSession workspaceFromJson(Map<String, dynamic> json) {
  final events = json['events'];
  return WorkspaceSession(
    id: _string(json['id']),
    trackId: _string(json['track_id']),
    moduleId: _string(json['module_id']),
    currentTopic: _string(json['current_topic']),
    contentMode: _string(json['content_mode']),
    status: _string(json['status']),
    events: events is List
        ? events
              .whereType<Map<String, dynamic>>()
              .map(workspaceEventFromJson)
              .toList(growable: false)
        : const [],
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

int? _intOrNull(Object? value) => int.tryParse((value ?? '').toString());

double? _doubleOrNull(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse((value ?? '').toString());
}
