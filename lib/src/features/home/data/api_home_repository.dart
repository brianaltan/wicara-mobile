import '../../../core/network/api_client.dart';
import '../../auth/data/auth_session_store.dart';
import '../../pretest/data/api_pretest_repository.dart';
import '../domain/home_repository.dart';
import '../domain/home_snapshot.dart';

class ApiHomeRepository implements HomeRepository {
  const ApiHomeRepository({
    required ApiClient apiClient,
    required AuthSessionStore sessionStore,
  }) : _apiClient = apiClient,
       _sessionStore = sessionStore;

  final ApiClient _apiClient;
  final AuthSessionStore _sessionStore;

  @override
  Future<HomeSnapshot> fetchSnapshot() async {
    final token = _requireToken();

    final profileJson = await _apiClient.getJson(
      '/api/v1/me/profile',
      headers: {'Authorization': 'Bearer $token'},
    );
    final homeJson = await _apiClient.getJson(
      '/api/v1/home',
      headers: {'Authorization': 'Bearer $token'},
    );
    final subjectsJson = await _apiClient.getJson('/api/v1/subjects');
    final selectedSubjectCodes = _stringList(profileJson['selected_subjects']);
    final selectedSubjects = selectedSubjectCodes
        .map(_subjectKey)
        .toList(growable: false);

    return HomeSnapshot(
      displayName: _string(homeJson['display_name']).isNotEmpty
          ? _string(homeJson['display_name'])
          : (_string(profileJson['full_name']).isNotEmpty
                ? _string(profileJson['full_name'])
                : (_sessionStore.currentSession?.displayName ?? 'Learner')),
      streakDays: _int(homeJson['streak_days']),
      country: _string(profileJson['country_name']),
      educationLevel: _string(profileJson['education_level']),
      gradeLevel: _string(profileJson['grade_level']),
      preferredLanguage: _languageName(
        _string(profileJson['preferred_language']),
      ),
      studyGoal: _string(profileJson['study_goal']),
      dailyStudyTime: _string(profileJson['daily_study_time_label']),
      selectedSubjects: selectedSubjects,
      availableSubjects: _subjectKeys(subjectsJson),
      onboardingCompleted: profileJson['onboarding_completed'] == true,
      nextQueueItem: _queueItemOrNull(homeJson['next_queue_item']),
      activeTracks: _trackSummaries(homeJson['active_tracks']),
    );
  }

  @override
  Future<DailyEvaluationSession> fetchDailyEvaluation() async {
    final token = _requireToken();
    final json = await _apiClient.getJson(
      '/api/v1/daily-evaluations/today',
      headers: {'Authorization': 'Bearer $token'},
    );
    final questions = json['questions'];
    return DailyEvaluationSession(
      sessionId: _string(json['session_id']),
      questions: questions is List
          ? questions
                .whereType<Map<String, dynamic>>()
                .map(questionFromJson)
                .toList(growable: false)
          : const [],
    );
  }

  @override
  Future<void> submitDailyEvaluationAnswer({
    required String sessionId,
    required String questionId,
    required String optionId,
    required int confidence,
  }) async {
    final token = _requireToken();
    await _apiClient.postJson(
      '/api/v1/daily-evaluations/$sessionId/answers',
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'question_id': questionId,
        'option_id': optionId,
        'confidence': confidence,
      },
    );
  }

  List<String> _subjectKeys(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is! List) {
      return const [];
    }

    return items
        .whereType<Map<String, dynamic>>()
        .map((item) => _subjectKey(_string(item['code'])))
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  List<String> _stringList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .map((item) => _string(item))
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  int _int(Object? value) => int.tryParse((value ?? '').toString()) ?? 0;

  String _string(Object? value) => (value ?? '').toString().trim();

  LearningQueueItem? _queueItemOrNull(Object? value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }
    return LearningQueueItem(
      id: _string(value['id']),
      trackId: _nullableString(value['track_id']),
      moduleId: _nullableString(value['module_id']),
      title: _string(value['title']),
      subtitle: _string(value['subtitle']),
      status: _string(value['status']),
    );
  }

  List<LearningTrackSummary> _trackSummaries(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map<String, dynamic>>()
        .map(
          (track) => LearningTrackSummary(
            id: _string(track['id']),
            title: _string(track['title']),
            status: _string(track['status']),
            progressPercent: _int(track['progress_percent']),
            modules: _moduleSummaries(track['modules']),
          ),
        )
        .toList(growable: false);
  }

  List<LearningTrackModuleSummary> _moduleSummaries(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map<String, dynamic>>()
        .map(
          (module) => LearningTrackModuleSummary(
            id: _string(module['id']),
            title: _string(module['title']),
            description: _string(module['description']),
            status: _string(module['status']),
            estimatedMinutes: _int(module['estimated_minutes']),
          ),
        )
        .toList(growable: false);
  }

  String? _nullableString(Object? value) {
    final text = _string(value);
    return text.isEmpty ? null : text;
  }

  String _requireToken() {
    final token = _sessionStore.accessToken;
    if (token == null || token.isEmpty) {
      throw const ApiClientException('Please log in before opening dashboard.');
    }
    return token;
  }

  String _languageName(String code) {
    return switch (code) {
      'id' => 'Bahasa Indonesia',
      'en' => 'English',
      'ms' => 'Bahasa Melayu',
      'fil' => 'Filipino',
      'vi' => 'Vietnamese',
      _ => code,
    };
  }

  String _subjectKey(String code) {
    final normalized = code.trim().toLowerCase();
    return switch (normalized) {
      'math' || 'matematika' => 'Math',
      'physics' || 'fisika' => 'Physics',
      'chemistry' || 'kimia' => 'Chemistry',
      'biology' || 'biologi' => 'Biology',
      _ => _titleFromCode(code),
    };
  }

  String _titleFromCode(String code) {
    return code
        .replaceAll('_', ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}
