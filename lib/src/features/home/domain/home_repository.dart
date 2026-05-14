import 'home_snapshot.dart';

abstract class HomeRepository {
  Future<HomeSnapshot> fetchSnapshot();

  Future<DailyEvaluationSession> fetchDailyEvaluation();

  Future<void> submitDailyEvaluationAnswer({
    required String sessionId,
    required String questionId,
    required String optionId,
    required int confidence,
  });
}
