import 'package:flutter/material.dart';
import '../services/auth_service.dart';
export '../services/auth_service.dart' show AuthResult;
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
    await PushNotificationService.unregisterToken();
    await AuthService.logout();
    _user = null;
    _error = null;
    notifyListeners();
  }

  /// Permanently deletes the rider account on the backend, then clears the
  /// local session. Returns true on success.
  Future<bool> deleteAccount() async {
    try {
      final response = await ApiService.delete('/rider/profile');
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

  void updateUser(Map<String, dynamic> userData) {
    _user = User.fromJson(userData);
    AuthService.saveUserData(userData);
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    try {
      final res = await ApiService.get('/rider/profile');
      if (res.success && res.data != null && res.data['rider'] != null) {
        final riderData = Map<String, dynamic>.from(res.data['rider'] as Map);
        // fullName / phone live on the User document, not the rider document.
        // Merge over the existing user so these are never blanked if the
        // response doesn't carry them.
        final merged = <String, dynamic>{
          if (_user != null) ..._user!.toJson(),
          ...riderData,
        };
        if ((merged['fullName'] ?? '').toString().isEmpty && _user != null) {
          merged['fullName'] = _user!.fullName;
        }
        if ((merged['phone'] ?? '').toString().isEmpty && _user != null) {
          merged['phone'] = _user!.phone;
        }
        _user = User.fromJson(merged);
        AuthService.saveUserData(merged);
        notifyListeners();
      }
    } catch (_) {}
  }
}
