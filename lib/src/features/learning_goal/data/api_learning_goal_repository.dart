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
  Future<ActiveLearningGoal?> fetchActiveGoal() async {
    final token = _sessionStore.accessToken;
    if (token == null || token.isEmpty) {
      throw const LearningGoalException(
        'Please log in before creating a track.',
      );
    }

    try {
      final json = await _apiClient.getJson(
        '/api/v1/learning-goals/active',
        headers: {'Authorization': 'Bearer $token'},
      );
      if (json['has_active_goal'] != true || json['goal'] is! Map) {
        return null;
      }
      final goal = _activeGoalFromJson(
        Map<String, dynamic>.from(json['goal'] as Map),
      );
      _pretestSessionStore.saveBootstrap(
        learningGoalId: goal.id,
        pretestSessionId: goal.pretestSessionId,
        trackId: goal.trackId,
      );
      return goal;
    } on ApiClientException catch (error) {
      throw LearningGoalException(error.message);
    }
  }

  @override
  Future<LearningGoalResolution> resolveLearningGoal({
    required String rawQuery,
    String? subjectCode,
    String? educationLevel,
    String? gradeLevel,
    String? language,
  }) async {
    final token = _requireToken();
    try {
      final json = await _apiClient.postJson(
        '/api/v1/learning-goals/resolve',
        headers: {'Authorization': 'Bearer $token'},
        body: {
          'raw_query': rawQuery.trim(),
          if (_nullableString(subjectCode) != null)
            'subject_code': _nullableString(subjectCode),
          if (_nullableString(educationLevel) != null)
            'education_level': _nullableString(educationLevel),
          if (_nullableString(gradeLevel) != null)
            'grade_level': _nullableString(gradeLevel),
          if (_nullableString(language) != null)
            'language': _normalizeLanguage(language),
        },
      );
      return _resolutionFromJson(json);
    } on ApiClientException catch (error) {
      throw LearningGoalException(error.message);
    }
  }

  @override
  Future<LearningGoalBootstrap> confirmResolvedGoal({
    required String resolutionId,
  }) async {
    final token = _requireToken();
    try {
      final json = await _apiClient.postJson(
        '/api/v1/learning-goals/resolve/$resolutionId/confirm',
        headers: {'Authorization': 'Bearer $token'},
      );
      final bootstrap = LearningGoalBootstrap(
        learningGoalId: _string(json['learning_goal_id']),
      );
      _pretestSessionStore.saveBootstrap(
        learningGoalId: bootstrap.learningGoalId,
      );
      return bootstrap;
    } on ApiClientException catch (error) {
      // Detect 409 ACTIVE_LEARNING_GOAL_EXISTS from the backend and surface it
      // as a typed exception so the UI can show a structured conflict dialog.
      final conflict = _tryParseConflict(error);
      if (conflict != null) {
        throw conflict;
      }
      throw LearningGoalException(error.message);
    }
  }

  @override
  Future<LearningGoalResolution> selectResolvedConcept({
    required String resolutionId,
    required String conceptId,
  }) async {
    final token = _requireToken();
    try {
      final json = await _apiClient.postJson(
        '/api/v1/learning-goals/resolve/$resolutionId/select',
        headers: {'Authorization': 'Bearer $token'},
        body: {'concept_id': conceptId},
      );
      return _resolutionFromJson(json);
    } on ApiClientException catch (error) {
      throw LearningGoalException(error.message);
    }
  }

  @override
  Future<LearningGoalBootstrap> createLearningGoal({
    required String rawTopic,
  }) async {
    final resolution = await resolveLearningGoal(rawQuery: rawTopic);
    if (resolution.suggestedConcept == null) {
      throw LearningGoalException(
        resolution.clarificationQuestion ??
            'No matching learning goal was found.',
      );
    }
    return confirmResolvedGoal(resolutionId: resolution.resolutionId);
  }

  @override
  Future<LearningGoalBootstrap> createLearningGoalFromConcept({
    String? conceptId,
    String? conceptCode,
    String? subjectCode,
  }) async {
    final token = _requireToken();
    try {
      final json = await _apiClient.postJson(
        '/api/v1/learning-goals/from-concept',
        headers: {'Authorization': 'Bearer $token'},
        body: {
          if (_nullableString(conceptId) != null)
            'concept_id': _nullableString(conceptId),
          if (_nullableString(conceptCode) != null)
            'concept_code': _nullableString(conceptCode),
          if (_nullableString(subjectCode) != null)
            'subject_code': _nullableString(subjectCode),
        },
      );
      final bootstrap = LearningGoalBootstrap(
        learningGoalId: _string(json['learning_goal_id']),
      );
      _pretestSessionStore.saveBootstrap(
        learningGoalId: bootstrap.learningGoalId,
      );
      return bootstrap;
    } on ApiClientException catch (error) {
      final conflict = _tryParseConflict(error);
      if (conflict != null) {
        throw conflict;
      }
      throw LearningGoalException(error.message);
    }
  }

  @override
  Future<void> cancelGoal({required String learningGoalId}) async {
    final token = _requireToken();
    try {
      await _apiClient.postJson(
        '/api/v1/learning-goals/$learningGoalId/cancel',
        headers: {'Authorization': 'Bearer $token'},
      );
      _pretestSessionStore.clear();
    } on ApiClientException catch (error) {
      throw LearningGoalException(error.message);
    }
  }

  String _requireToken() {
    final token = _sessionStore.accessToken;
    if (token == null || token.isEmpty) {
      throw const LearningGoalException(
        'Please log in before creating a track.',
      );
    }
    return token;
  }

  String _string(Object? value) => (value ?? '').toString().trim();

  /// Tries to parse a 409 ACTIVE_LEARNING_GOAL_EXISTS response body into an
  /// [ActiveGoalConflictException]. Returns `null` for any other error.
  ActiveGoalConflictException? _tryParseConflict(ApiClientException error) {
    final detail = error.detail;
    if (detail is! Map) return null;
    final errorCode = detail['error']?.toString();
    if (errorCode != 'ACTIVE_LEARNING_GOAL_EXISTS') return null;
    final activeGoal = detail['active_goal'];
    if (activeGoal is! Map) return null;
    final existingGoalId = _string(activeGoal['id']);
    final pretestSessionId = _nullableString(activeGoal['pretest_session_id']);
    final trackId = _nullableString(activeGoal['track_id']);
    if (existingGoalId.isNotEmpty) {
      _pretestSessionStore.saveBootstrap(
        learningGoalId: existingGoalId,
        pretestSessionId: pretestSessionId,
        trackId: trackId,
      );
    }
    return ActiveGoalConflictException(
      existingGoalId: existingGoalId,
      existingTopic: _string(activeGoal['raw_topic']),
      existingStatus: _string(activeGoal['status']),
      existingNextAction: _string(activeGoal['next_action'] ?? ''),
      pretestSessionId: pretestSessionId,
      trackId: trackId,
    );
  }
}

