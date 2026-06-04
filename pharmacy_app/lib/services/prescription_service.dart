import 'api_service.dart';

class PrescriptionService {
  static Future<ApiResponse> getPrescriptionRequests() async {
    return await ApiService.get('/pharmacy/requests');
  }

  static Future<ApiResponse> sendQuote({
    required String prescriptionId,
    required List<Map<String, dynamic>> items,
    required double deliveryFee,
    Map<String, String>? paymentMethod,
  }) async {
    final subtotal = items.fold<double>(
      0,
      (sum, item) => sum + (item['totalPrice'] as num).toDouble(),
    );

    return await ApiService.post('/pharmacy/send-quote', {
      'prescriptionId': prescriptionId,
      'items': items,
      'deliveryFee': deliveryFee,
      'subtotal': subtotal,
      'totalAmount': subtotal + deliveryFee,
      'paymentMethod': paymentMethod,
    });
  }
}
