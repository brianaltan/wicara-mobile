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
    this.refreshToken,
  });

  final String userId;
  final String displayName;
  final AuthRole role;
  final bool onboardingCompleted;
  final String? token;
  final String? refreshToken;

  AuthSession copyWith({
    String? userId,
    String? displayName,
    AuthRole? role,
    bool? onboardingCompleted,
    String? token,
    String? refreshToken,
  }) {
    return AuthSession(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      token: token ?? this.token,
      refreshToken: refreshToken ?? this.refreshToken,
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

  Future<AuthSession> signInWithGoogleIdToken({
    required String idToken,
    required String nonce,
    required AuthRole role,
  });

  Stream<AuthSession> googleSignInSessions({required AuthRole role});

  /// Exchange refresh_token for a fresh access_token.
  /// Returns null if refresh_token is invalid/expired (caller should sign out).
  Future<AuthSession?> refresh(AuthSession current);

  Future<void> signOut();
}
