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

  @override
  void initState() {
    super.initState();
    _authRouteObserver = _AuthRouteObserver(widget.authController);
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
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.authController,
        widget.onboardingController,
      ]),
      builder: (context, _) {
        return MaterialApp(
          title: 'Wicara',
          debugShowCheckedModeBanner: false,
          theme: WicaraTheme.light(),
          navigatorObservers: [_authRouteObserver],
          initialRoute: widget.authController.isSignedIn
              ? widget.authController.initialSignedInRoute
              : AppRoutes.landing,
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
        ),
        AppRoutes.workspaceModules => WorkspaceModulesPage(
          onboardingController: widget.onboardingController,
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

class _AuthRouteObserver extends NavigatorObserver {
  _AuthRouteObserver(this._authController);

  final AuthController _authController;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _authController.markRouteVisited(route.settings.name);
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
  Future<DailyEvaluationSession> fetchDailyEvaluation() {
    throw UnimplementedError('HomeRepository is not configured.');
  }

  @override
  Future<void> submitDailyEvaluationAnswer({
    required String sessionId,
    required String questionId,
    required String optionId,
    required int confidence,
  }) {
    throw UnimplementedError('HomeRepository is not configured.');
  }
}
