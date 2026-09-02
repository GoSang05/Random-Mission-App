import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthActionCancelled implements Exception {
  const AuthActionCancelled();
}

class AuthConfigurationException implements Exception {
  const AuthConfigurationException(this.message);

  final String message;
}

abstract interface class AuthService {
  Future<void> signUp({
    required String displayName,
    required String loginId,
    required String password,
  });

  Future<void> signIn({required String loginId, required String password});

  Future<void> signInWithGoogle();
}

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client);

  static const _requestTimeout = Duration(seconds: 20);
  static const _googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );
  static const _googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );
  static const _googleScopes = <String>[
    'https://www.googleapis.com/auth/userinfo.email',
    'https://www.googleapis.com/auth/userinfo.profile',
  ];

  final SupabaseClient _client;

  @override
  Future<void> signUp({
    required String displayName,
    required String loginId,
    required String password,
  }) async {
    await _client.auth
        .signUp(
          email: _authEmail(loginId),
          password: password,
          data: {
            'display_name': displayName,
            'login_id': loginId.trim().toLowerCase(),
          },
        )
        .timeout(_requestTimeout);
  }

  @override
  Future<void> signIn({
    required String loginId,
    required String password,
  }) async {
    await _client.auth
        .signInWithPassword(email: _authEmail(loginId), password: password)
        .timeout(_requestTimeout);
  }

  /// Supabase password auth requires an email or phone identifier. The app
  /// exposes a username-like ID and maps it deterministically to an internal
  /// address. Addresses entered by existing users remain valid for migration.
  static String _authEmail(String loginId) {
    final normalized = loginId.trim().toLowerCase();
    if (normalized.contains('@')) return normalized;
    return '$normalized@id.doitapp.app';
  }

  @override
  Future<void> signInWithGoogle() async {
    if (_googleWebClientId.isEmpty) {
      throw const AuthConfigurationException('Google 로그인 설정이 아직 완료되지 않았어요.');
    }
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      await _client.auth.signInWithOAuth(OAuthProvider.google);
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        _googleIosClientId.isEmpty) {
      throw const AuthConfigurationException(
        'iOS Google 로그인 설정이 아직 완료되지 않았어요.',
      );
    }

    try {
      final signIn = GoogleSignIn.instance;
      await signIn.initialize(
        clientId: defaultTargetPlatform == TargetPlatform.iOS
            ? _googleIosClientId
            : null,
        serverClientId: _googleWebClientId,
      );
      final account = await signIn.authenticate(scopeHint: _googleScopes);
      final authorization =
          await account.authorizationClient.authorizationForScopes(
            _googleScopes,
          ) ??
          await account.authorizationClient.authorizeScopes(_googleScopes);
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthConfigurationException('Google에서 로그인 토큰을 받지 못했어요.');
      }
      await _client.auth
          .signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
            accessToken: authorization.accessToken,
          )
          .timeout(_requestTimeout);
    } on GoogleSignInException catch (error) {
      debugPrint(
        'Google sign-in failed: ${error.code.name}; ${error.description ?? 'no description'}',
      );
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthActionCancelled();
      }
      final message = switch (error.code) {
        GoogleSignInExceptionCode.clientConfigurationError =>
          'Google 앱 설정이 현재 설치된 앱과 맞지 않아요. 앱을 최신 빌드로 다시 설치해 주세요.',
        GoogleSignInExceptionCode.providerConfigurationError =>
          '기기의 Google Play 서비스에서 로그인을 사용할 수 없어요. Play 서비스를 업데이트한 뒤 다시 시도해 주세요.',
        GoogleSignInExceptionCode.uiUnavailable =>
          'Google 계정 선택 화면을 열지 못했어요. 앱을 다시 연 뒤 시도해 주세요.',
        GoogleSignInExceptionCode.interrupted =>
          'Google 로그인이 중단됐어요. 잠시 후 다시 시도해 주세요.',
        GoogleSignInExceptionCode.userMismatch =>
          '선택한 Google 계정이 현재 로그인 계정과 달라요. 다시 선택해 주세요.',
        _ => 'Google 로그인에 실패했어요. 오류 코드: ${error.code.name}',
      };
      throw AuthConfigurationException(message);
    }
  }
}
