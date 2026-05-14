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
       _sessionStore = sessionStore,
       _googleSignIn = kIsWeb
           ? null
           : GoogleSignIn(
               scopes: const ['email', 'profile'],
               clientId: googleWebClientId.isEmpty ? null : googleWebClientId,
               serverClientId: googleWebClientId.isEmpty
                   ? null
                   : googleWebClientId,
             );

  final ApiClient _apiClient;
  final AuthSessionStore _sessionStore;
  final GoogleSignIn? _googleSignIn;

  @override
  Stream<AuthSession> googleSignInSessions({required AuthRole role}) {
    final googleSignIn = _googleSignIn;
    if (googleSignIn == null) {
      return const Stream<AuthSession>.empty();
    }
    return googleSignIn.onCurrentUserChanged
        .where((account) => account != null)
        .asyncMap((account) => _exchangeGoogleAccount(account!, role));
  }

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
      final googleSignIn = _googleSignIn;
      if (googleSignIn == null) {
        throw const AuthException(
          'Google web sign-in must use the Google-rendered button.',
        );
      }
      final account = await googleSignIn.signIn();
      if (account == null) {
        throw const AuthException('Google sign-in was cancelled.');
      }
      return await _exchangeGoogleAccount(account, role);
    } on AuthException {
      rethrow;
    } on ApiClientException catch (error) {
      throw AuthException(error.message);
    } catch (error) {
      throw AuthException('Google sign-in failed: $error');
    }
  }

  @override
  Future<AuthSession> signInWithGoogleIdToken({
    required String idToken,
    required String nonce,
    required AuthRole role,
  }) {
    return _exchangeGoogleTokens(
      idToken: idToken,
      accessToken: null,
      nonce: nonce,
      role: role,
    );
  }

  Future<AuthSession> _exchangeGoogleAccount(
    GoogleSignInAccount account,
    AuthRole role,
  ) async {
    try {
      final auth = await account.authentication;
      return await _exchangeGoogleTokens(
        idToken: auth.idToken,
        accessToken: auth.accessToken,
        nonce: null,
        role: role,
      );
    } on AuthException {
      rethrow;
    } on ApiClientException catch (error) {
      throw AuthException(error.message);
    } catch (error) {
      throw AuthException('Google sign-in failed: $error');
    }
  }

  Future<AuthSession> _exchangeGoogleTokens({
    required String? idToken,
    required String? accessToken,
    required String? nonce,
    required AuthRole role,
  }) async {
    try {
      if (idToken == null || idToken.isEmpty) {
        throw const AuthException(
          'Google did not return idToken. On web, use the Google-rendered sign-in button.',
        );
      }
      if (!kIsWeb && (accessToken == null || accessToken.isEmpty)) {
        throw const AuthException('Google did not return accessToken.');
      }

      final body = <String, String>{'id_token': idToken, 'role': role.name};
      if (accessToken != null && accessToken.isNotEmpty) {
        body['access_token'] = accessToken;
      }
      if (nonce != null && nonce.isNotEmpty) {
        body['nonce'] = nonce;
      }

      final json = await _apiClient.postJson('/api/v1/auth/google', body: body);
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
      await _googleSignIn?.signOut();
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
