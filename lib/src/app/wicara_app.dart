import 'package:flutter/material.dart';

import '../core/theme/wicara_theme.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/presentation/sign_in_page.dart';
import '../features/curriculum/domain/curriculum_repository.dart';
import '../features/home/domain/home_repository.dart';
import '../features/home/domain/home_snapshot.dart';
import '../features/home/presentation/app_home_page.dart';
import '../features/landing/presentation/landing_page.dart';
import '../features/learning_goal/domain/learning_goal_repository.dart';
import '../features/learning_goal/presentation/learning_goal_page.dart';
import '../features/onboarding/domain/onboarding_repository.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/pretest/domain/pretest_repository.dart';
import '../features/pretest/presentation/pretest_page.dart';
import '../features/workspace/presentation/workspace_modules_page.dart';
import 'app_routes.dart';

class WicaraApp extends StatefulWidget {
  const WicaraApp({
    required this.authRepository,
    required this.curriculumRepository,
    required this.learningGoalRepository,
    required this.onboardingRepository,
    required this.pretestRepository,
    this.homeRepository,
    this.initialRoute = AppRoutes.landing,
    super.key,
  });

  final AuthRepository authRepository;
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
    return MaterialApp(
      title: 'Wicara',
      debugShowCheckedModeBanner: false,
      theme: WicaraTheme.light(),
      initialRoute: widget.initialRoute,
      routes: {
        AppRoutes.landing: (_) => const LandingPage(),
        AppRoutes.signIn: (_) =>
            SignInPage(authRepository: widget.authRepository),
        AppRoutes.onboarding: (_) =>
            OnboardingPage(onboardingRepository: widget.onboardingRepository),
        AppRoutes.learningGoal: (_) => LearningGoalPage(
          learningGoalRepository: widget.learningGoalRepository,
        ),
        AppRoutes.pretest: (_) =>
            PretestPage(pretestRepository: widget.pretestRepository),
        AppRoutes.home: (_) => AppHomePage(
          curriculumRepository: widget.curriculumRepository,
          homeRepository:
              widget.homeRepository ?? const _UnavailableHomeRepository(),
        ),
        AppRoutes.workspaceModules: (_) => const WorkspaceModulesPage(),
      },
    );
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
