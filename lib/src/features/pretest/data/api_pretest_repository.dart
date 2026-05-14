import '../../../core/network/api_client.dart';
import '../../auth/data/auth_session_store.dart';
import '../domain/pretest_models.dart';
import '../domain/pretest_repository.dart';
import 'pretest_session_store.dart';

class ApiPretestRepository implements PretestRepository {
  const ApiPretestRepository({
    required ApiClient apiClient,
    required AuthSessionStore sessionStore,
    required PretestSessionStore pretestSessionStore,
  }) : _apiClient = apiClient,
       _sessionStore = sessionStore,
       _pretestSessionStore = pretestSessionStore;

  final ApiClient _apiClient;
  final AuthSessionStore _sessionStore;
  final PretestSessionStore _pretestSessionStore;

  @override
  Future<PretestQuestion> fetchCurrentQuestion() async {
    final token = _requireToken();
    final learningGoalId = _pretestSessionStore.learningGoalId;
    if (learningGoalId == null || learningGoalId.isEmpty) {
      throw const PretestException(
        'Create a learning goal before opening the pretest.',
      );
    }

    try {
      final json = await _apiClient.getJson(
        '/api/v1/pretests/$learningGoalId',
        headers: {'Authorization': 'Bearer $token'},
      );
      _pretestSessionStore.pretestSessionId = _string(json['session_id']);
      final questions = json['questions'];
      if (questions is! List || questions.isEmpty) {
        throw const PretestException('Backend returned no pretest questions.');
      }
      final first = questions.first;
      if (first is! Map<String, dynamic>) {
        throw const PretestException(
          'Backend returned an invalid pretest question.',
        );
      }
      return questionFromJson(first);
    } on PretestException {
      rethrow;
    } on ApiClientException catch (error) {
      throw PretestException(error.message);
    }
  }

  @override
  Future<void> submitAnswer(PretestAnswer answer) async {
    final token = _requireToken();
    final sessionId = _requirePretestSessionId();
    if (answer.optionId.isEmpty) {
      throw const PretestException('Choose an answer before continuing.');
    }

    try {
      await _apiClient.postJson(
        '/api/v1/pretests/$sessionId/answers',
        headers: {'Authorization': 'Bearer $token'},
        body: {
          'question_id': answer.questionId,
          'option_id': answer.optionId,
          'confidence': answer.confidence,
        },
      );
    } on ApiClientException catch (error) {
      throw PretestException(error.message);
    }
  }

  @override
  Future<KnowledgeState> submitReasoning(PretestReasoning reasoning) async {
    final token = _requireToken();
    final sessionId = _requirePretestSessionId();
    if (reasoning.explanation.trim().isEmpty && !reasoning.usedCanvas) {
      throw const PretestException('Share your reasoning or sketch it first.');
    }

    try {
      final json = await _apiClient.postJson(
        '/api/v1/pretests/$sessionId/reasoning',
        headers: {'Authorization': 'Bearer $token'},
        body: {
          'question_id': reasoning.answer.questionId,
          'option_id': reasoning.answer.optionId,
          'confidence': reasoning.answer.confidence,
          'explanation': reasoning.explanation,
          'used_canvas': reasoning.usedCanvas,
        },
      );
      return KnowledgeState(
        skill: _string(json['skill']),
        gapLabel: _string(json['gap_label']),
        message: _string(json['message']),
        pathTitle: _string(json['path_title']),
        pathMeta: _string(json['path_meta']),
        pathDescription: _string(json['path_description']),
      );
    } on ApiClientException catch (error) {
      throw PretestException(error.message);
    }
  }

  String _requireToken() {
    final token = _sessionStore.accessToken;
    if (token == null || token.isEmpty) {
      throw const PretestException('Please log in before taking the pretest.');
    }
    return token;
  }

  String _requirePretestSessionId() {
    final sessionId = _pretestSessionStore.pretestSessionId;
    if (sessionId == null || sessionId.isEmpty) {
      throw const PretestException(
        'Open a generated pretest before submitting.',
      );
    }
    return sessionId;
  }
}

PretestQuestion questionFromJson(Map<String, dynamic> json) {
  final options = json['options'];
  return PretestQuestion(
    id: _string(json['id']),
    stepLabel: _string(json['step_label']),
    topic: _string(json['topic']),
    prompt: _string(json['prompt']),
    helper: _string(json['helper']),
    options: options is List
        ? options
              .whereType<Map<String, dynamic>>()
              .map(
                (option) => PretestOption(
                  id: _string(option['id']),
                  label: _string(option['label']),
                  text: _string(option['text']),
                ),
              )
              .toList(growable: false)
        : const [],
  );
}

String _string(Object? value) => (value ?? '').toString().trim();
