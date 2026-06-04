import 'package:flutter/material.dart';
import '../services/prescription_service.dart';
import '../services/api_service.dart';

class PrescriptionProvider with ChangeNotifier {
  List<dynamic> _prescriptions = [];
  bool _isLoading = false;
  String? _error;
  int _confirmedCount = 0;
  int _completedCount = 0;

  List<dynamic> get prescriptions => _prescriptions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get confirmedCount => _confirmedCount;
  int get completedCount => _completedCount;

  Future<void> fetchPrescriptionRequests({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final result = await PrescriptionService.getPrescriptionRequests();

      if (result.success) {
        final data = result.data;
        if (data != null && data['prescriptions'] is List) {
          final all = List<dynamic>.from(data['prescriptions']);
          // Only show pending/quoted in the requests list — accepted means patient confirmed
          _prescriptions = all.where((p) => p['status'] != 'accepted').toList();
        } else {
          _prescriptions = [];
        }
      } else if (!silent) {
        _error = result.message;
      }

      // Fetch order counts
      final ordersResponse = await ApiService.get('/pharmacy/orders');
      if (ordersResponse.success) {
        final orders = (ordersResponse.data['orders'] as List?) ?? [];
        _confirmedCount = orders.where((o) => !['delivered', 'cancelled', 'pending'].contains(o['status'])).length;
        _completedCount = orders.where((o) => o['status'] == 'delivered').length;
      }
    } catch (e) {
      if (!silent) _error = 'Connection error. Pull down to retry.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> sendQuote({
    required String prescriptionId,
    required List<Map<String, dynamic>> items,
    required double deliveryFee,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await PrescriptionService.sendQuote(
        prescriptionId: prescriptionId,
        items: items,
        deliveryFee: deliveryFee,
      );

      _isLoading = false;
      notifyListeners();

      if (result.success) {
        await fetchPrescriptionRequests();
        return true;
      } else {
        _error = result.message;
        return false;
      }
    } catch (e) {
      _error = 'Failed to send quote: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
