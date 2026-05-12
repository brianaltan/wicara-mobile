import 'package:flutter/material.dart';

import '../core/theme/wicara_theme.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/curriculum/domain/curriculum_repository.dart';
import '../features/auth/presentation/sign_in_page.dart';
import '../features/home/presentation/app_home_page.dart';
import '../features/landing/presentation/landing_page.dart';
import '../features/learning_goal/presentation/learning_goal_page.dart';
import '../features/onboarding/domain/onboarding_repository.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/pretest/domain/pretest_repository.dart';
import '../features/pretest/presentation/pretest_page.dart';
import '../features/workspace/presentation/workspace_modules_page.dart';
import 'app_routes.dart';

class WicaraApp extends StatelessWidget {
  const WicaraApp({
    required this.authRepository,
    required this.curriculumRepository,
    required this.onboardingRepository,
    required this.pretestRepository,
    super.key,
  });

  final AuthRepository authRepository;
  final CurriculumRepository curriculumRepository;
  final OnboardingRepository onboardingRepository;
  final PretestRepository pretestRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wicara',
      debugShowCheckedModeBanner: false,
      theme: WicaraTheme.light(),
      initialRoute: AppRoutes.landing,
      routes: {
        AppRoutes.landing: (_) => const LandingPage(),
        AppRoutes.signIn: (_) => SignInPage(authRepository: authRepository),
        AppRoutes.onboarding: (_) =>
            OnboardingPage(onboardingRepository: onboardingRepository),
        AppRoutes.learningGoal: (_) => const LearningGoalPage(),
        AppRoutes.pretest: (_) =>
            PretestPage(pretestRepository: pretestRepository),
        AppRoutes.home: (_) =>
            AppHomePage(curriculumRepository: curriculumRepository),
        AppRoutes.workspaceModules: (_) => const WorkspaceModulesPage(),
      },
    );
  }
}
