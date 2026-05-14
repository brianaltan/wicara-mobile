import '../domain/auth_repository.dart';

class AuthSessionStore {
  AuthSession? _session;

  AuthSession? get currentSession => _session;

  String? get accessToken => _session?.token;

  void save(AuthSession session) {
    _session = session;
  }

  void clear() {
    _session = null;
  }
}

final authSessionStore = AuthSessionStore();
