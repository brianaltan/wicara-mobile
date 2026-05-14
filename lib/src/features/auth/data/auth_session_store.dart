import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/app_routes.dart';
import '../domain/auth_repository.dart';

class PersistedAuthState {
  const PersistedAuthState({
    this.session,
    this.lastProtectedRoute,
  });

  final AuthSession? session;
  final String? lastProtectedRoute;
}

class AuthSessionStore {
  static const _userIdKey = 'auth.user_id';
  static const _displayNameKey = 'auth.display_name';
  static const _roleKey = 'auth.role';
  static const _tokenKey = 'auth.token';
  static const _onboardingCompletedKey = 'auth.onboarding_completed';
  static const _lastProtectedRouteKey = 'auth.lastProtectedRoute';

  AuthSession? _session;

  AuthSession? get currentSession => _session;

  String? get accessToken => _session?.token;

  Future<PersistedAuthState> read() async {
    final preferences = await SharedPreferences.getInstance();
    final userId = preferences.getString(_userIdKey)?.trim() ?? '';
    final displayName = preferences.getString(_displayNameKey)?.trim() ?? '';
    final roleName = preferences.getString(_roleKey)?.trim() ?? '';
    final token = preferences.getString(_tokenKey)?.trim();
    final lastProtectedRoute = preferences
        .getString(_lastProtectedRouteKey)
        ?.trim();

    if (userId.isEmpty || displayName.isEmpty || roleName.isEmpty) {
      return PersistedAuthState(
        lastProtectedRoute: _normalizeProtectedRoute(lastProtectedRoute),
      );
    }

    final session = AuthSession(
      userId: userId,
      displayName: displayName,
      role: _roleFromName(roleName),
      onboardingCompleted:
          preferences.getBool(_onboardingCompletedKey) ?? false,
      token: token == null || token.isEmpty ? null : token,
    );
    _session = session;

    return PersistedAuthState(
      session: session,
      lastProtectedRoute: _normalizeProtectedRoute(lastProtectedRoute),
    );
  }

  Future<void> save({
    required AuthSession session,
    required String lastProtectedRoute,
  }) async {
    _session = session;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_userIdKey, session.userId);
    await preferences.setString(_displayNameKey, session.displayName);
    await preferences.setString(_roleKey, session.role.name);
    if (session.token != null && session.token!.isNotEmpty) {
      await preferences.setString(_tokenKey, session.token!);
    } else {
      await preferences.remove(_tokenKey);
    }
    await preferences.setBool(
      _onboardingCompletedKey,
      session.onboardingCompleted,
    );
    await preferences.setString(
      _lastProtectedRouteKey,
      _normalizeProtectedRoute(lastProtectedRoute) ?? AppRoutes.onboarding,
    );
  }

  Future<void> markOnboardingCompleted({
    required String lastProtectedRoute,
    String? displayName,
  }) async {
    final session = _session;
    if (session == null) {
      return;
    }

    await save(
      session: session.copyWith(
        displayName: displayName?.trim().isNotEmpty == true
            ? displayName!.trim()
            : session.displayName,
        onboardingCompleted: true,
      ),
      lastProtectedRoute: lastProtectedRoute,
    );
  }

  Future<void> clear() async {
    _session = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_userIdKey);
    await preferences.remove(_displayNameKey);
    await preferences.remove(_roleKey);
    await preferences.remove(_tokenKey);
    await preferences.remove(_onboardingCompletedKey);
    await preferences.remove(_lastProtectedRouteKey);
  }

  AuthRole _roleFromName(String roleName) {
    return AuthRole.values.firstWhere(
      (role) => role.name == roleName,
      orElse: () => AuthRole.learner,
    );
  }

  String? _normalizeProtectedRoute(String? routeName) {
    if (routeName == null || routeName.isEmpty) {
      return null;
    }

    return AppRoutes.protectedRoutes.contains(routeName) ? routeName : null;
  }
}

final authSessionStore = AuthSessionStore();
