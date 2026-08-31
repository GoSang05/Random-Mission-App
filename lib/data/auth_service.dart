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
  Future<bool> signUp({
    required String displayName,
    required String email,
    required String password,
  });

  Future<void> signIn({required String email, required String password});

  Future<void> signInWithGoogle();

  Future<void> resendSignupConfirmation(String email);
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

  final SupabaseClient _client;

  @override
  Future<bool> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final response = await _client.auth
        .signUp(
          email: email,
          password: password,
          data: {'display_name': displayName},
        )
        .timeout(_requestTimeout);
    return response.session == null;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth
        .signInWithPassword(email: email, password: password)
        .timeout(_requestTimeout);
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
      final account = await signIn.authenticate();
      final authorization = await account.authorizationClient
          .authorizationForScopes(const []);
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthConfigurationException('Google에서 로그인 토큰을 받지 못했어요.');
      }
      await _client.auth
          .signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
            accessToken: authorization?.accessToken,
          )
          .timeout(_requestTimeout);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthActionCancelled();
      }
      throw const AuthConfigurationException('Google 로그인 설정을 확인해 주세요.');
    }
  }

  @override
  Future<void> resendSignupConfirmation(String email) async {
    await _client.auth
        .resend(type: OtpType.signup, email: email)
        .timeout(_requestTimeout);
  }
}
