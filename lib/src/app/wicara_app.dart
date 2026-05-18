import 'package:flutter/material.dart';

import '../core/theme/wicara_theme.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/sign_in_page.dart';
import '../features/curriculum/domain/curriculum_repository.dart';
import '../features/home/domain/home_repository.dart';
import '../features/home/domain/home_snapshot.dart';
import '../features/home/presentation/app_home_page.dart';
import '../features/landing/presentation/landing_page.dart';
import '../features/learning_goal/domain/learning_goal_repository.dart';
import '../features/learning_goal/presentation/learning_goal_page.dart';
import '../features/onboarding/application/onboarding_controller.dart';
import '../features/onboarding/domain/onboarding_repository.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/pretest/domain/pretest_repository.dart';
import '../features/pretest/presentation/pretest_page.dart';
import '../features/workspace/domain/workspace_models.dart';
import '../features/workspace/domain/workspace_repository.dart';
import '../features/workspace/presentation/workspace_modules_page.dart';
import 'app_routes.dart';

class WicaraApp extends StatefulWidget {
  const WicaraApp({
    required this.authController,
    required this.onboardingController,
    required this.curriculumRepository,
    required this.learningGoalRepository,
    required this.onboardingRepository,
    required this.pretestRepository,
    this.workspaceRepository,
    this.homeRepository,
    this.initialRoute = AppRoutes.landing,
    super.key,
  });

  final AuthController authController;
  final OnboardingController onboardingController;
  final CurriculumRepository curriculumRepository;
  final LearningGoalRepository learningGoalRepository;
  final HomeRepository? homeRepository;
  final OnboardingRepository onboardingRepository;
  final PretestRepository pretestRepository;
  final WorkspaceRepository? workspaceRepository;
  final String initialRoute;

  @override
  State<WicaraApp> createState() => _WicaraAppState();
}

class _WicaraAppState extends State<WicaraApp> {
  static const _preloadedAssets = <String>[
    'lib/src/assets/landingPage.png',
    'lib/src/assets/iconText.png',
    'lib/src/assets/waveIcon.png',
    'lib/src/assets/learnIcon.png',
    'lib/src/assets/progressIcon.png',
    'lib/src/assets/profileIcon.png',
    'lib/src/assets/onboardingIcon.png',
    'lib/src/assets/pretestIcon.png',
    'lib/src/assets/workspaceIcon.png',
  ];

  bool _didSchedulePreload = false;
  late final NavigatorObserver _authRouteObserver;

  // Cached once after auth finishes initializing so that MaterialApp.initialRoute
  // is never set from a partially-restored session.
  String? _resolvedInitialRoute;

  @override
  void initState() {
    super.initState();
    _authRouteObserver = _AuthRouteObserver(widget.authController);
    widget.authController.addListener(_onAuthChanged);
    // If already initialized when the widget is created (uncommon but possible)
    if (widget.authController.isInitialized) {
      _resolvedInitialRoute = _computeInitialRoute();
    }
  }

  @override
  void dispose() {
    widget.authController.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (_resolvedInitialRoute == null && widget.authController.isInitialized) {
      setState(() {
        _resolvedInitialRoute = _computeInitialRoute();
      });
    }
  }

  String _computeInitialRoute() {
    return widget.authController.isSignedIn
        ? widget.authController.initialSignedInRoute
        : AppRoutes.landing;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didSchedulePreload) {
      return;
    }

    _didSchedulePreload = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      for (final assetPath in _preloadedAssets) {
        precacheImage(AssetImage(assetPath), context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show a blank splash until auth finishes initializing (including refresh).
    // This prevents MaterialApp from mounting with an initialRoute derived from
    // a partially-restored session before the refresh completes.
    final initialRoute = _resolvedInitialRoute;
    if (initialRoute == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(backgroundColor: Color(0xFFF3F3FD)),
      );
    }

    return AnimatedBuilder(
      animation: widget.onboardingController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Wicara',
          debugShowCheckedModeBanner: false,
          theme: WicaraTheme.light(),
          navigatorObservers: [_authRouteObserver],
          initialRoute: initialRoute,
          onGenerateRoute: _onGenerateRoute,
        );
      },
    );
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final routeName = _resolveRouteName(settings.name);

    return MaterialPageRoute<void>(
      settings: RouteSettings(name: routeName, arguments: settings.arguments),
      builder: (context) => switch (routeName) {
        AppRoutes.landing => LandingPage(
          onboardingController: widget.onboardingController,
        ),
        AppRoutes.signIn => SignInPage(
          authController: widget.authController,
          onboardingController: widget.onboardingController,
        ),
        AppRoutes.onboarding => OnboardingPage(
          onboardingController: widget.onboardingController,
          authController: widget.authController,
        ),
        AppRoutes.learningGoal => LearningGoalPage(
          learningGoalRepository: widget.learningGoalRepository,
          onboardingController: widget.onboardingController,
        ),
        AppRoutes.pretest => PretestPage(
          pretestRepository: widget.pretestRepository,
          onboardingController: widget.onboardingController,
        ),
        AppRoutes.home => AppHomePage(
          curriculumRepository: widget.curriculumRepository,
          homeRepository:
              widget.homeRepository ?? const _UnavailableHomeRepository(),
          authController: widget.authController,
          onboardingController: widget.onboardingController,
          routeArguments: settings.arguments,
        ),
        AppRoutes.workspaceModules => WorkspaceModulesPage(
          onboardingController: widget.onboardingController,
          workspaceRepository:
              widget.workspaceRepository ??
              const _UnavailableWorkspaceRepository(),
          homeRepository: widget.homeRepository,
          routeArguments: settings.arguments is WorkspaceRouteArguments
              ? settings.arguments! as WorkspaceRouteArguments
              : null,
        ),
        _ => LandingPage(onboardingController: widget.onboardingController),
      },
    );
  }

  String _resolveRouteName(String? requestedRouteName) {
    final routeName = requestedRouteName ?? AppRoutes.landing;
    final isProtectedRoute = AppRoutes.protectedRoutes.contains(routeName);

    if (!widget.authController.isSignedIn && isProtectedRoute) {
      return AppRoutes.signIn;
    }

    if (widget.authController.isSignedIn &&
        (routeName == AppRoutes.landing || routeName == AppRoutes.signIn)) {
      return widget.authController.initialSignedInRoute;
    }

    return routeName;
  }
}