LearningGoalResolution _resolutionFromJson(Map<String, dynamic> json) {
  final concept = json['suggested_concept'];
  final alternatives = json['alternatives'];
  final graphFocus = json['graph_focus'];
  return LearningGoalResolution(
    resolutionId: _stringValue(json['resolution_id']),
    status: _stringValue(json['status']),
    confidence: _doubleValue(json['confidence']),
    suggestedConcept: concept is Map
        ? _conceptFromJson(Map<String, dynamic>.from(concept))
        : null,
    clarificationQuestion: _nullableString(json['clarification_question']),
    searchScope: _stringValue(json['search_scope']),
    searchScopeReason: _nullableString(json['search_scope_reason']),
    graphSubjectCode: graphFocus is Map
        ? _nullableString(graphFocus['subject_code'])
        : null,
    graphFocusCodes: graphFocus is Map
        ? _stringList(graphFocus['highlight_concept_codes'])
        : const [],
    alternatives: alternatives is List
        ? alternatives
              .whereType<Map>()
              .map((item) => _conceptFromJson(Map<String, dynamic>.from(item)))
              .toList(growable: false)
        : const [],
  );
}

LearningConceptSuggestion _conceptFromJson(Map<String, dynamic> json) {
  return LearningConceptSuggestion(
    conceptId: _stringValue(json['concept_id']),
    conceptCode: _stringValue(json['concept_code']),
    title: _stringValue(json['title']),
    description: _stringValue(json['description']),
    idDesc: _stringValue(
      json['id_desc'].isEmpty
          ? json['description']
          : json['id_desc'],
    ),
    enDesc: _stringValue(json['en_desc']),
    subjectCode: _stringValue(json['subject_code']),
    subject: _stringValue(json['subject']),
    gradeBand: _nullableString(json['grade_band']),
    gradeRelation: _nullableString(json['grade_relation']),
    levelNote: _nullableString(json['level_note']),
    confidence: json.containsKey('confidence')
        ? _doubleValue(json['confidence'])
        : null,
  );
}

ActiveLearningGoal _activeGoalFromJson(Map<String, dynamic> json) {
  final concept = json['target_concept'];
  return ActiveLearningGoal(
    id: _stringValue(json['id']),
    status: _stringValue(json['status']),
    rawTopic: _stringValue(json['raw_topic']),
    nextAction: _stringValue(json['next_action']),
    targetConcept: concept is Map
        ? _conceptFromJson(Map<String, dynamic>.from(concept))
        : null,
    pretestSessionId: _nullableString(json['pretest_session_id']),
    trackId: _nullableString(json['track_id']),
  );
}

String _stringValue(Object? value) => (value ?? '').toString().trim();

String? _nullableString(Object? value) {
  final text = _stringValue(value);
  return text.isEmpty ? null : text;
}

double _doubleValue(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(_stringValue(value)) ?? 0;
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .map(_stringValue)
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String _normalizeLanguage(String? language) {
  final value = _stringValue(language).toLowerCase();
  if (value.contains('indo') || value == 'id') {
    return 'id';
  }
  return 'en';
}
