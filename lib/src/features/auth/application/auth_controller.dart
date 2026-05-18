import 'package:flutter/foundation.dart';

import '../../../app/app_routes.dart';
import '../../../core/network/api_client.dart';
import '../data/auth_session_store.dart';
import '../domain/auth_repository.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthRepository authRepository,
    required AuthSessionStore sessionStore,
    required ApiClient apiClient,
  }) : _authRepository = authRepository,
       _sessionStore = sessionStore,
       _apiClient = apiClient;

  final AuthRepository _authRepository;
  final AuthSessionStore _sessionStore;
  final ApiClient _apiClient;

  bool _isInitialized = false;
  AuthSession? _session;
  String? _lastProtectedRoute;

  bool get isInitialized => _isInitialized;
  bool get isSignedIn => _session != null;
  AuthSession? get session => _session;
  String get initialSignedInRoute {
    final session = _session;
    if (session == null) {
      return AppRoutes.landing;
    }
    if (!session.onboardingCompleted) {
      return AppRoutes.onboarding;
    }
    final lastRoute = _normalizeRestorableRoute(_lastProtectedRoute);
    return lastRoute == AppRoutes.onboarding
        ? AppRoutes.home
        : (lastRoute ?? AppRoutes.home);
  }

  Future<void> initialize() async {
    final persistedState = await _sessionStore.read();
    final restoredSession = persistedState.session;

    // A session without a token cannot authenticate API requests.
    // Treat it as signed-out and wipe storage to prevent a stuck state.
    if (restoredSession != null &&
        (restoredSession.token == null || restoredSession.token!.isEmpty)) {
      await _sessionStore.clear();
      _session = null;
      _lastProtectedRoute = null;
    } else {
      _session = restoredSession;
      _lastProtectedRoute = _normalizeRestorableRoute(
        persistedState.lastProtectedRoute,
      );
    }

    // Auto-refresh: try to get a fresh access_token using the stored refresh_token.
    // This prevents 401 errors when the 1-hour Supabase token has expired.
    final sessionToRefresh = _session;
    if (sessionToRefresh != null) {
      if (sessionToRefresh.refreshToken != null &&
          sessionToRefresh.refreshToken!.isNotEmpty) {
        try {
          final refreshed = await _authRepository.refresh(sessionToRefresh);
          if (refreshed != null) {
            _session = refreshed;
            _lastProtectedRoute = _normalizeRestorableRoute(
              persistedState.lastProtectedRoute,
            );
            await _sessionStore.save(
              session: refreshed,
              lastProtectedRoute:
                  _lastProtectedRoute ??
                  (refreshed.onboardingCompleted ? '/home' : '/onboarding'),
            );
          } else {
            // Refresh token also expired — force sign-out cleanly
            await _sessionStore.clear();
            _session = null;
            _lastProtectedRoute = null;
          }
        } catch (_) {
          // Refresh failed (e.g. network error). Clear the session so the user
          // is redirected to sign-in instead of landing on home with a bad token.
          await _sessionStore.clear();
          _session = null;
          _lastProtectedRoute = null;
        }
      } else {
        // Missing refresh token entirely (e.g., legacy session).
        // Since we cannot keep it alive and it's likely expired, force sign out.
        await _sessionStore.clear();
        _session = null;
        _lastProtectedRoute = null;
      }
    }

    _apiClient.setAuthToken(_session?.token);
    _isInitialized = true;
    notifyListeners();
  }

  Future<AuthSession> signIn(SignInRequest request) async {
    final session = await _authRepository.signIn(request);
    await _setSession(session, lastProtectedRoute: AppRoutes.onboarding);
    return session;
  }

  Future<AuthSession> signInWithGoogle({required AuthRole role}) async {
    final session = await _authRepository.signInWithGoogle(role: role);
    await _setSession(session, lastProtectedRoute: AppRoutes.onboarding);
    return session;
  }

  Future<AuthSession> signInWithGoogleIdToken({
    required String idToken,
    required String nonce,
    required AuthRole role,
  }) async {
    final session = await _authRepository.signInWithGoogleIdToken(
      idToken: idToken,
      nonce: nonce,
      role: role,
    );
    await _setSession(session, lastProtectedRoute: AppRoutes.onboarding);
    return session;
  }

  Future<AuthSession> register(RegisterRequest request) async {
    final session = await _authRepository.register(request);
    await _setSession(session, lastProtectedRoute: AppRoutes.onboarding);
    return session;
  }

  Future<AuthSession> startDevelopmentSession({
    required AuthRole role,
    String? displayName,
    bool onboardingCompleted = false,
  }) async {
    final session = AuthSession(
      userId: 'dev-web-learner',
      displayName: _normalizeDisplayName(displayName),
      role: role,
      onboardingCompleted: onboardingCompleted,
      token: 'dev-session-token',
    );
    await _setSession(
      session,
      lastProtectedRoute: onboardingCompleted
          ? AppRoutes.home
          : AppRoutes.onboarding,
    );
    return session;
  }

  Future<void> markOnboardingCompleted({String? displayName}) async {
    final session = _session;
    if (session == null) {
      return;
    }

    _session = session.copyWith(
      displayName: displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : session.displayName,
      onboardingCompleted: true,
    );
    _lastProtectedRoute = AppRoutes.home;
    await _persistCurrentState();
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await _authRepository.signOut();
    } finally {
      _session = null;
      _lastProtectedRoute = null;
      _apiClient.clearAuthToken();
      await _sessionStore.clear();
      notifyListeners();
    }
  }

  Future<void> markRouteVisited(String? routeName) async {
    if (!isSignedIn || routeName == null) {
      return;
    }
    if (!_isRestorableProtectedRoute(routeName)) {
      return;
    }
    if (_lastProtectedRoute == routeName) {
      return;
    }

    _lastProtectedRoute = routeName;
    await _persistCurrentState();
  }

  Future<void> _setSession(
    AuthSession session, {
    required String lastProtectedRoute,
  }) async {
    _session = session;
    _lastProtectedRoute = lastProtectedRoute;
    _apiClient.setAuthToken(session.token);
    await _persistCurrentState();
    notifyListeners();
  }

  Future<void> _persistCurrentState() async {
    final session = _session;
    final route = _lastProtectedRoute;
    if (session == null || route == null) {
      return;
    }
    await _sessionStore.save(session: session, lastProtectedRoute: route);
  }

  String _normalizeDisplayName(String? displayName) {
    final normalized = displayName?.trim();
    if (normalized == null || normalized.isEmpty) {
      return 'Dev Learner';
    }

    return normalized;
  }

  bool _isRestorableProtectedRoute(String routeName) {
    if (!AppRoutes.protectedRoutes.contains(routeName)) {
      return false;
    }
    return routeName != AppRoutes.pretest &&
        routeName != AppRoutes.edgeAiSettings &&
        routeName != AppRoutes.workspaceModules;
  }

  String? _normalizeRestorableRoute(String? routeName) {
    if (routeName == null || routeName.trim().isEmpty) {
      return null;
    }
    return _isRestorableProtectedRoute(routeName) ? routeName : null;
  }
}
