import '../domain/auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  const MockAuthRepository({this.delay = const Duration(milliseconds: 450)});

  final Duration delay;

  @override
  Future<AuthSession> signIn(SignInRequest request) async {
    await Future<void>.delayed(delay);

    if (request.emailOrPhone.trim().isEmpty || request.password.isEmpty) {
      throw const AuthException('Please enter your email and password.');
    }

    return AuthSession(
      userId: 'mock-learner-001',
      displayName: request.emailOrPhone.trim(),
      role: request.role,
      onboardingCompleted: true,
      token: 'mock-session-token',
    );
  }

  @override
  Future<AuthSession> register(RegisterRequest request) async {
    await Future<void>.delayed(delay);

    if (request.email.trim().isEmpty || request.password.isEmpty) {
      throw const AuthException('Please enter your email and password.');
    }

    return AuthSession(
      userId: 'mock-registered-learner',
      displayName: request.displayName.trim().isEmpty
          ? request.email.trim()
          : request.displayName.trim(),
      role: request.role,
      onboardingCompleted: false,
      token: 'mock-registered-session-token',
    );
  }

  @override
  Future<AuthSession> signInWithGoogle({required AuthRole role}) async {
    await Future<void>.delayed(delay);

    return AuthSession(
      userId: 'mock-google-learner',
      displayName: 'Google Learner',
      role: role,
      onboardingCompleted: true,
      token: 'mock-google-session-token',
    );
  }

  @override
  Future<AuthSession> signInWithGoogleIdToken({
    required String idToken,
    required String nonce,
    required AuthRole role,
  }) {
    return signInWithGoogle(role: role);
  }

  @override
  Stream<AuthSession> googleSignInSessions({required AuthRole role}) {
    return const Stream<AuthSession>.empty();
  }

  @override
  Future<AuthSession?> refresh(AuthSession current) async {
    // Mock: always succeeds with same session (no real expiry in mock)
    return current;
  }

  @override
  Future<void> signOut() async {}
}
