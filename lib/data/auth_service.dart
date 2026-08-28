import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AuthService {
  Future<bool> signUp({
    required String displayName,
    required String email,
    required String password,
  });

  Future<void> signIn({required String email, required String password});

  Future<void> resendSignupConfirmation(String email);
}

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client);

  static const _requestTimeout = Duration(seconds: 20);

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
  Future<void> resendSignupConfirmation(String email) async {
    await _client.auth
        .resend(type: OtpType.signup, email: email)
        .timeout(_requestTimeout);
  }
}
