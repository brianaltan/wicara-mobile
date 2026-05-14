class PretestSessionStore {
  String? learningGoalId;
  String? pretestSessionId;
  String? trackId;

  void saveBootstrap({
    required String learningGoalId,
    required String pretestSessionId,
    required String trackId,
  }) {
    this.learningGoalId = learningGoalId;
    this.pretestSessionId = pretestSessionId;
    this.trackId = trackId;
  }
}

final pretestSessionStore = PretestSessionStore();
