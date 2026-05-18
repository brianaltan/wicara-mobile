import 'package:flutter/material.dart';

import 'src/app/wicara_app.dart';
import 'src/core/network/api_client.dart';
import 'src/features/auth/application/auth_controller.dart';
import 'src/features/auth/data/api_auth_repository.dart';
import 'src/features/auth/data/auth_session_store.dart';
import 'src/features/auth/data/google_web_client_id.dart';
import 'src/features/home/data/api_home_repository.dart';
import 'src/features/learning_goal/data/local_learning_goal_repository.dart';
import 'src/features/onboarding/application/onboarding_controller.dart';
import 'src/features/onboarding/data/api_onboarding_repository.dart';
import 'src/features/onboarding/data/onboarding_profile_store.dart';
import 'src/features/offline_learning/data/curriculum_bootstrap_service.dart';
import 'src/features/offline_learning/data/local_curriculum_repository.dart';
import 'src/features/offline_learning/data/local_wicara_database.dart';
import 'src/features/offline_pretest/data/local_pretest_repository.dart';
import 'src/features/pretest/data/api_pretest_repository.dart';
import 'src/features/pretest/data/pretest_session_store.dart';
import 'src/features/workspace/data/api_workspace_repository.dart';
import 'src/features/workspace/data/workspace_session_store.dart';

const _googleWebClientId = String.fromEnvironment(
  'WICARA_GOOGLE_WEB_CLIENT_ID',
);
const _edgeLiteRtForceLocalForPilot = bool.fromEnvironment(
  'EDGE_LITERT_FORCE_LOCAL_FOR_PILOT',
  defaultValue: true,
);
const _edgeCloudFallbackAllowed = bool.fromEnvironment(
  'EDGE_CLOUD_FALLBACK_ALLOWED',
  defaultValue: false,
);
const _edgeDebugRouteTrace = bool.fromEnvironment(
  'EDGE_DEBUG_ROUTE_TRACE',
  defaultValue: false,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localDatabase = LocalWicaraDatabase();
  final localCurriculumRepository = LocalCurriculumRepository(
    database: localDatabase,
  );
  await _bootstrapOfflineCurriculum(
    database: localDatabase,
    curriculumRepository: localCurriculumRepository,
  );
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

  final backendPretestRepository = ApiPretestRepository(
    apiClient: apiClient,
    sessionStore: sessionStore,
    pretestSessionStore: pretestStore,
  );

  runApp(
    WicaraApp(
      authController: authController,
      onboardingController: onboardingController,
      curriculumRepository: localCurriculumRepository,
      learningGoalRepository: LocalLearningGoalRepository(
        localCurriculumRepository: localCurriculumRepository,
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
      pretestRepository: LocalPretestRepository(
        localDatabase: localDatabase,
        pretestSessionStore: pretestStore,
        localCurriculumRepository: localCurriculumRepository,
        backendRepository: backendPretestRepository,
        forceLocalForPilot: _edgeLiteRtForceLocalForPilot,
        allowBackendFallback: false,
      ),
      workspaceRepository: ApiWorkspaceRepository(
        apiClient: apiClient,
        sessionStore: sessionStore,
        workspaceSessionStore: workspaceStore,
        edgeForceLocalForPilot: _edgeLiteRtForceLocalForPilot,
        edgeCloudFallbackAllowed: _edgeCloudFallbackAllowed,
        edgeDebugRouteTrace: _edgeDebugRouteTrace,
      ),
    ),
  );
}

Future<void> _bootstrapOfflineCurriculum({
  required LocalWicaraDatabase database,
  required LocalCurriculumRepository curriculumRepository,
}) async {
  if (!database.isPlatformSupported) {
    return;
  }
  final bootstrapService = CurriculumBootstrapService(
    repository: curriculumRepository,
  );
  try {
    await bootstrapService.ensureBootstrapped();
  } catch (error) {
    debugPrint(
      'Offline curriculum bootstrap failed, fallback to pilot graph: $error',
    );
    await curriculumRepository.ensurePilotSliceSeeded();
  }
}
