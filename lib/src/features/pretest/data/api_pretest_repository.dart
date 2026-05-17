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
      final json = await _apiClient.postJson(
        '/api/v1/pretests/start',
        headers: {'Authorization': 'Bearer $token'},
        body: {'learning_goal_id': learningGoalId},
      );
      _pretestSessionStore.pretestSessionId = _string(json['session_id']);
      final current = json['current_question'];
      if (current is! Map<String, dynamic>) {
        throw const PretestException(
          'Backend returned an invalid pretest question.',
        );
      }
      return questionFromJson(current);
    } on PretestException {
      rethrow;
    } on ApiClientException catch (error) {
      throw PretestException(error.message);
    }
  }

  @override
  Future<PretestAnswerResult> submitAnswer(PretestAnswer answer) async {
    final token = _requireToken();
    final sessionId = _requirePretestSessionId();
    if (answer.optionId.isEmpty) {
      throw const PretestException('Choose an answer before continuing.');
    }

    try {
      final json = await _apiClient.postJson(
        '/api/v1/pretests/$sessionId/answers',
        headers: {'Authorization': 'Bearer $token'},
        body: {
          'question_id': answer.questionId,
          'selected_option_id': answer.optionId,
          'confidence': answer.confidence,
          'typed_reasoning': answer.typedReasoning,
          'canvas_asset_id': answer.canvasAssetId,
          'used_canvas': answer.usedCanvas,
        },
      );
      final nextQuestion = json['next_question'];
      if (nextQuestion is Map<String, dynamic>) {
        return PretestAnswerResult(
          completed: false,
          nextQuestion: questionFromJson(nextQuestion),
        );
      }
      final diagnosis = json['diagnosis'];
      if (diagnosis is Map<String, dynamic>) {
        return PretestAnswerResult(
          completed: true,
          diagnosis: knowledgeStateFromDiagnosis(diagnosis),
        );
      }
      throw const PretestException(
        'Backend returned no next question or diagnosis.',
      );
    } on ApiClientException catch (error) {
      throw PretestException(error.message);
    }
  }

  @override
  Future<KnowledgeState> selectPath(String pathOption) async {
    final token = _requireToken();
    final learningGoalId = _pretestSessionStore.learningGoalId;
    if (learningGoalId == null || learningGoalId.isEmpty) {
      throw const PretestException(
        'Create a learning goal before selecting a path.',
      );
    }

    try {
      final json = await _apiClient.postJson(
        '/api/v1/learning-goals/$learningGoalId/path-selection',
        headers: {'Authorization': 'Bearer $token'},
        body: {'path_option': pathOption},
      );
      _pretestSessionStore.trackId = _string(json['track_id']);
      return KnowledgeState(
        skill: 'Path selected',
        gapLabel: _string(json['goal_status']).toUpperCase(),
        message: 'Your adaptive learning path is ready.',
        pathTitle: 'Personalized path generated',
        pathMeta: '${(json['modules'] as List?)?.length ?? 0} modules',
        pathDescription: 'Continue with the selected path.',
        recommendedPath: pathOption,
        pathOptions: const [],
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
  final progress = json['progress'];
  final conceptTitle = _string(json['concept_title']);
  return PretestQuestion(
    id: _string(json['id']),
    packId: _string(json['pack_id']),
    stepLabel: _string(json['step_label']).isNotEmpty
        ? _string(json['step_label'])
        : 'Question ${_intFromProgress(progress, 'current', fallback: 1)} of ${_intFromProgress(progress, 'max', fallback: 10)}',
    topic: conceptTitle.isNotEmpty ? conceptTitle : _string(json['topic']),
    prompt: _string(json['prompt']),
    helper: _string(json['helper']),
    progressCurrent: _intFromProgress(progress, 'current', fallback: 1),
    progressMax: _intFromProgress(progress, 'max', fallback: 10),
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

KnowledgeState knowledgeStateFromDiagnosis(Map<String, dynamic> diagnosis) {
  final target = diagnosis['target'];
  final analysis = diagnosis['analysis'];
  final targetTitle = target is Map ? _string(target['title']) : '';
  final recommendedPath = _string(diagnosis['recommended_path']);
  final pathOptions = diagnosis['path_options'];
  final strengths = analysis is Map ? _stringList(analysis['strengths']) : const <String>[];
  final gaps = analysis is Map ? _stringList(analysis['gaps']) : const <String>[];
  final evidenceNotes = analysis is Map
      ? _stringList(analysis['evidence_notes'])
      : const <String>[];
  final recommendedFocus = analysis is Map
      ? _stringList(analysis['recommended_focus'])
      : const <String>[];
  final masteryScore = target is Map
      ? _double(target['mastery_score'])
      : _percentToUnit(diagnosis['score_percent']);
  final confidence = target is Map
      ? _double(target['confidence'])
      : _percentToUnit(diagnosis['confidence_percent']);
  final overallMasteryPercent = _int(diagnosis['overall_mastery_percent']) ??
      (analysis is Map ? _int(analysis['overall_mastery_percent']) : null);
  return KnowledgeState(
    skill: targetTitle.isNotEmpty ? targetTitle : 'Adaptive diagnosis',
    gapLabel: target is Map ? _string(target['status']).toUpperCase() : 'DONE',
    message: _string(diagnosis['summary']),
    pathTitle: 'Personalized path generated',
    pathMeta: _scoreMeta(
      masteryScore: masteryScore,
      confidence: confidence,
    ),
    pathDescription: _pathDescription(recommendedPath),
    recommendedPath: recommendedPath.isEmpty
        ? 'target_from_basics'
        : recommendedPath,
    pathOptions: pathOptions is List
        ? pathOptions
              .map((item) => _string(item))
              .where((item) => item.isNotEmpty)
              .toList(growable: false)
        : const [],
    masteryScore: masteryScore,
    confidence: confidence,
    overallMasteryPercent: overallMasteryPercent,
    strengths: strengths,
    gaps: gaps,
    evidenceNotes: evidenceNotes,
    recommendedFocus: recommendedFocus,
    nodeReports: _nodeReports(diagnosis['nodes']),
  );
}

String _string(Object? value) => (value ?? '').toString().trim();

double? _double(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(_string(value));
}

double? _percentToUnit(Object? value) {
  final parsed = _double(value);
  if (parsed == null) {
    return null;
  }
  return parsed > 1 ? parsed / 100 : parsed;
}

int _intFromProgress(Object? value, String key, {required int fallback}) {
  if (value is Map && value[key] is num) {
    return (value[key] as num).toInt();
  }
  return fallback;
}

String _pathDescription(String option) {
  return switch (option) {
    'review_only' => 'Start with a short review and advanced practice.',
    'target_reinforcement' =>
      'Practice the target concept at medium and hard levels.',
    'target_intro' => 'Start from the target concept introduction.',
    'repair_prerequisites' =>
      'Repair prerequisite gaps before returning to the target.',
    'full_foundation_path' => 'Rebuild the deeper foundation first.',
    _ => 'Learn the target concept from basics.',
  };
}

int? _int(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(_string(value));
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

List<PretestNodeReport> _nodeReports(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.whereType<Map>().map((node) {
    final evidenceSummary = node['evidence_summary'];
    final summary = evidenceSummary is Map ? evidenceSummary : const {};
    return PretestNodeReport(
      title: _string(node['title']).isNotEmpty
          ? _string(node['title'])
          : _string(node['concept_code']),
      role: _string(node['role']),
      status: _string(node['status']),
      difficultyReached: _string(node['difficulty_reached']),
      masteryScore: _double(node['mastery_score']),
      confidence: _double(node['confidence']),
      reasoningQuality: _string(summary['reasoning_quality']).isNotEmpty
          ? _string(summary['reasoning_quality'])
          : 'not_provided',
      avgReasoningScore: _double(summary['avg_reasoning_score']),
      attemptCount: _int(summary['attempt_count']) ?? 0,
      correctCount: _int(summary['correct_count']) ?? 0,
      diagnosticSignals: _stringList(summary['diagnostic_signals']),
      carelessMistakePossible: summary['careless_mistake_possible'] == true,
      misconceptionDetected: summary['misconception_detected'] == true,
    );
  }).where((node) => node.status != 'not_tested').toList(growable: false);
}

String _scoreMeta({double? masteryScore, double? confidence}) {
  if (masteryScore == null && confidence == null) {
    return 'Adaptive pretest complete';
  }
  final scoreText = masteryScore == null
      ? null
      : 'Score ${(masteryScore * 100).round()}%';
  final confidenceText = confidence == null
      ? null
      : 'confidence ${(confidence * 100).round()}%';
  return [scoreText, confidenceText].whereType<String>().join(' • ');
}
