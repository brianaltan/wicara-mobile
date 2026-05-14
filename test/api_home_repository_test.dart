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

    await repository.fetchWeeklyLearningReport(
      start: DateTime(2026, 5, 11),
      end: DateTime(2026, 5, 17),
    );

    expect(requestedUri.path, '/api/v1/reports/weekly');
    expect(requestedUri.queryParameters, {
      'start': '2026-05-11',
      'end': '2026-05-17',
    });
    expect(requestedUri.toString(), isNot(contains('%3F')));
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
