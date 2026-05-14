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
      displayName: 'Aisyah Putri',
      role: request.role,
      token: 'mock-session-token',
    );
  }

  @override
  Future<AuthSession> signInWithGoogle({required AuthRole role}) async {
    await Future<void>.delayed(delay);

    return AuthSession(
      userId: 'mock-google-learner',
      displayName: 'Google Learner',
      role: role,
      token: 'mock-google-session-token',
    );
  }

  @override
  Future<void> signOut() async {}
}
