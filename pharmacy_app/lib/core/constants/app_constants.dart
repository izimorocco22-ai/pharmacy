import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'https://pharmacy-zeta-seven.vercel.app/api';

  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';

  static const Duration connectionTimeout = Duration(seconds: 30);
}
