import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  static Future<AuthResult> sendOtp(String phone) async {
    try {
      final response = await ApiService.post(
        '/auth/patient-send-otp',
        {'phone': phone},
        includeAuth: false,
      );
      return AuthResult(success: response.success, message: response.message);
    } catch (e) {
      return AuthResult(success: false, message: 'Failed to send OTP');
    }
  }

  static Future<AuthResult> loginWithOtp(String phone, String otp) async {
    try {
      final response = await ApiService.post(
        '/auth/patient-login',
        {'phone': phone, 'otp': otp},
        includeAuth: false,
      );

      if (response.success) {
        final token = response.data['token'];
        final user = User.fromJson(response.data['user']);
        await _saveAuthData(token, user);
        return AuthResult(success: true, user: user);
      } else {
        return AuthResult(success: false, message: response.message);
      }
    } catch (e) {
      return AuthResult(success: false, message: 'Login failed');
    }
  }

  static Future<AuthResult> login(String email, String password) async {
    try {
      final response = await ApiService.post(
        '/auth/login',
        {
          'email': email,
          'password': password,
          'role': 'patient',
        },
        includeAuth: false,
      );

      if (response.success) {
        final token = response.data['token'];
        final user = User.fromJson(response.data['user']);

        await _saveAuthData(token, user);

        return AuthResult(success: true, user: user);
      } else {
        return AuthResult(success: false, message: response.message);
      }
    } catch (e) {
      return AuthResult(success: false, message: 'Login failed');
    }
  }

  static Future<AuthResult> register(Map<String, dynamic> data) async {
    try {
      final response = await ApiService.post(
        '/auth/register',
        data,
        includeAuth: false,
      );

      if (response.success) {
        final token = response.data['token'];
        final user = User.fromJson(response.data['user']);

        await _saveAuthData(token, user);

        return AuthResult(success: true, user: user);
      } else {
        return AuthResult(success: false, message: response.message);
      }
    } catch (e) {
      return AuthResult(success: false, message: 'Registration failed');
    }
  }

  static Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userKey, json.encode(user.toJson()));
  }

  static Future<void> _saveAuthData(String token, User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
    await saveUser(user);
  }

  static Future<User?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString(AppConstants.userKey);

      if (userData != null) {
        return User.fromJson(json.decode(userData));
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(AppConstants.tokenKey);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userKey);
  }

  static Future<void> updateFcmToken(String fcmToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.fcmTokenKey, fcmToken);
  }
}

class AuthResult {
  final bool success;
  final String? message;
  final User? user;

  AuthResult({
    required this.success,
    this.message,
    this.user,
  });
}
