import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocalProfile {
  const LocalProfile({
    required this.displayName,
    this.avatarPath,
    this.avatarStoragePath,
  });

  final String displayName;
  final String? avatarPath;
  final String? avatarStoragePath;
}

class LocalProfileStore {
  LocalProfileStore(this.scope, {this.supabaseClient});

  final String scope;
  final SupabaseClient? supabaseClient;
  String? _remoteAvatarStoragePath;

  String get _key => 'local_profile_$scope';

  Future<LocalProfile?> load() async {
    final client = supabaseClient;
    final user = client?.auth.currentUser;
    if (client != null && user != null) {
      final row = await client
          .from('chat_profiles')
          .select('display_name, avatar_path')
          .eq('user_id', user.id)
          .single();
      final storagePath = row['avatar_path'] as String?;
      _remoteAvatarStoragePath = storagePath;
      String? avatarUrl;
      if (storagePath != null && storagePath.isNotEmpty) {
        avatarUrl = await client.storage
            .from('profile-avatars')
            .createSignedUrl(storagePath, 60 * 60);
      }
      return LocalProfile(
        displayName: row['display_name'] as String,
        avatarPath: avatarUrl,
        avatarStoragePath: storagePath,
      );
    }
    try {
      final value = await SharedPreferencesAsync().getString(_key);
      if (value == null) return null;
      final json = jsonDecode(value) as Map<String, dynamic>;
      return LocalProfile(
        displayName: json['displayName'] as String,
        avatarPath: json['avatarPath'] as String?,
        avatarStoragePath: json['avatarStoragePath'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(LocalProfile profile) async {
    final client = supabaseClient;
    final user = client?.auth.currentUser;
    if (client != null && user != null) {
      var storagePath = profile.avatarStoragePath ?? _remoteAvatarStoragePath;
      final avatarPath = profile.avatarPath;
      if (avatarPath != null &&
          avatarPath.isNotEmpty &&
          !avatarPath.startsWith('http://') &&
          !avatarPath.startsWith('https://')) {
        storagePath = '${user.id}/avatar.jpg';
        await client.storage
            .from('profile-avatars')
            .upload(
              storagePath,
              File(avatarPath),
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                cacheControl: '3600',
                upsert: true,
              ),
            );
        _remoteAvatarStoragePath = storagePath;
      }
      await client
          .from('chat_profiles')
          .update({
            'display_name': profile.displayName,
            'avatar_path': storagePath,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', user.id);
      await client.auth.updateUser(
        UserAttributes(data: {'display_name': profile.displayName}),
      );
      return;
    }
    try {
      await SharedPreferencesAsync().setString(
        _key,
        jsonEncode({
          'displayName': profile.displayName,
          'avatarPath': profile.avatarPath,
          'avatarStoragePath': profile.avatarStoragePath,
        }),
      );
    } catch (_) {
      // Unsupported test/desktop targets can still use the in-memory profile.
    }
  }
}
