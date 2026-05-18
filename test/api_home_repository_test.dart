import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wicara_mobile/src/core/network/api_client.dart';
import 'package:wicara_mobile/src/features/auth/data/auth_session_store.dart';
import 'package:wicara_mobile/src/features/auth/domain/auth_repository.dart';
import 'package:wicara_mobile/src/features/home/data/api_home_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('weekly report range sends start and end as query parameters', () async {
    SharedPreferences.setMockInitialValues({});
    final sessionStore = AuthSessionStore();
    await sessionStore.save(
      session: const AuthSession(
        userId: 'learner-test',
        displayName: 'Learner Test',
        role: AuthRole.learner,
        onboardingCompleted: true,
        token: 'token-test',
      ),
      lastProtectedRoute: '/home',
    );

    late Uri requestedUri;
    final apiClient = ApiClient(
      baseUrl: 'http://127.0.0.1:8000',
      httpClient: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode(_weeklyReportJson()),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final repository = ApiHomeRepository(
      apiClient: apiClient,
      sessionStore: sessionStore,
    );

    final report = await repository.fetchWeeklyLearningReport(
      start: DateTime(2026, 5, 11),
      end: DateTime(2026, 5, 17),
    );

    expect(requestedUri.path, '/api/v1/reports/weekly');
    expect(requestedUri.queryParameters, {
      'start': '2026-05-11',
      'end': '2026-05-17',
    });
    expect(requestedUri.toString(), isNot(contains('%3F')));
    expect(report.pretestScorePercent, 72);
    expect(report.posttestScorePercent, 88);
    expect(report.learningGainPercent, 16);
    expect(report.pairedConceptCount, 1);
  });

  test('posttest answer sends reasoning and canvas evidence fields', () async {
    SharedPreferences.setMockInitialValues({});
    final sessionStore = AuthSessionStore();
    await sessionStore.save(
      session: const AuthSession(
        userId: 'learner-test',
        displayName: 'Learner Test',
        role: AuthRole.learner,
        onboardingCompleted: true,
        token: 'token-test',
      ),
      lastProtectedRoute: '/home',
    );

    late Map<String, dynamic> body;
    final apiClient = ApiClient(
      baseUrl: 'http://127.0.0.1:8000',
      httpClient: MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'attempt_id': 'attempt-1',
            'is_correct': true,
            'completed': false,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final repository = ApiHomeRepository(
      apiClient: apiClient,
      sessionStore: sessionStore,
    );

    await repository.submitPosttestAnswer(
      sessionId: 'posttest-1',
      questionId: 'question-1',
      optionId: 'option-1',
      confidence: 7,
      typedReasoning: '6 groups of 7',
      canvasAssetId: 'canvas-1',
      usedCanvas: true,
    );

    expect(body['question_id'], 'question-1');
    expect(body['selected_option_id'], 'option-1');
    expect(body['typed_reasoning'], '6 groups of 7');
    expect(body['canvas_asset_id'], 'canvas-1');
    expect(body['used_canvas'], isTrue);
  });

  test('posttest start sends module focus when provided', () async {
    SharedPreferences.setMockInitialValues({});
    final sessionStore = AuthSessionStore();
    await sessionStore.save(
      session: const AuthSession(
        userId: 'learner-test',
        displayName: 'Learner Test',
        role: AuthRole.learner,
        onboardingCompleted: true,
        token: 'token-test',
      ),
      lastProtectedRoute: '/home',
    );

    late Map<String, dynamic> body;
    final apiClient = ApiClient(
      baseUrl: 'http://127.0.0.1:8000',
      httpClient: MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'session_id': 'posttest-1',
            'status': 'active',
            'question_count': 0,
            'total_questions': 0,
            'questions': [],
            'node_results': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final repository = ApiHomeRepository(
      apiClient: apiClient,
      sessionStore: sessionStore,
    );

    await repository.startPosttest(trackId: 'track-1', moduleId: 'module-1');

    expect(body['track_id'], 'track-1');
    expect(body['module_id'], 'module-1');
  });

  test('posttest finalize parses node-level metrics', () async {
    SharedPreferences.setMockInitialValues({});
    final sessionStore = AuthSessionStore();
    await sessionStore.save(
      session: const AuthSession(
        userId: 'learner-test',
        displayName: 'Learner Test',
        role: AuthRole.learner,
        onboardingCompleted: true,
        token: 'token-test',
      ),
      lastProtectedRoute: '/home',
    );

    final apiClient = ApiClient(
      baseUrl: 'http://127.0.0.1:8000',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'session_id': 'posttest-1',
            'status': 'completed',
            'retake_required_concepts': ['math.multiplication'],
            'node_results': [
              {
                'concept_id': 'concept-1',
                'concept_code': 'math.multiplication',
                'concept_title': 'Perkalian',
                'total_questions': 3,
                'answered_count': 3,
                'correct_count': 2,
                'answer_percent': 66.67,
                'evidence_percent': 76.67,
                'score_percent': 76.67,
                'confidence_percent': 68,
                'scaled_score': 7.67,
                'passed': false,
                'retake_required': true,
                'metric_source': 'adaptive_posttest_evidence',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final repository = ApiHomeRepository(
      apiClient: apiClient,
      sessionStore: sessionStore,
    );

    final result = await repository.finalizePosttest(sessionId: 'posttest-1');

    expect(result.passed, isFalse);
    expect(result.answerPercent, 66.67);
    expect(result.evidencePercent, 76.67);
    expect(result.retakeRequiredConcepts, ['math.multiplication']);
    expect(result.nodeResults.single.retakeRequired, isTrue);
  });
}

Map<String, Object?> _weeklyReportJson() {
  return {
    'range_label': 'May 11 - May 17, 2026',
    'range_start': '2026-05-11',
    'range_end': '2026-05-17',
    'status': 'complete',
    'source': 'test',
    'score': 88,
    'pretest_score_percent': 72,
    'posttest_score_percent': 88,
    'learning_gain_percent': 16,
    'paired_concept_count': 1,
    'fixed_gaps': 4,
    'fixed_gaps_delta': 2,
    'remaining_gaps': 1,
    'remaining_gaps_delta': -1,
    'retention_minutes': 18,
    'concepts': 'Spaced review',
    'summary_notes': ['Test report'],
    'performance_groups': [
      {'label': 'Overall', 'pre_test_percent': 72, 'post_test_percent': 88},
    ],
    'gap_metrics': {
      'fixed': {'count': 4, 'weekly_delta': 2, 'delta_label': '+2 this period'},
      'remaining': {
        'count': 1,
        'weekly_delta': -1,
        'delta_label': '-1 this period',
      },
    },
    'unlocked_this_week': {
      'count': 1,
      'concepts': ['Spaced review'],
    },
    'upcoming_recommendations': [
      {
        'title': 'Review: Spaced review',
        'action_type': 'review',
        'reason': 'Due soon',
        'due_date': '2026-05-17',
        'due_label': 'Due today',
      },
    ],
    'consistency_summary': {
      'title': 'Consistency is compounding.',
      'narrative': 'Test narrative',
      'signal': 'test',
    },
  };
}
