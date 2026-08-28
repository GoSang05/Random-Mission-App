import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalProfile {
  const LocalProfile({required this.displayName, this.avatarPath});

  final String displayName;
  final String? avatarPath;
}

class LocalProfileStore {
  LocalProfileStore(this.scope);

  final String scope;

  String get _key => 'local_profile_$scope';

  Future<LocalProfile?> load() async {
    try {
      final value = await SharedPreferencesAsync().getString(_key);
      if (value == null) return null;
      final json = jsonDecode(value) as Map<String, dynamic>;
      return LocalProfile(
        displayName: json['displayName'] as String,
        avatarPath: json['avatarPath'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(LocalProfile profile) async {
    try {
      await SharedPreferencesAsync().setString(
        _key,
        jsonEncode({
          'displayName': profile.displayName,
          'avatarPath': profile.avatarPath,
        }),
      );
    } catch (_) {
      // Unsupported test/desktop targets can still use the in-memory profile.
    }
  }
}
