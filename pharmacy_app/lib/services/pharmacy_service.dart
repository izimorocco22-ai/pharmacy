import 'api_service.dart';

class PharmacyService {
  static Future<ApiResponse> getPaymentSettings() async {
    return await ApiService.get('/pharmacy/payment-settings');
  }

  static Future<ApiResponse> updatePaymentSettings(List<Map<String, String>> settings) async {
    return await ApiService.put('/pharmacy/payment-settings', {
      'paymentSettings': settings,
    });
  }
}
