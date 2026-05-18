class PretestSessionStore {
  String? learningGoalId;
  String? pretestSessionId;
  String? trackId;
  String? targetConceptCode;
  String? targetSubjectCode;

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
}

final pretestSessionStore = PretestSessionStore();
