class PretestSessionStore {
  String? learningGoalId;
  String? pretestSessionId;
  String? trackId;

  void saveBootstrap({
    required String learningGoalId,
    String? pretestSessionId,
    String? trackId,
  }) {
    this.learningGoalId = learningGoalId;
    this.pretestSessionId = pretestSessionId;
    this.trackId = trackId;
  }

  void clear() {
    learningGoalId = null;
    pretestSessionId = null;
    trackId = null;
  }
}

final pretestSessionStore = PretestSessionStore();
