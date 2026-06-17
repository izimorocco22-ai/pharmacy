import 'package:flutter/material.dart';
import '../services/auth_service.dart';
export '../services/auth_service.dart' show AuthResult;
import '../services/api_service.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  Future<void> checkAuth() async {
    _isLoading = true;
    notifyListeners();
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      if (isLoggedIn) {
        _user = await AuthService.getCurrentUser();
      }
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> sendOtp(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await AuthService.sendOtp(phone);
      _error = result.success ? null : result.message;
      _isLoading = false;
      notifyListeners();
      return result.success;
    } catch (e) {
      _error = 'Failed to send OTP';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<AuthResult?> loginWithOtp(String phone, String otp) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await AuthService.loginWithOtp(phone, otp);
      if (result.success) {
        _user = result.user;
      } else {
        _error = result.message;
      }
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _error = 'Login failed';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await AuthService.login(email, password);
      if (result.success) {
        _user = result.user;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result.message;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Login failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await AuthService.logout();
    _user = null;
    _error = null;
    notifyListeners();
  }

  void updateUser(Map<String, dynamic> userData) {
    _user = User.fromJson(userData);
    AuthService.saveUserData(userData);
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    try {
      final res = await ApiService.get('/rider/profile');
      if (res.success && res.data != null) {
        final userData = res.data['rider'];
        _user = User.fromJson(userData);
        AuthService.saveUserData(userData);
        notifyListeners();
      }
    } catch (_) {}
  }
}
