// services/shared_prefs_service.dart


import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsService {
  static const String _authTokenKey = 'authToken';
  static const String _nameKey = 'name';
  static const String _emailKey = 'email';
  static const String _isLoggedInKey = 'isLoggedIn';

  static Future<void> saveUserData({
    required String authToken,
    required String name,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authTokenKey, authToken);
    await prefs.setString(_nameKey, name);
    await prefs.setString(_emailKey, email);
    await prefs.setBool(_isLoggedInKey, true);
  }

  static Future<Map<String, String?>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'authToken': prefs.getString(_authTokenKey),
      'name': prefs.getString(_nameKey),
      'email': prefs.getString(_emailKey),
    };
  }

  static Future<bool> isUserLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authTokenKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_isLoggedInKey);
  }
}