import 'workspace_models.dart';

abstract class WorkspaceRepository {
  Future<WorkspaceSession> createOrResumeWorkspace({
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