class _UnavailableWorkspaceRepository implements WorkspaceRepository {
  const _UnavailableWorkspaceRepository();

  @override
  Future<WorkspaceSession> createOrResumeWorkspace({
    required String trackId,
    required String moduleId,
    String? workspaceSessionId,
    bool startNewSession = false,
  }) {
    throw UnimplementedError('WorkspaceRepository is not configured.');
  }

  @override
  WorkspaceSessionHistory sessionHistory({
    required String trackId,
    required String moduleId,
  }) {
    throw UnimplementedError('WorkspaceRepository is not configured.');
  }

  @override
  Future<void> setActiveSession({
    required String trackId,
    required String moduleId,
    required String workspaceId,
  }) {
    throw UnimplementedError('WorkspaceRepository is not configured.');
  }

  @override
  Future<List<WorkspaceSessionSummary>> fetchSessionHistory({
    required String trackId,
    required String moduleId,
  }) {
    throw UnimplementedError('WorkspaceRepository is not configured.');
  }

  @override
  Future<WorkspaceSession> fetchWorkspace(String workspaceId) {
    throw UnimplementedError('WorkspaceRepository is not configured.');
  }

  @override
  Future<WorkspaceAppendResult> appendEvent({
    required String workspaceId,
    required String eventType,
    String textPayload = '',
    Map<String, dynamic> metadata = const {},
  }) {
    throw UnimplementedError('WorkspaceRepository is not configured.');
  }

  @override
  Future<WorkspaceGenerateVideoResult> generateVideo({
    required String workspaceId,
    String generationMode = 'context_auto',
    String? templateId,
    Map<String, dynamic>? specJson,
    String language = 'id',
    String qualityProfile = 'standard',
    String? conceptId,
    Map<String, dynamic> metadata = const {},
  }) {
    throw UnimplementedError('WorkspaceRepository is not configured.');
  }

  @override
  Future<WorkspaceAnimationJobStatus> getAnimationStatus({
    required String jobId,
  }) {
    throw UnimplementedError('WorkspaceRepository is not configured.');
  }

  @override
  Future<void> updateModuleState({
    required String trackId,
    required String moduleId,
    required String status,
  }) {
    throw UnimplementedError('WorkspaceRepository is not configured.');
  }
}

class _AuthRouteObserver extends NavigatorObserver {
  _AuthRouteObserver(this._authController);

  final AuthController _authController;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _authController.markRouteVisited(route.settings.name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _authController.markRouteVisited(previousRoute?.settings.name);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _authController.markRouteVisited(newRoute?.settings.name);
  }
}

class _UnavailableHomeRepository implements HomeRepository {
  const _UnavailableHomeRepository();

  @override
  Future<HomeSnapshot> fetchSnapshot() {
    throw UnimplementedError('HomeRepository is not configured.');
  }

  @override
  Future<List<HomeMediaArtifact>> fetchMediaArtifacts() {
    throw UnimplementedError('HomeRepository is not configured.');
  }

  @override
  Future<HomeMediaArtifact> fetchMediaArtifactById({
    required String artifactId,
  }) {
    throw UnimplementedError('HomeRepository is not configured.');
  }

  @override
  Future<AssessmentDashboard> fetchAssessmentDashboard({
    required String learningGoalId,
  }) {
    throw UnimplementedError('HomeRepository is not configured.');
  }

  @override
  Future<DailyEvaluationSession> fetchDailyEvaluation() {
    throw UnimplementedError('HomeRepository is not configured.');
  }

  @override
  Future<DailyEvaluationAnswerResult> submitDailyEvaluationAnswer({
    required String sessionId,
    required String questionId,
    required String optionId,
    required int confidence,
  }) {
    throw UnimplementedError('HomeRepository is not configured.');
  }

  @override
  Future<DailyEvaluationResult> fetchDailyEvaluationResult({
    required String sessionId,
  }) {
    throw UnimplementedError('HomeRepository is not configured.');
  }

  @override
  Future<DailyEvaluationSession> startPosttest({
    String? learningGoalId,
    String? trackId,
  }) {
    throw UnimplementedError('HomeRepository is not configured.');
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
  }) {
    throw UnimplementedError('HomeRepository is not configured.');
  }

  @override
  Future<AdaptivePosttestResult> finalizePosttest({required String sessionId}) {
    throw UnimplementedError('HomeRepository is not configured.');
  }

  @override
  Future<WeeklyLearningReport> fetchWeeklyLearningReport({
    DateTime? start,
    DateTime? end,
  }) {
    throw UnimplementedError('HomeRepository is not configured.');
  }
}
