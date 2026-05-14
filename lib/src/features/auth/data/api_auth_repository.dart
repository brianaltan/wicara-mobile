import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/network/api_client.dart';
import '../domain/auth_repository.dart';
import 'auth_session_store.dart';

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({
    required ApiClient apiClient,
    required AuthSessionStore sessionStore,
    required String googleWebClientId,
  }) : _apiClient = apiClient,
       _googleWebClientId = googleWebClientId.trim(),
       _sessionStore = sessionStore,
       _googleSignIn = GoogleSignIn(
         scopes: const ['email', 'profile'],
         clientId: googleWebClientId.isEmpty ? null : googleWebClientId,
         serverClientId: kIsWeb || googleWebClientId.isEmpty
             ? null
             : googleWebClientId,
       );

  final ApiClient _apiClient;
  final String _googleWebClientId;
  final AuthSessionStore _sessionStore;
  final GoogleSignIn _googleSignIn;

  @override
  Future<AuthSession> signIn(SignInRequest request) async {
    try {
      final json = await _apiClient.postJson(
        '/api/v1/auth/sign-in',
        body: {
          'email_or_phone': request.emailOrPhone.trim(),
          'password': request.password,
          'role': request.role.name,
        },
      );
      final session = _toAuthSession(json, request.role);
      await _sessionStore.save(
        session: session,
        lastProtectedRoute: session.onboardingCompleted
            ? '/home'
            : '/onboarding',
      );
      return session;
    } on ApiClientException catch (error) {
      throw AuthException(error.message);
    }
  }

  @override
  Future<AuthSession> register(RegisterRequest request) async {
    try {
      final json = await _apiClient.postJson(
        '/api/v1/auth/register',
        body: {
          'email': request.email.trim(),
          'password': request.password,
          'display_name': request.displayName.trim(),
          'role': request.role.name,
        },
      );
      final session = _toAuthSession(json, request.role);
      await _sessionStore.save(
        session: session,
        lastProtectedRoute: session.onboardingCompleted
            ? '/home'
            : '/onboarding',
      );
      return session;
    } on ApiClientException catch (error) {
      throw AuthException(error.message);
    }
  }

  @override
  Future<AuthSession> signInWithGoogle({required AuthRole role}) async {
    try {
      if (kIsWeb && _googleWebClientId.isEmpty) {
        throw const AuthException(
          'Google web client ID is missing. Set WICARA_GOOGLE_WEB_CLIENT_ID '
          'with --dart-define or add a '
          '<meta name="google-signin-client_id" content="..."> tag in web/index.html.',
        );
      }

      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw const AuthException('Google sign-in was cancelled.');
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthException(
          'Google did not return idToken. Set serverClientId/web client id.',
        );
      }

      final json = await _apiClient.postJson(
        '/api/v1/auth/google',
        body: {
          'id_token': idToken,
          'access_token': auth.accessToken,
          'role': role.name,
        },
      );
      final session = _toAuthSession(json, role);
      await _sessionStore.save(
        session: session,
        lastProtectedRoute: session.onboardingCompleted
            ? '/home'
            : '/onboarding',
      );
      return session;
    } on AuthException {
      rethrow;
    } on ApiClientException catch (error) {
      throw AuthException(error.message);
    } catch (error) {
      throw AuthException('Google sign-in failed: $error');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // We still clear the local app session even if Google sign-out fails.
    }
  }

  AuthSession _toAuthSession(Map<String, dynamic> json, AuthRole role) {
    final token = (json['token'] ?? '').toString().trim();

    return AuthSession(
      userId: (json['user_id'] ?? '').toString(),
      displayName: (json['display_name'] ?? '').toString(),
      role: role,
      onboardingCompleted: json['onboarding_completed'] == true,
      token: token.isEmpty ? null : token,
    );
  }
}
