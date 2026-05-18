class LocalTrackDraft {
  const LocalTrackDraft({
    required this.trackId,
    required this.learningGoalId,
    required this.conceptCode,
    required this.conceptTitle,
    required this.subjectCode,
    required this.moduleId,
    required this.moduleTitle,
    required this.createdAtIso,
  });

  final String trackId;
  final String learningGoalId;
  final String conceptCode;
  final String conceptTitle;
  final String subjectCode;
  final String moduleId;
  final String moduleTitle;
  final String createdAtIso;
}

class PretestSessionStore {
  String? learningGoalId;
  String? pretestSessionId;
  String? trackId;
  String? targetConceptCode;
  String? targetSubjectCode;
  final List<LocalTrackDraft> localTrackHistory = <LocalTrackDraft>[];

  void saveBootstrap({
    required String learningGoalId,
    String? pretestSessionId,
    String? trackId,
    String? targetConceptCode,
    String? targetSubjectCode,
  }) {
    final previousGoalId = this.learningGoalId;
    this.learningGoalId = learningGoalId;
    this.pretestSessionId = pretestSessionId;
    this.trackId = trackId;
    if (previousGoalId != null &&
        previousGoalId.isNotEmpty &&
        previousGoalId != learningGoalId) {
      this.targetConceptCode = null;
      this.targetSubjectCode = null;
    }
    if ((targetConceptCode ?? '').trim().isNotEmpty) {
      this.targetConceptCode = targetConceptCode!.trim();
    }
    if ((targetSubjectCode ?? '').trim().isNotEmpty) {
      this.targetSubjectCode = targetSubjectCode!.trim();
    }
  }

  void clear() {
    learningGoalId = null;
    pretestSessionId = null;
    trackId = null;
    targetConceptCode = null;
    targetSubjectCode = null;
  }

  void upsertLocalTrack(LocalTrackDraft draft) {
    localTrackHistory.removeWhere((item) => item.trackId == draft.trackId);
    localTrackHistory.insert(0, draft);
  }
}

final pretestSessionStore = PretestSessionStore();
