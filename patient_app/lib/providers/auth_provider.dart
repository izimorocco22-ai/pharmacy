import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/push_notification_service.dart';
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
        // First load from local storage for fast startup
        _user = await AuthService.getCurrentUser();
        notifyListeners();
        // Then refresh from backend to get latest data including profileImage
        await refreshProfile();
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

  Future<bool> loginWithOtp(String phone, String otp) async {
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
      return result.success;
    } catch (e) {
      _error = 'Login failed';
      _isLoading = false;
      notifyListeners();
      return false;
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

  Future<bool> register(Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await AuthService.register(data);

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
      _error = 'Registration failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await PushNotificationService.unregisterToken();
    await AuthService.logout();
    _user = null;
    _error = null;
    notifyListeners();
  }

  /// Permanently deletes the current account on the backend, then clears
  /// local session. Returns true on success.
  Future<bool> deleteAccount() async {
    try {
      final response = await ApiService.delete('/patients/profile');
      if (response.success) {
        await AuthService.logout();
        _user = null;
        _error = null;
        notifyListeners();
        return true;
      }
      _error = response.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to delete account';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void updateUser(Map<String, dynamic> userData) {
    _user = User.fromJson(userData);
    AuthService.saveUser(_user!);
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    try {
      final response = await ApiService.get('/patients/profile');
      if (response.success && response.data != null && response.data['user'] != null) {
        _user = User.fromJson(response.data['user']);
        await AuthService.saveUser(_user!);
        notifyListeners();
      }
    } catch (e) {
      // ignore
    }
  }
}
