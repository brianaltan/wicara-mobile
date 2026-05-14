import 'pretest_models.dart';

class PretestException implements Exception {
  const PretestException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class PretestRepository {
  Future<PretestQuestion> fetchCurrentQuestion();

  Future<void> submitAnswer(PretestAnswer answer);

  Future<KnowledgeState> submitReasoning(PretestReasoning reasoning);
}
