import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../models/user_model.dart';
import '../core/constants/app_constants.dart';

class AuthService {
  static Future<AuthResult> sendOtp(String phone) async {
    final response = await ApiService.post(
      '/auth/rider-send-otp',
      {'phone': phone},
      includeAuth: false,
    );
    return AuthResult(success: response.success, message: response.message);
  }

  static Future<AuthResult> loginWithOtp(String phone, String otp) async {
    final response = await ApiService.post(
      '/auth/rider-login',
      {'phone': phone, 'otp': otp},
      includeAuth: false,
    );

    if (response.success && response.data != null) {
      final token = response.data['token'];
      final userData = response.data['user'];

      await _saveToken(token);
      await _saveUser(userData);

      return AuthResult(
        success: true,
        message: response.message,
        user: User.fromJson(userData),
        approvalStatus: response.data['approvalStatus'],
        adminNote: response.data['adminNote'] ?? '',
      );
    }

    return AuthResult(success: false, message: response.message);
  }

  static Future<AuthResult> login(String email, String password) async {
    final response = await ApiService.post(
      '/auth/login',
      {'email': email, 'password': password, 'role': 'rider'},
      includeAuth: false,
    );

    if (response.success && response.data != null) {
      final token = response.data['token'];
      final userData = response.data['user'];

      await _saveToken(token);
      await _saveUser(userData);

      return AuthResult(
        success: true,
        message: response.message,
        user: User.fromJson(userData),
      );
    }

    return AuthResult(
      success: false,
      message: response.message,
    );
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userKey);
  }

  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userKey, json.encode(userData));
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(AppConstants.tokenKey);
  }

  static Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(AppConstants.userKey);
    
    if (userJson != null) {
      return User.fromJson(json.decode(userJson));
    }
    return null;
  }

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
  }

  static Future<void> _saveUser(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userKey, json.encode(userData));
  }
}

class AuthResult {
  final bool success;
  final String message;
  final User? user;
  final String? approvalStatus;
  final String? adminNote;

  AuthResult({
    required this.success,
    required this.message,
    this.user,
    this.approvalStatus,
    this.adminNote,
  });
}
