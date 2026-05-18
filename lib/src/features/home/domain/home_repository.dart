import 'home_snapshot.dart';

abstract class HomeRepository {
  Future<HomeSnapshot> fetchSnapshot();

  Future<List<HomeMediaArtifact>> fetchMediaArtifacts();

  Future<HomeMediaArtifact> fetchMediaArtifactById({
    required String artifactId,
  });

  Future<AssessmentDashboard> fetchAssessmentDashboard({
    required String learningGoalId,
  });

  Future<DailyEvaluationSession> fetchDailyEvaluation();

  Future<DailyEvaluationAnswerResult> submitDailyEvaluationAnswer({
    required String sessionId,
    required String questionId,
    required String optionId,
    required int confidence,
  });

  Future<DailyEvaluationResult> fetchDailyEvaluationResult({
    required String sessionId,
  });

  Future<DailyEvaluationSession> startPosttest({
    String? learningGoalId,
    String? trackId,
  });

  Future<DailyEvaluationAnswerResult> submitPosttestAnswer({
    required String sessionId,
    required String questionId,
    required String optionId,
    required int confidence,
    String typedReasoning = '',
    String? canvasAssetId,
    bool usedCanvas = false,
  });

  Future<AdaptivePosttestResult> finalizePosttest({required String sessionId});

  Future<WeeklyLearningReport> fetchWeeklyLearningReport({
    DateTime? start,
    DateTime? end,
  });
}
