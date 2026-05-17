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

class WorkspaceCompletionResult {
  const WorkspaceCompletionResult({
    required this.trackId,
    required this.moduleId,
    required this.moduleTitle,
  });

  final String trackId;
  final String moduleId;
  final String moduleTitle;
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
    this.latestMedia,
  });

  final String id;
  final String trackId;
  final String moduleId;
  final String currentTopic;
  final String contentMode;
  final String status;
  final List<WorkspaceEvent> events;
  final WorkspaceMediaArtifact? latestMedia;
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

class WorkspaceMediaArtifact {
  const WorkspaceMediaArtifact({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.durationSeconds,
    required this.durationLabel,
    required this.transcript,
    required this.notes,
    this.thumbnailUrl,
    this.videoUrl,
    this.playbackUrl,
    this.createdAt,
  });

  final String id;
  final String title;
  final String subtitle;
  final String status;
  final int durationSeconds;
  final String durationLabel;
  final String transcript;
  final List<String> notes;
  final String? thumbnailUrl;
  final String? videoUrl;
  final String? playbackUrl;
  final String? createdAt;

  bool get isReady => status.toLowerCase() == 'ready';
}

class WorkspaceAnimationQueue {
  const WorkspaceAnimationQueue({
    required this.jobId,
    required this.artifactId,
    required this.status,
    this.errorDetails,
  });

  final String jobId;
  final String artifactId;
  final String status;
  final Map<String, dynamic>? errorDetails;
}

class WorkspaceGenerateVideoResult {
  const WorkspaceGenerateVideoResult({
    required this.queue,
    required this.event,
    required this.workspace,
  });

  final WorkspaceAnimationQueue queue;
  final WorkspaceEvent event;
  final WorkspaceSession workspace;
}

class WorkspaceAnimationJobStatus {
  const WorkspaceAnimationJobStatus({
    required this.jobId,
    required this.status,
    required this.progress,
    required this.message,
    required this.artifactId,
    this.videoUrl,
    this.thumbnailUrl,
    this.error,
    this.errorDetails,
  });

  final String jobId;
  final String status;
  final int progress;
  final String message;
  final String artifactId;
  final String? videoUrl;
  final String? thumbnailUrl;
  final String? error;
  final Map<String, dynamic>? errorDetails;

  bool get isQueued => status == 'queued';
  bool get isProcessing => status == 'processing' || isQueued;
  bool get isReady => status == 'ready';
  bool get isFailed => status == 'failed';
  bool get isFinal => isReady || isFailed;
}
