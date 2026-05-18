import '../../../core/network/api_client.dart';
import '../../auth/data/auth_session_store.dart';
import '../../pretest/data/api_pretest_repository.dart';
import '../../pretest/domain/pretest_models.dart';
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
    Map<String, dynamic> mediaArtifactsJson = const {'items': []};
    try {
      mediaArtifactsJson = await _apiClient.getJson(
        '/api/v1/media-artifacts',
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (_) {
      mediaArtifactsJson = const {'items': []};
    }
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
      mediaArtifacts: _mediaArtifactsFromList(mediaArtifactsJson['items']),
    );
  }

  @override
  Future<List<HomeMediaArtifact>> fetchMediaArtifacts() async {
    final token = _requireToken();
    final json = await _apiClient.getJson(
      '/api/v1/media-artifacts',
      headers: {'Authorization': 'Bearer $token'},
    );
    return _mediaArtifactsFromList(json['items']);
  }

  @override
  Future<HomeMediaArtifact> fetchMediaArtifactById({
    required String artifactId,
  }) async {
    final token = _requireToken();
    final json = await _apiClient.getJson(
      '/api/v1/media-artifacts/$artifactId',
      headers: {'Authorization': 'Bearer $token'},
    );
    return _mediaArtifactFromJson(json);
  }

  @override
  Future<AssessmentDashboard> fetchAssessmentDashboard({
    required String learningGoalId,
  }) async {
    final token = _requireToken();
    final json = await _apiClient.getJson(
      '/api/v1/learning-goals/$learningGoalId/assessment-dashboard',
      headers: {'Authorization': 'Bearer $token'},
    );
    return _assessmentDashboardFromJson(json);
  }

  @override
  Future<DailyEvaluationSession> fetchDailyEvaluation() async {
    final token = _requireToken();
    final json = await _apiClient.getJson(
      '/api/v1/daily-evaluations/today',
      headers: {'Authorization': 'Bearer $token'},
    );
    final questions = json['questions'];
    final parsedQuestions = questions is List
        ? questions
              .whereType<Map<String, dynamic>>()
              .map(questionFromJson)
              .toList(growable: false)
        : const <PretestQuestion>[];
    final currentQuestionJson = json['question'];
    final currentQuestion = currentQuestionJson is Map<String, dynamic>
        ? questionFromJson(currentQuestionJson)
        : (parsedQuestions.isEmpty ? null : parsedQuestions.first);
    return DailyEvaluationSession(
      sessionId: _string(json['session_id']),
      title: _stringWithFallback(json['title'], 'Daily Evaluation'),
      status: _string(json['status']),
      language: _stringWithFallback(json['language'], 'en'),
      source: _string(json['source']),
      reviewDue: _reviewDueFromJson(json['review_due']),
      progress: _progressFromJson(json['progress'], parsedQuestions.length),
      currentQuestion: currentQuestion,
      questions: parsedQuestions,
      retentionForecast: _retentionForecastFromJson(json['retention_forecast']),
      recommendationCallout: _recommendationCalloutFromJson(
        json['recommendation_callout'],
      ),
    );
  }

  @override
  Future<DailyEvaluationAnswerResult> submitDailyEvaluationAnswer({
    required String sessionId,
    required String questionId,
    required String optionId,
    required int confidence,
  }) async {
    final token = _requireToken();
    final json = await _apiClient.postJson(
      '/api/v1/daily-evaluations/$sessionId/answers',
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'question_id': questionId,
        'option_id': optionId,
        'confidence': confidence,
      },
    );
    return DailyEvaluationAnswerResult(
      attemptId: _string(json['attempt_id']),
      isCorrect: json['is_correct'] == true,
      nextReviewLabel: _string(json['next_review_label']),
      masteryDelta: _double(json['mastery_delta']),
      sessionStatus: _string(json['session_status']),
      completed: json['completed'] == true,
    );
  }

  @override
  Future<DailyEvaluationResult> fetchDailyEvaluationResult({
    required String sessionId,
  }) async {
    final token = _requireToken();
    final json = await _apiClient.getJson(
      '/api/v1/daily-evaluations/$sessionId/result',
      headers: {'Authorization': 'Bearer $token'},
    );
    return _dailyEvaluationResultFromJson(json);
  }

  @override
  Future<DailyEvaluationSession> startPosttest({
    String? learningGoalId,
    String? trackId,
    String? moduleId,
  }) async {
    final token = _requireToken();
    final body = <String, dynamic>{};
    if ((learningGoalId ?? '').isNotEmpty) {
      body['learning_goal_id'] = learningGoalId;
    }
    if ((trackId ?? '').isNotEmpty) {
      body['track_id'] = trackId;
    }
    if ((moduleId ?? '').isNotEmpty) {
      body['module_id'] = moduleId;
    }
    final json = await _apiClient.postJson(
      '/api/v1/posttests/start',
      headers: {'Authorization': 'Bearer $token'},
      body: body,
    );
    return _posttestSessionFromJson(json);
  }

  @override
  Future<DailyEvaluationAnswerResult> submitPosttestAnswer({
    required String sessionId,
    required String questionId,
    required String optionId,
    required int confidence,
    String typedReasoning = '',
    String? canvasAssetId,
    bool usedCanvas = false,
  }) async {
    final token = _requireToken();
    final json = await _apiClient.postJson(
      '/api/v1/posttests/$sessionId/answers',
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'question_id': questionId,
        'selected_option_id': optionId,
        'confidence': confidence,
        'typed_reasoning': typedReasoning,
        'canvas_asset_id': canvasAssetId,
        'used_canvas': usedCanvas,
      },
    );
    return DailyEvaluationAnswerResult(
      attemptId: _string(json['attempt_id']),
      isCorrect: json['is_correct'] == true,
      nextReviewLabel: '',
      masteryDelta: 0,
      sessionStatus: json['completed'] == true ? 'completed' : 'active',
      completed: json['completed'] == true,
    );
  }

  @override
  Future<AdaptivePosttestResult> finalizePosttest({
    required String sessionId,
  }) async {
    final token = _requireToken();
    final json = await _apiClient.postJson(
      '/api/v1/posttests/$sessionId/finalize',
      headers: {'Authorization': 'Bearer $token'},
      body: const {},
    );
    return _posttestResultFromJson(json, sessionId: sessionId);
  }

  @override
  Future<WeeklyLearningReport> fetchWeeklyLearningReport({
    DateTime? start,
    DateTime? end,
  }) async {
    final token = _requireToken();
    final hasDateRange = start != null && end != null;
    final json = await _apiClient.getJson(
      hasDateRange ? '/api/v1/reports/weekly' : '/api/v1/reports/weekly/latest',
      queryParameters: hasDateRange
          ? {'start': _dateOnly(start), 'end': _dateOnly(end)}
          : null,
      headers: {'Authorization': 'Bearer $token'},
    );
    return _weeklyLearningReportFromJson(json);
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

  String _string(Object? value) => (value ?? '').toString().trim();

  String _stringWithFallback(Object? value, String fallback) {
    final parsed = _string(value);
    return parsed.isEmpty ? fallback : parsed;
  }

  int _int(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse(_string(value)) ?? 0;
  }

  double _double(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(_string(value)) ?? 0;
  }

  Map<String, dynamic> _map(Object? value) {
    return value is Map<String, dynamic> ? value : const {};
  }

  ReviewDueSummary _reviewDueFromJson(Object? value) {
    final json = _map(value);
    return ReviewDueSummary(
      title: _stringWithFallback(json['title'], 'Review due'),
      dueCount: _int(json['due_count']),
      summary: _string(json['summary']),
      actionLabel: _stringWithFallback(json['action_label'], 'Start'),
    );
  }

  DailyEvaluationProgress _progressFromJson(Object? value, int totalFallback) {
    final json = _map(value);
    final total = _int(json['total']);
    final current = _int(json['current']);
    final completed = _int(json['completed']);
    final effectiveTotal = total == 0 ? totalFallback : total;
    final effectiveCurrent = current == 0 && effectiveTotal > 0 ? 1 : current;
    return DailyEvaluationProgress(
      current: effectiveCurrent,
      total: effectiveTotal,
      completed: completed,
      label: _stringWithFallback(
        json['label'],
        '$effectiveCurrent of $effectiveTotal',
      ),
    );
  }

  RetentionForecast _retentionForecastFromJson(Object? value) {
    final json = _map(value);
    final rawPoints = json['points'];
    return RetentionForecast(
      title: _stringWithFallback(json['title'], 'Your retention forecast'),
      basis: _string(json['basis']),
      points: rawPoints is List
          ? rawPoints
                .whereType<Map<String, dynamic>>()
                .map(
                  (point) => RetentionForecastPoint(
                    label: _string(point['label']),
                    retentionPercent: _int(point['retention_percent']),
                    projected: point['projected'] == true,
                  ),
                )
                .where((point) => point.label.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }

  RecommendationCallout _recommendationCalloutFromJson(Object? value) {
    final json = _map(value);
    return RecommendationCallout(
      title: _stringWithFallback(json['title'], 'Review now'),
      message: _string(json['message']),
      impactLabel: _string(json['impact_label']),
      actionLabel: _stringWithFallback(json['action_label'], 'Review now'),
    );
  }

  DailyEvaluationResult _dailyEvaluationResultFromJson(
    Map<String, dynamic> json,
  ) {
    return DailyEvaluationResult(
      sessionId: _string(json['session_id']),
      title: _stringWithFallback(json['title'], 'Daily Evaluation'),
      status: _string(json['status']),
      source: _string(json['source']),
      scorePercent: _int(json['score_percent']),
      reviewedCount: _int(json['reviewed_count']),
      correctCount: _int(json['correct_count']),
      reviewAgainCount: _int(json['review_again_count']),
      reviewedConcepts: _reviewedConceptsFromJson(json['reviewed_concepts']),
      spacedRepetitionImpact: _impactFromJson(json['spaced_repetition_impact']),
      nextReview: _nextReviewFromJson(json['next_review']),
      recommendedNextActions: _recommendedActionsFromJson(
        json['recommended_next_actions'],
      ),
      backToHome: _actionTargetFromJson(
        json['back_to_home'],
        fallbackLabel: 'Back to Home',
      ),
    );
  }

  DailyEvaluationSession _posttestSessionFromJson(Map<String, dynamic> json) {
    final questions = json['questions'];
    final parsedQuestions = questions is List
        ? questions
              .whereType<Map<String, dynamic>>()
              .map(questionFromJson)
              .toList(growable: false)
        : const <PretestQuestion>[];
    final currentQuestionJson = json['current_question'];
    final currentQuestion = currentQuestionJson is Map<String, dynamic>
        ? questionFromJson(currentQuestionJson)
        : (parsedQuestions.isEmpty ? null : parsedQuestions.first);
    final totalQuestions = _int(json['total_questions']);
    final answered = _int(json['question_count']);
    final safeCurrent = (answered + 1)
        .clamp(1, totalQuestions == 0 ? 1 : totalQuestions)
        .toInt();
    return DailyEvaluationSession(
      sessionId: _string(json['session_id']),
      title: 'Adaptive Posttest',
      status: _stringWithFallback(json['status'], 'active'),
      language: 'id',
      source: 'adaptive_generated',
      reviewDue: ReviewDueSummary(
        title: 'Posttest siap',
        dueCount: totalQuestions,
        summary: '$totalQuestions soal untuk validasi mastery per node.',
        actionLabel: 'Mulai',
      ),
      progress: DailyEvaluationProgress(
        current: safeCurrent,
        total: totalQuestions,
        completed: answered,
        label: '$safeCurrent of $totalQuestions',
      ),
      currentQuestion: currentQuestion,
      questions: parsedQuestions,
      retentionForecast: const RetentionForecast(
        title: 'Target posttest',
        basis: 'Pass score per node minimal 7.0.',
        points: [
          RetentionForecastPoint(label: 'Pre', retentionPercent: 0),
          RetentionForecastPoint(label: 'Post', retentionPercent: 100),
        ],
      ),
      recommendationCallout: const RecommendationCallout(
        title: 'Mastery gate',
        message: 'Node dengan skor <7 wajib retake dan badge tidak diberikan.',
        impactLabel: 'Posttest',
        actionLabel: 'Jawab',
      ),
    );
  }

  AdaptivePosttestResult _posttestResultFromJson(
    Map<String, dynamic> json, {
    required String sessionId,
  }) {
    final nodeResults = json['node_results'];
    return AdaptivePosttestResult(
      sessionId: sessionId,
      status: _stringWithFallback(json['status'], 'completed'),
      nodeResults: _posttestNodesFromJson(nodeResults),
      retakeRequiredConcepts: _stringList(json['retake_required_concepts']),
    );
  }

  AssessmentDashboard _assessmentDashboardFromJson(Map<String, dynamic> json) {
    return AssessmentDashboard(
      learningGoalId: _string(json['learning_goal_id']),
      targetTitle: _string(json['target_title']),
      state: _string(json['state']),
      pretest: _dashboardPretestFromJson(json['pretest']),
      posttest: _dashboardPosttestFromJson(json['posttest']),
      comparison: _dashboardComparisonFromJson(json['comparison']),
      primaryAction: _actionTargetFromJson(
        json['primary_action'],
        fallbackLabel: 'Continue',
      ),
      recommendations: _stringList(json['recommendations']),
    );
  }

  AssessmentDashboardPretest? _dashboardPretestFromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }
    return AssessmentDashboardPretest(
      sessionId: _nullableString(value['session_id']),
      status: _string(value['status']),
      scorePercent: _double(value['score_percent']),
      overallMasteryPercent: _double(value['overall_mastery_percent']),
      confidencePercent: _double(value['confidence_percent']),
      recommendedPath: _string(value['recommended_path']),
      summary: _string(value['summary']),
      strengths: _stringList(value['strengths']),
      gaps: _stringList(value['gaps']),
      evidenceNotes: _stringList(value['evidence_notes']),
    );
  }

  AssessmentDashboardPosttest? _dashboardPosttestFromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }
    return AssessmentDashboardPosttest(
      sessionId: _nullableString(value['session_id']),
      status: _string(value['status']),
      answerPercent: _double(value['answer_percent']),
      evidencePercent: _double(value['evidence_percent']),
      scorePercent: _double(value['score_percent']),
      confidencePercent: _double(value['confidence_percent']),
      passedNodeCount: _int(value['passed_node_count']),
      totalNodeCount: _int(value['total_node_count']),
      passed: value['passed'] == true,
      retakeRequiredConcepts: _stringList(value['retake_required_concepts']),
      nodes: _posttestNodesFromJson(value['nodes']),
    );
  }

  AssessmentDashboardComparison _dashboardComparisonFromJson(Object? value) {
    final json = _map(value);
    return AssessmentDashboardComparison(
      available: json['available'] == true,
      pretestScorePercent: _nullableInt(json['pretest_score_percent']),
      posttestScorePercent: _nullableInt(json['posttest_score_percent']),
      learningGainPercent: _nullableInt(json['learning_gain_percent']),
      pairedConceptCount: _int(json['paired_concept_count']),
    );
  }

  List<PosttestNodeResult> _posttestNodesFromJson(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => PosttestNodeResult(
            conceptId: _nullableString(json['concept_id']),
            conceptCode: _string(json['concept_code']),
            conceptTitle: _stringWithFallback(
              json['concept_title'],
              _string(json['concept_code']),
            ),
            totalQuestions: _int(json['total_questions']),
            answeredCount: _int(json['answered_count']),
            correctCount: _int(json['correct_count']),
            answerPercent: _double(json['answer_percent']),
            evidencePercent: _double(json['evidence_percent']),
            scorePercent: _double(json['score_percent']),
            confidencePercent: _double(json['confidence_percent']),
            scaledScore: _double(json['scaled_score']),
            passed: json['passed'] == true,
            retakeRequired: json['retake_required'] == true,
            metricSource: _stringWithFallback(
              json['metric_source'],
              'adaptive_posttest_evidence',
            ),
          ),
        )
        .toList(growable: false);
  }

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
            subjectCode: _string(track['subject_code']),
            subjectName: _string(track['subject_name']),
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

  List<HomeMediaArtifact> _mediaArtifactsFromList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map<String, dynamic>>()
        .map(_mediaArtifactFromJson)
        .toList(growable: false);
  }

  HomeMediaArtifact _mediaArtifactFromJson(Map<String, dynamic> json) {
    final notes = json['notes'];
    return HomeMediaArtifact(
      id: _string(json['id']),
      title: _string(json['title']),
      subtitle: _string(json['subtitle']),
      status: _string(json['status']),
      durationSeconds: _int(json['duration_seconds']),
      durationLabel: _string(json['duration_label']),
      transcript: _string(json['transcript']),
      notes: notes is List
          ? notes.map((item) => _string(item)).toList(growable: false)
          : const [],
      artifactType: _stringWithFallback(json['artifact_type'], 'video'),
      thumbnailUrl: _resolveMediaUrl(_nullableString(json['thumbnail_url'])),
      videoUrl: _resolveMediaUrl(_nullableString(json['video_url'])),
      playbackUrl: _resolveMediaUrl(_nullableString(json['playback_url'])),
      trackId: _nullableString(json['track_id']),
      moduleId: _nullableString(json['module_id']),
      createdAt: _nullableString(json['created_at']),
    );
  }

  String? _nullableString(Object? value) {
    final text = _string(value);
    return text.isEmpty ? null : text;
  }

  int? _nullableInt(Object? value) {
    if (value == null) {
      return null;
    }
    final text = _string(value);
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return _int(value);
  }

  List<ReviewedConcept> _reviewedConceptsFromJson(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => ReviewedConcept(
            conceptId: _string(json['concept_id']).isEmpty
                ? null
                : _string(json['concept_id']),
            title: _stringWithFallback(json['title'], 'Reviewed concept'),
            statusLabel: _stringWithFallback(json['status_label'], 'Review'),
            masteryScore: _double(json['mastery_score']),
          ),
        )
        .toList(growable: false);
  }

  SpacedRepetitionImpact _impactFromJson(Object? value) {
    final json = _map(value);
    return SpacedRepetitionImpact(
      retentionLiftPercent: _int(json['retention_lift_percent']),
      daysUntilNextReview: _int(json['days_until_next_review']),
      summary: _string(json['summary']),
    );
  }

  DailyEvaluationNextReview _nextReviewFromJson(Object? value) {
    final json = _map(value);
    return DailyEvaluationNextReview(
      label: _string(json['label']),
      dueDate: _string(json['due_date']),
      intervalDays: _int(json['interval_days']),
    );
  }

  List<RecommendedNextAction> _recommendedActionsFromJson(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => RecommendedNextAction(
            title: _stringWithFallback(json['title'], 'Recommended action'),
            actionType: _string(json['action_type']),
            reason: _string(json['reason']),
            dueDate: _string(json['due_date']).isEmpty
                ? null
                : _string(json['due_date']),
            priority: _int(json['priority']),
            dueLabel: _string(json['due_label']).isEmpty
                ? null
                : _string(json['due_label']),
          ),
        )
        .toList(growable: false);
  }

  ActionTarget _actionTargetFromJson(
    Object? value, {
    required String fallbackLabel,
  }) {
    final json = _map(value);
    return ActionTarget(
      label: _stringWithFallback(json['label'], fallbackLabel),
      actionType: _string(json['action_type']),
      target: _string(json['target']).isEmpty
          ? _nullableString(json['target_id'])
          : _string(json['target']),
    );
  }

  WeeklyLearningReport _weeklyLearningReportFromJson(
    Map<String, dynamic> json,
  ) {
    return WeeklyLearningReport(
      rangeLabel: _stringWithFallback(json['range_label'], 'This week'),
      rangeStart: _string(json['range_start']),
      rangeEnd: _string(json['range_end']),
      status: _stringWithFallback(json['status'], 'complete'),
      source: _string(json['source']),
      score: _int(json['score']),
      pretestScorePercent: _nullableInt(json['pretest_score_percent']),
      posttestScorePercent: _nullableInt(json['posttest_score_percent']),
      learningGainPercent: _nullableInt(json['learning_gain_percent']),
      pairedConceptCount: _int(json['paired_concept_count']),
      fixedGaps: _int(json['fixed_gaps']),
      fixedGapsDelta: _int(json['fixed_gaps_delta']),
      remainingGaps: _int(json['remaining_gaps']),
      remainingGapsDelta: _int(json['remaining_gaps_delta']),
      retentionMinutes: _int(json['retention_minutes']),
      concepts: _string(json['concepts']),
      summaryNotes: _stringList(json['summary_notes']),
      performanceGroups: _performanceGroupsFromJson(
        json['performance_groups'],
        json['trends'],
      ),
      gapMetrics: _gapMetricsFromJson(json),
      unlockedThisWeek: _unlockedConceptSummaryFromJson(
        json['unlocked_this_week'],
      ),
      upcomingRecommendations: _recommendedActionsFromJson(
        json['upcoming_recommendations'],
      ),
      consistencySummary: _consistencySummaryFromJson(
        json['consistency_summary'],
      ),
    );
  }

  List<ReportPerformanceGroup> _performanceGroupsFromJson(
    Object? value,
    Object? trendFallback,
  ) {
    if (value is List && value.isNotEmpty) {
      return value
          .whereType<Map<String, dynamic>>()
          .map(
            (json) => ReportPerformanceGroup(
              label: _stringWithFallback(json['label'], 'Performance'),
              preTestPercent: _int(json['pre_test_percent']),
              postTestPercent: _int(json['post_test_percent']),
            ),
          )
          .toList(growable: false);
    }
    if (trendFallback is List) {
      return trendFallback
          .whereType<Map<String, dynamic>>()
          .map(
            (json) => ReportPerformanceGroup(
              label: _stringWithFallback(json['label'], 'Performance'),
              preTestPercent: (_double(json['before']) * 100).round(),
              postTestPercent: (_double(json['after']) * 100).round(),
            ),
          )
          .toList(growable: false);
    }
    return const [];
  }

  Map<String, GapMetric> _gapMetricsFromJson(Map<String, dynamic> json) {
    final metrics = json['gap_metrics'];
    if (metrics is Map<String, dynamic>) {
      return metrics.map(
        (key, value) => MapEntry(key, _gapMetricFromJson(value)),
      );
    }
    return {
      'fixed': GapMetric(
        count: _int(json['fixed_gaps']),
        weeklyDelta: _int(json['fixed_gaps_delta']),
        deltaLabel: _deltaLabel(_int(json['fixed_gaps_delta'])),
      ),
      'remaining': GapMetric(
        count: _int(json['remaining_gaps']),
        weeklyDelta: _int(json['remaining_gaps_delta']),
        deltaLabel: _deltaLabel(_int(json['remaining_gaps_delta'])),
      ),
    };
  }

  GapMetric _gapMetricFromJson(Object? value) {
    final json = _map(value);
    final delta = _int(json['weekly_delta']);
    return GapMetric(
      count: _int(json['count']),
      weeklyDelta: delta,
      deltaLabel: _stringWithFallback(json['delta_label'], _deltaLabel(delta)),
    );
  }

  String _deltaLabel(int delta) {
    if (delta > 0) {
      return '+$delta this week';
    }
    return '$delta this week';
  }

  UnlockedConceptSummary _unlockedConceptSummaryFromJson(Object? value) {
    final json = _map(value);
    return UnlockedConceptSummary(
      count: _int(json['count']),
      concepts: _stringList(json['concepts']),
    );
  }

  ConsistencySummary _consistencySummaryFromJson(Object? value) {
    final json = _map(value);
    return ConsistencySummary(
      title: _stringWithFallback(json['title'], 'Consistency is compounding.'),
      narrative: _string(json['narrative']),
      signal: _string(json['signal']),
    );
  }

  String _requireToken() {
    final token = _sessionStore.accessToken;
    if (token == null || token.isEmpty) {
      throw const ApiClientException('Please log in before opening dashboard.');
    }
    return token;
  }

  String? _resolveMediaUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) {
      return null;
    }
    final parsed = Uri.tryParse(rawUrl);
    if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
      return rawUrl;
    }

    final baseUri = Uri.parse(_apiClient.baseUrl);
    if (rawUrl.startsWith('/')) {
      return baseUri.resolve(rawUrl).toString();
    }
    return baseUri.resolve('/$rawUrl').toString();
  }

  String _dateOnly(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);
    return '${normalized.year.toString().padLeft(4, '0')}-'
        '${normalized.month.toString().padLeft(2, '0')}-'
        '${normalized.day.toString().padLeft(2, '0')}';
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
