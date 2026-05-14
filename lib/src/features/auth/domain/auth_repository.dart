enum AuthRole {
  learner('Learner');

  const AuthRole(this.label);

  final String label;
}

class SignInRequest {
  const SignInRequest({
    required this.emailOrPhone,
    required this.password,
    required this.role,
  });

  final String emailOrPhone;
  final String password;
  final AuthRole role;
}

class RegisterRequest {
  const RegisterRequest({
    required this.email,
    required this.password,
    required this.displayName,
    required this.role,
  });

  final String email;
  final String password;
  final String displayName;
  final AuthRole role;
}

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.onboardingCompleted,
    this.token,
  });

  final String userId;
  final String displayName;
  final AuthRole role;
  final bool onboardingCompleted;
  final String? token;

  AuthSession copyWith({
    String? userId,
    String? displayName,
    AuthRole? role,
    bool? onboardingCompleted,
    String? token,
  }) {
    return AuthSession(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      token: token ?? this.token,
    );
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class AuthRepository {
  Future<AuthSession> signIn(SignInRequest request);

  Future<AuthSession> register(RegisterRequest request);

  Future<AuthSession> signInWithGoogle({required AuthRole role});

  Future<void> signOut();
}
