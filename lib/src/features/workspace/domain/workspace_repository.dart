import 'workspace_models.dart';

class WorkspaceSessionHistory {
  const WorkspaceSessionHistory({
    required this.activeWorkspaceId,
    required this.workspaceIds,
  });

  final String? activeWorkspaceId;
  final List<String> workspaceIds;
}

abstract class WorkspaceRepository {
  Future<WorkspaceSession> createOrResumeWorkspace({
    required String trackId,
    required String moduleId,
    String? workspaceSessionId,
    bool startNewSession = false,
  });

  WorkspaceSessionHistory sessionHistory({
    required String trackId,
    required String moduleId,
  });

  Future<void> setActiveSession({
    required String trackId,
    required String moduleId,
    required String workspaceId,
  });

  Future<List<WorkspaceSessionSummary>> fetchSessionHistory({
    required String trackId,
    required String moduleId,
  });

  Future<WorkspaceSession> fetchWorkspace(String workspaceId);

  Future<WorkspaceAppendResult> appendEvent({
    required String workspaceId,
    required String eventType,
    String textPayload = '',
    Map<String, dynamic> metadata = const {},
  });

  Future<WorkspaceSession> advancePhase({
    required String workspaceId,
    bool force = false,
  });

  Future<WorkspaceSession> startPosttest({required String workspaceId});

  Future<WorkspaceGenerateVideoResult> generateVideo({
    required String workspaceId,
    String generationMode = 'context_auto',
    String? templateId,
    Map<String, dynamic>? specJson,
    String language = 'en',
    String qualityProfile = 'standard',
    String? conceptId,
    Map<String, dynamic> metadata = const {},
  });

  Future<WorkspaceAnimationJobStatus> getAnimationStatus({
    required String jobId,
  });

  Future<void> updateModuleState({
    required String trackId,
    required String moduleId,
    required String status,
  });
}

class WorkspaceException implements Exception {
  const WorkspaceException(this.message);

  final String message;

  @override
  String toString() => message;
}
