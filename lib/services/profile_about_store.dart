import 'package:shared_preferences/shared_preferences.dart';

class ProfileAboutStore {
  static const _aboutPrefix = 'profile_about_';

  static Future<String> getAbout(String userId, String fallback) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('$_aboutPrefix$userId')?.trim();
    return saved == null || saved.isEmpty ? fallback : saved;
  }

  static Future<void> saveAbout(String userId, String about) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_aboutPrefix$userId', about.trim());
  }
}
