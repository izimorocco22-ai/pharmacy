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

  void setUser(User user) {
    _user = user;
    notifyListeners();
  }

  Future<void> checkAuth() async {
    _isLoading = true;
    notifyListeners();
    try {
      final isLoggedIn = await AuthService.isLoggedIn();
      if (isLoggedIn) {
        _user = await AuthService.getCurrentUser();
        // If user data missing from prefs but token exists, keep logged in
        _user ??= User(
          id: '',
          fullName: 'Pharmacy',
          email: '',
          phone: '',
          role: 'pharmacy',
          isVerified: true,
        );
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

  Future<bool> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String pharmacyName,
    required String licenseNumber,
    required String address,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await ApiService.post('/auth/register', {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'password': password,
        'role': 'pharmacy',
        'pharmacyName': pharmacyName,
        'licenseNumber': licenseNumber,
        'address': address,
        'coordinates': [0.0, 0.0],
      }, includeAuth: false);

      if (response.success && response.data != null) {
        await AuthService.saveToken(response.data['token']);
        await AuthService.saveUserData(response.data['user']);
        _user = User.fromJson(response.data['user']);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response.message;
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

  /// Permanently deletes the pharmacy account on the backend, then clears the
  /// local session. Returns true on success.
  Future<bool> deleteAccount() async {
    try {
      final response = await ApiService.delete('/pharmacy/profile');
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

  Future<bool> updateProfile({required String fullName, required String phone}) async {
    try {
      final response = await ApiService.put('/pharmacy/profile', {
        'fullName': fullName,
        'phone': phone,
      });
      if (response.success && response.data != null) {
        final userData = response.data['user'];
        if (userData != null) {
          await AuthService.saveUserData(userData);
          _user = User.fromJson(userData);
          notifyListeners();
        }
      }
      return response.success;
    } catch (e) {
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await ApiService.put('/pharmacy/profile', {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
      return response.success;
    } catch (e) {
      return false;
    }
  }
}
