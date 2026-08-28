import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalMagazineStore {
  LocalMagazineStore(this.storageKey);

  final String storageKey;

  Future<List<String>> loadPhotoPaths() async {
    try {
      final encoded = await SharedPreferencesAsync().getString(storageKey);
      if (encoded == null || encoded.isEmpty) return const [];
      return (jsonDecode(encoded) as List<dynamic>).cast<String>();
    } catch (_) {
      return const [];
    }
  }

  Future<void> savePhotoPaths(Iterable<String> paths) {
    return SharedPreferencesAsync().setString(
      storageKey,
      jsonEncode(paths.toList()),
    );
  }
}
