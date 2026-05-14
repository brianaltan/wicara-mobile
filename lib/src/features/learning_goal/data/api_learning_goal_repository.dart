import '../../../core/network/api_client.dart';
import '../../auth/data/auth_session_store.dart';
import '../../pretest/data/pretest_session_store.dart';
import '../domain/learning_goal_repository.dart';

class ApiLearningGoalRepository implements LearningGoalRepository {
  const ApiLearningGoalRepository({
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
  Future<LearningGoalBootstrap> createLearningGoal({
    required String rawTopic,
  }) async {
    final token = _sessionStore.accessToken;
    if (token == null || token.isEmpty) {
      throw const LearningGoalException(
        'Please log in before creating a track.',
      );
    }

    try {
      final json = await _apiClient.postJson(
        '/api/v1/learning-goals',
        headers: {'Authorization': 'Bearer $token'},
        body: {'raw_topic': rawTopic.trim()},
      );
      final bootstrap = LearningGoalBootstrap(
        learningGoalId: _string(json['learning_goal_id']),
        pretestSessionId: _string(json['pretest_session_id']),
        trackId: _string(json['track_id']),
      );
      _pretestSessionStore.saveBootstrap(
        learningGoalId: bootstrap.learningGoalId,
        pretestSessionId: bootstrap.pretestSessionId,
        trackId: bootstrap.trackId,
      );
      return bootstrap;
    } on ApiClientException catch (error) {
      throw LearningGoalException(error.message);
    }
  }

  String _string(Object? value) => (value ?? '').toString().trim();
}
