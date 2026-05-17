import 'package:flutter/material.dart';

import 'src/app/wicara_app.dart';
import 'src/core/network/api_client.dart';
import 'src/features/auth/application/auth_controller.dart';
import 'src/features/auth/data/api_auth_repository.dart';
import 'src/features/auth/data/auth_session_store.dart';
import 'src/features/auth/data/google_web_client_id.dart';
import 'src/features/curriculum/data/api_curriculum_repository.dart';
import 'src/features/home/data/api_home_repository.dart';
import 'src/features/learning_goal/data/api_learning_goal_repository.dart';
import 'src/features/onboarding/application/onboarding_controller.dart';
import 'src/features/onboarding/data/api_onboarding_repository.dart';
import 'src/features/onboarding/data/onboarding_profile_store.dart';
import 'src/features/pretest/data/api_pretest_repository.dart';
import 'src/features/pretest/data/pretest_session_store.dart';
import 'src/features/workspace/data/api_workspace_repository.dart';
import 'src/features/workspace/data/workspace_session_store.dart';

const _googleWebClientId = String.fromEnvironment(
  'WICARA_GOOGLE_WEB_CLIENT_ID',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sessionStore = authSessionStore;
  final pretestStore = pretestSessionStore;
  final workspaceStore = workspaceSessionStore;
  final apiClient = ApiClient(
    baseUrl: ApiClient.resolveRuntimeBaseUrl(ApiClient.defaultBaseUrl),
  );
  final googleWebClientId = resolveGoogleWebClientId(_googleWebClientId);
  final authController = AuthController(
    authRepository: ApiAuthRepository(
      apiClient: apiClient,
      sessionStore: sessionStore,
      googleWebClientId: googleWebClientId,
    ),
    sessionStore: sessionStore,
    apiClient: apiClient,
  );

  await authController.initialize();
  await workspaceStore.read();
  final onboardingController = OnboardingController(
    onboardingRepository: ApiOnboardingRepository(
      apiClient: apiClient,
      sessionStore: sessionStore,
    ),
    profileStore: OnboardingProfileStore(),
  );
  await onboardingController.initialize(
    displayName: authController.session?.displayName ?? 'Learner',
  );

  runApp(
    WicaraApp(
      authController: authController,
      onboardingController: onboardingController,
      curriculumRepository: ApiCurriculumRepository(apiClient: apiClient),
      learningGoalRepository: ApiLearningGoalRepository(
        apiClient: apiClient,
        sessionStore: sessionStore,
        pretestSessionStore: pretestStore,
      ),
      homeRepository: ApiHomeRepository(
        apiClient: apiClient,
        sessionStore: sessionStore,
      ),
      onboardingRepository: ApiOnboardingRepository(
        apiClient: apiClient,
        sessionStore: sessionStore,
      ),
      pretestRepository: ApiPretestRepository(
        apiClient: apiClient,
        sessionStore: sessionStore,
        pretestSessionStore: pretestStore,
      ),
      workspaceRepository: ApiWorkspaceRepository(
        apiClient: apiClient,
        sessionStore: sessionStore,
        workspaceSessionStore: workspaceStore,
      ),
    ),
  );
}
