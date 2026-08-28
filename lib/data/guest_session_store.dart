import 'package:shared_preferences/shared_preferences.dart';

class GuestSessionStore {
  static const _key = 'temporary_guest_mode_enabled';

  Future<bool> load() async {
    try {
      return await SharedPreferencesAsync().getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setEnabled(bool enabled) {
    return SharedPreferencesAsync().setBool(_key, enabled);
  }
}
