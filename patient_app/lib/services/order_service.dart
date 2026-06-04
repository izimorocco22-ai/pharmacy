import '../models/order_model.dart';
import '../models/quote_model.dart';
import 'api_service.dart';

class OrderService {
  static Future<OrderResult> createOrder({
    required String prescriptionId,
    required Map<String, dynamic> deliveryAddress,
  }) async {
    try {
      final response = await ApiService.post('/orders/create', {
        'prescriptionId': prescriptionId,
        'deliveryAddress': deliveryAddress,
      });

      if (response.success) {
        final data = response.data;
        final orderJson = data['order'] ?? data;
        final order = Order.fromJson(orderJson);
        return OrderResult(success: true, order: order);
      } else {
        return OrderResult(success: false, message: response.message);
      }
    } catch (e) {
      return OrderResult(success: false, message: 'Failed to create order');
    }
  }

  static Future<OrderResult> confirmOrder({
    required String quoteId,
    required String paymentMethod,
  }) async {
    try {
      final response = await ApiService.post('/orders/confirm', {
        'quoteId': quoteId,
        'paymentMethod': paymentMethod,
      });

      if (response.success) {
        final order = Order.fromJson(response.data['order']);
        return OrderResult(success: true, order: order);
      } else {
        return OrderResult(success: false, message: response.message);
      }
    } catch (e) {
      return OrderResult(
        success: false,
        message: 'Failed to confirm order',
      );
    }
  }

  static Future<List<Order>> getOrderHistory() async {
    try {
      final response = await ApiService.get('/orders/history');

      if (response.success) {
        final data = response.data;
        if (data is List) {
          return data.map((json) => Order.fromJson(json)).toList();
        }
      }
    } catch (e) {
      print('Error fetching order history: $e');
      return [];
    }
    return [];
  }

  static Future<OrderResult> trackOrder(String orderId) async {
    try {
      final response = await ApiService.get('/orders/$orderId');

      if (response.success) {
        final data = response.data;
        final orderJson = data['order'] ?? data;
        final order = Order.fromJson(orderJson);
        return OrderResult(success: true, order: order);
      } else {
        return OrderResult(success: false, message: response.message);
      }
    } catch (e) {
      return OrderResult(
        success: false,
        message: 'Failed to fetch order',
      );
    }
  }

  static Future<List<Quote>> getQuotes(String prescriptionId) async {
    try {
      final response = await ApiService.get('/prescriptions/$prescriptionId/quotes');

      if (response.success) {
        final List<dynamic> data = response.data['quotes'];
        return data.map((json) => Quote.fromJson(json)).toList();
      }
    } catch (e) {
      return [];
    }
    return [];
  }

  static Future<bool> cancelOrder(String orderId) async {
    try {
      final response = await ApiService.post('/orders/$orderId/cancel', {});
      return response.success;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> confirmQuote(String quoteId, String paymentMethod) async {
    try {
      final response = await ApiService.post(
        '/patient/quotes/$quoteId/confirm',
        {'paymentMethod': paymentMethod},
      );
      return response.success;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> uploadPaymentProof(String quoteId, String imageUrl) async {
    try {
      final response = await ApiService.post(
        '/patient/quotes/$quoteId/upload-proof',
        {'paymentProofUrl': imageUrl},
      );
      if (response.success) return imageUrl;
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> cancelQuote(String quoteId) async {
    try {
      final response = await ApiService.post('/patient/quotes/$quoteId/cancel', {});
      return response.success;
    } catch (_) {
      return false;
    }
  }
}

class OrderResult {
  final bool success;
  final String? message;
  final Order? order;

  OrderResult({
    required this.success,
    this.message,
    this.order,
  });
}
