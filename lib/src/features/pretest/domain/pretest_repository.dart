import 'pretest_models.dart';

class PretestException implements Exception {
  const PretestException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class PretestRepository {
  Future<PretestQuestion> fetchCurrentQuestion();

  Future<PretestAnswerResult> submitAnswer(PretestAnswer answer);

  Future<KnowledgeState> selectPath(String pathOption);
}
