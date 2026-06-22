import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

class ApiService {
  static String get baseUrl => AppConstants.baseUrl;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  static Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (includeAuth) {
      final token = await _getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<ApiResponse> get(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl$endpoint'), headers: headers)
          .timeout(AppConstants.connectionTimeout);
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(success: false, message: _getErrorMessage(e));
    }
  }

  static Future<ApiResponse> post(String endpoint, Map<String, dynamic> data,
      {bool includeAuth = true}) async {
    try {
      final headers = await _getHeaders(includeAuth: includeAuth);
      final response = await http
          .post(Uri.parse('$baseUrl$endpoint'),
              headers: headers, body: json.encode(data))
          .timeout(AppConstants.connectionTimeout);
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(success: false, message: _getErrorMessage(e));
    }
  }

  static Future<ApiResponse> put(String endpoint, Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .put(Uri.parse('$baseUrl$endpoint'),
              headers: headers, body: json.encode(data))
          .timeout(AppConstants.connectionTimeout);
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(success: false, message: _getErrorMessage(e));
    }
  }

  static Future<ApiResponse> delete(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .delete(Uri.parse('$baseUrl$endpoint'), headers: headers)
          .timeout(AppConstants.connectionTimeout);
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(success: false, message: _getErrorMessage(e));
    }
  }

  static ApiResponse _handleResponse(http.Response response) {
    try {
      if (response.body.isEmpty) {
        return ApiResponse(
            success: response.statusCode < 300, message: 'No response');
      }
      if (response.body.contains('<html') || response.body.contains('<!DOCTYPE')) {
        return ApiResponse(
            success: false, message: 'Server error (${response.statusCode})');
      }
      final body = json.decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          success: body['success'] ?? true,
          message: body['message'] ?? 'Success',
          data: body['data'],
        );
      } else {
        return ApiResponse(
          success: false,
          message: body['message'] ?? 'Error ${response.statusCode}',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: 'Parse error: $e');
    }
  }

  static String _getErrorMessage(dynamic error) {
    final msg = error.toString();
    if (msg.contains('SocketException') || msg.contains('No internet')) {
      return 'No internet connection';
    } else if (msg.contains('TimeoutException')) {
      return 'Request timeout';
    }
    return 'Connection error';
  }
}

class ApiResponse {
  final bool success;
  final String message;
  final dynamic data;
  final dynamic errors;

  ApiResponse({required this.success, required this.message, this.data, this.errors});
}
