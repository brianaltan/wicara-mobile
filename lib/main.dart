import 'package:flutter/material.dart';

import 'src/app/app_routes.dart';
import 'src/app/wicara_app.dart';
import 'src/core/network/api_client.dart';
import 'src/features/auth/data/api_auth_repository.dart';
import 'src/features/auth/data/auth_session_store.dart';
import 'src/features/curriculum/data/api_curriculum_repository.dart';
import 'src/features/home/data/api_home_repository.dart';
import 'src/features/learning_goal/data/api_learning_goal_repository.dart';
import 'src/features/onboarding/data/api_onboarding_repository.dart';
import 'src/features/pretest/data/api_pretest_repository.dart';
import 'src/features/pretest/data/pretest_session_store.dart';

const _googleWebClientId = String.fromEnvironment(
  'WICARA_GOOGLE_WEB_CLIENT_ID',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await authSessionStore.restore();

  final apiClient = ApiClient(baseUrl: ApiClient.defaultBaseUrl);
  final session = authSessionStore.currentSession;
  final initialRoute = session == null
      ? AppRoutes.landing
      : session.onboardingCompleted
      ? AppRoutes.home
      : AppRoutes.onboarding;

  runApp(
    WicaraApp(
      authRepository: ApiAuthRepository(
        apiClient: apiClient,
        sessionStore: authSessionStore,
        googleWebClientId: _googleWebClientId,
      ),
      curriculumRepository: ApiCurriculumRepository(apiClient: apiClient),
      learningGoalRepository: ApiLearningGoalRepository(
        apiClient: apiClient,
        sessionStore: authSessionStore,
        pretestSessionStore: pretestSessionStore,
      ),
      homeRepository: ApiHomeRepository(
        apiClient: apiClient,
        sessionStore: authSessionStore,
      ),
      onboardingRepository: ApiOnboardingRepository(
        apiClient: apiClient,
        sessionStore: authSessionStore,
      ),
      pretestRepository: ApiPretestRepository(
        apiClient: apiClient,
        sessionStore: authSessionStore,
        pretestSessionStore: pretestSessionStore,
      ),
      initialRoute: initialRoute,
    ),
  );
}
