class AppRoutes {
  const AppRoutes._();

  static const landing = '/';
  static const signIn = '/auth/sign-in';
  static const onboarding = '/onboarding';
  static const learningGoal = '/learning-goal';
  static const pretest = '/pretest';
  static const home = '/home';
  static const workspaceModules = '/workspace-modules';

  static const protectedRoutes = <String>{
    onboarding,
    learningGoal,
    pretest,
    home,
    workspaceModules,
  };
}
