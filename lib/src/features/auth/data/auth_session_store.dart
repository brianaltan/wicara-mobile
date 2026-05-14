import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/app_routes.dart';
import '../domain/auth_repository.dart';

class PersistedAuthState {
  const PersistedAuthState({this.session, this.lastProtectedRoute});

  final AuthSession? session;
  final String? lastProtectedRoute;
}

class AuthSessionStore {
  static const _userIdKey = 'auth.userId';
  static const _displayNameKey = 'auth.displayName';
  static const _roleKey = 'auth.role';
  static const _tokenKey = 'auth.token';
  static const _lastProtectedRouteKey = 'auth.lastProtectedRoute';

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

    return PersistedAuthState(
      session: AuthSession(
        userId: userId,
        displayName: displayName,
        role: _roleFromName(roleName),
        token: token == null || token.isEmpty ? null : token,
      ),
      lastProtectedRoute: _normalizeProtectedRoute(lastProtectedRoute),
    );
  }

  Future<void> save({
    required AuthSession session,
    required String lastProtectedRoute,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_userIdKey, session.userId);
    await preferences.setString(_displayNameKey, session.displayName);
    await preferences.setString(_roleKey, session.role.name);
    if (session.token != null && session.token!.isNotEmpty) {
      await preferences.setString(_tokenKey, session.token!);
    } else {
      await preferences.remove(_tokenKey);
    }
    await preferences.setString(
      _lastProtectedRouteKey,
      _normalizeProtectedRoute(lastProtectedRoute) ?? AppRoutes.onboarding,
    );
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_userIdKey);
    await preferences.remove(_displayNameKey);
    await preferences.remove(_roleKey);
    await preferences.remove(_tokenKey);
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
