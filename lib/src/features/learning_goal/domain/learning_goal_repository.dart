class LearningGoalException implements Exception {
  const LearningGoalException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LearningGoalBootstrap {
  const LearningGoalBootstrap({
    required this.learningGoalId,
    this.pretestSessionId,
    this.trackId,
  });

  final String learningGoalId;
  final String? pretestSessionId;
  final String? trackId;
}

class LearningConceptSuggestion {
  const LearningConceptSuggestion({
    required this.conceptId,
    required this.conceptCode,
    required this.title,
    required this.subject,
    this.description = '',
    this.subjectCode = '',
    this.gradeBand,
    this.gradeRelation,
    this.levelNote,
    this.confidence,
  });

  final String conceptId;
  final String conceptCode;
  final String title;
  final String subject;
  final String description;
  final String subjectCode;
  final String? gradeBand;
  final String? gradeRelation;
  final String? levelNote;
  final double? confidence;
}

class LearningGoalResolution {
  const LearningGoalResolution({
    required this.resolutionId,
    required this.status,
    required this.confidence,
    this.suggestedConcept,
    this.clarificationQuestion,
    this.alternatives = const [],
    this.searchScope = '',
    this.searchScopeReason,
    this.graphFocusCodes = const [],
    this.graphSubjectCode,
  });

  final String resolutionId;
  final String status;
  final double confidence;
  final LearningConceptSuggestion? suggestedConcept;
  final String? clarificationQuestion;
  final List<LearningConceptSuggestion> alternatives;
  final String searchScope;
  final String? searchScopeReason;
  final List<String> graphFocusCodes;
  final String? graphSubjectCode;
}

class ActiveLearningGoal {
  const ActiveLearningGoal({
    required this.id,
    required this.status,
    required this.rawTopic,
    required this.nextAction,
    this.targetConcept,
    this.pretestSessionId,
    this.trackId,
  });

  final String id;
  final String status;
  final String rawTopic;
  final String nextAction;
  final LearningConceptSuggestion? targetConcept;
  final String? pretestSessionId;
  final String? trackId;
}

abstract class LearningGoalRepository {
  Future<ActiveLearningGoal?> fetchActiveGoal();

  Future<LearningGoalResolution> resolveLearningGoal({
    required String rawQuery,
    String? subjectCode,
    String? educationLevel,
    String? gradeLevel,
    String? language,
  });

  Future<LearningGoalBootstrap> confirmResolvedGoal({
    required String resolutionId,
  });

  Future<LearningGoalResolution> selectResolvedConcept({
    required String resolutionId,
    required String conceptId,
  });

  Future<LearningGoalBootstrap> createLearningGoal({required String rawTopic});

  Future<List<LearningConceptSuggestion>> searchMaterials({
    required String query,
    String? subjectCode,
  });

  Future<void> cancelGoal({required String learningGoalId});
}
