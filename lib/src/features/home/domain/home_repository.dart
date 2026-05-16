import 'home_snapshot.dart';

abstract class HomeRepository {
  Future<HomeSnapshot> fetchSnapshot();

  Future<List<HomeMediaArtifact>> fetchMediaArtifacts();

  Future<HomeMediaArtifact> fetchMediaArtifactById({
    required String artifactId,
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

  Future<WeeklyLearningReport> fetchWeeklyLearningReport({
    DateTime? start,
    DateTime? end,
  });
}
