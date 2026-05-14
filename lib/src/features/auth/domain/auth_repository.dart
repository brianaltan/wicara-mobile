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

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.displayName,
    required this.role,
    this.token,
  });

  final String userId;
  final String displayName;
  final AuthRole role;
  final String? token;
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class AuthRepository {
  Future<AuthSession> signIn(SignInRequest request);

  Future<AuthSession> signInWithGoogle({required AuthRole role});

  Future<void> signOut();
}
