import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // API Configuration
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'https://pharmacy-zeta-seven.vercel.app/api';
  
  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String fcmTokenKey = 'fcm_token';
  
  // Pagination
  static const int pageSize = 20;
  
  // Map Configuration
  static const double defaultZoom = 15.0;
  static const double nearbyRadius = 5000; // 5km in meters
  
  // Quote Expiry
  static const Duration quoteExpiryDuration = Duration(minutes: 30);
  
  // Order Status
  static const String statusConfirmed = 'confirmed';
  static const String statusPreparing = 'preparing';
  static const String statusReady = 'ready';
  static const String statusAssigned = 'assigned';
  static const String statusPickedUp = 'picked_up';
  static const String statusInTransit = 'in_transit';
  static const String statusDelivered = 'delivered';
  static const String statusCancelled = 'cancelled';
}
