import 'package:flutter/material.dart';
import '../services/order_service.dart';
import '../models/order_model.dart';
import '../models/quote_model.dart';

class OrderProvider with ChangeNotifier {
  List<Order> _orders = [];
  Order? _currentOrder;
  List<Quote> _quotes = [];
  bool _isLoading = false;
  String? _error;

  List<Order> get orders => _orders;
  Order? get currentOrder => _currentOrder;
  List<Quote> get quotes => _quotes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<bool> createOrder({
    required String prescriptionId,
    required Map<String, dynamic> deliveryAddress,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await OrderService.createOrder(
        prescriptionId: prescriptionId,
        deliveryAddress: deliveryAddress,
      );

      if (result.success) {
        _currentOrder = result.order;
        if (result.order != null) _orders.insert(0, result.order!);
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
      _error = 'Order creation failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> confirmOrder({
    required String quoteId,
    required String paymentMethod,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await OrderService.confirmOrder(
        quoteId: quoteId,
        paymentMethod: paymentMethod,
      );

      if (result.success) {
        _currentOrder = result.order;
        if (result.order != null) {
          _orders.insert(0, result.order!);
        }
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
      _error = 'Order confirmation failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadOrderHistory() async {
    _isLoading = true;
    notifyListeners();

    try {
      _orders = await OrderService.getOrderHistory();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchOrders() async {
    await loadOrderHistory();
  }

  Future<void> trackOrder(String orderId) async {
    final cached = _orders.where((o) => o.id == orderId).firstOrNull;
    if (cached != null) {
      _currentOrder = cached;
      notifyListeners();
    }

    // Pending quotes don't have a real order endpoint — use cached only
    if (cached?.isPendingQuote == true) return;

    _isLoading = cached == null;
    if (cached == null) notifyListeners();

    try {
      final result = await OrderService.trackOrder(orderId);
      if (result.success && result.order != null) {
        _currentOrder = result.order;
      } else if (cached == null) {
        _error = result.message;
      }
    } catch (e) {
      if (cached == null) _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadQuotes(String prescriptionId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _quotes = await OrderService.getQuotes(prescriptionId);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> confirmQuote({required String quoteId, required String paymentMethod}) async {
    try {
      return await OrderService.confirmQuote(quoteId, paymentMethod);
    } catch (_) {
      return false;
    }
  }

  Future<String?> uploadPaymentProof({required String quoteId, required String imageUrl}) async {
    try {
      return await OrderService.uploadPaymentProof(quoteId, imageUrl);
    } catch (_) {
      return null;
    }
  }

  Future<bool> cancelQuote({required String quoteId}) async {
    try {
      return await OrderService.cancelQuote(quoteId);
    } catch (_) {
      return false;
    }
  }

  Future<bool> cancelOrder({required String orderId}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await OrderService.cancelOrder(orderId);
      if (res) {
        // Update local order status if it's the current one
        if (_currentOrder?.id == orderId) {
          _currentOrder = _currentOrder?.copyWith(status: 'cancelled');
        }
        // Update in history list
        final index = _orders.indexWhere((o) => o.id == orderId);
        if (index != -1) {
          _orders[index] = _orders[index].copyWith(status: 'cancelled');
        }
      }
      _isLoading = false;
      notifyListeners();
      return res;
    } catch (_) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
