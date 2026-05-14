class LearningGoalException implements Exception {
  const LearningGoalException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LearningGoalBootstrap {
  const LearningGoalBootstrap({
    required this.learningGoalId,
    required this.pretestSessionId,
    required this.trackId,
  });

  final String learningGoalId;
  final String pretestSessionId;
  final String trackId;
}

abstract class LearningGoalRepository {
  Future<LearningGoalBootstrap> createLearningGoal({required String rawTopic});
}
