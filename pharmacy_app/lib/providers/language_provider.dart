import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  LanguageProvider() {
    _loadLanguage();
  }

  void _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'en';
    _locale = Locale(languageCode);
    notifyListeners();
  }

  void setLanguage(String languageCode) async {
    if (_locale.languageCode == languageCode) return;

    _locale = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
    notifyListeners();

    // Tell the backend too, so push notifications switch language with the UI.
    // Without this the choice stays on the device and every push keeps
    // arriving in whatever language was set when the token was registered.
    _syncLanguageToBackend(languageCode);
  }

  /// Best-effort: a signed-out user has no token to authenticate with, and a
  /// failure here must never block the language actually changing on screen.
  /// The language is sent again with the FCM token at the next sign-in.
  static Future<void> _syncLanguageToBackend(String languageCode) async {
    try {
      await ApiService.post('/notifications/token', {'language': languageCode});
    } catch (e) {
      debugPrint('[language] could not save language to backend: $e');
    }
  }
}
