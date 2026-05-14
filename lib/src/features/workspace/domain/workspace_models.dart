class WorkspaceRouteArguments {
  const WorkspaceRouteArguments({
    required this.trackId,
    required this.moduleId,
    this.moduleTitle,
  });

  final String trackId;
  final String moduleId;
  final String? moduleTitle;

  bool get isValid => trackId.isNotEmpty && moduleId.isNotEmpty;
}

class WorkspaceSession {
  const WorkspaceSession({
    required this.id,
    required this.trackId,
    required this.moduleId,
    required this.currentTopic,
    required this.contentMode,
    required this.status,
    required this.events,
  });

  final String id;
  final String trackId;
  final String moduleId;
  final String currentTopic;
  final String contentMode;
  final String status;
  final List<WorkspaceEvent> events;
}

class WorkspaceEvent {
  const WorkspaceEvent({
    required this.id,
    required this.workspaceId,
    required this.eventIndex,
    required this.eventType,
    required this.actorType,
    required this.textPayload,
    required this.metadata,
  });

  final String id;
  final String workspaceId;
  final int eventIndex;
  final String eventType;
  final String actorType;
  final String textPayload;
  final Map<String, dynamic> metadata;

  bool get isLearner => actorType == 'learner';
}

class WorkspaceTutorResponse {
  const WorkspaceTutorResponse({
    required this.text,
    required this.intent,
    required this.nextActions,
  });

  final String text;
  final String intent;
  final List<String> nextActions;
}

class WorkspaceMasteryUpdate {
  const WorkspaceMasteryUpdate({
    required this.reason,
    required this.delta,
    this.conceptId,
    this.masteryScore,
    this.confidenceScore,
    this.evidenceCount,
    this.status,
  });

  final String? conceptId;
  final double? masteryScore;
  final double? confidenceScore;
  final int? evidenceCount;
  final String? status;
  final double delta;
  final String reason;
}

class WorkspaceAppendResult {
  const WorkspaceAppendResult({
    required this.event,
    required this.workspace,
    this.tutorResponse,
    this.masteryUpdate,
  });

  final WorkspaceEvent event;
  final WorkspaceTutorResponse? tutorResponse;
  final WorkspaceMasteryUpdate? masteryUpdate;
  final WorkspaceSession workspace;
}
