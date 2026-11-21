import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_app/services/push_notification_service.dart';

// Verifies where a pharmacy notification tap deep-links, for every notification
// type the backend actually sends to a pharmacy.
void main() {
  String decide(Map<String, dynamic> d) =>
      PushNotificationService.deepLinkDecision(d);

  group('pharmacy deep-link decision', () {
    test('order notifications -> order-detail (uses orderId)', () {
      for (final type in [
        'order_confirmed',
        'rider_coming',
        'order_cancelled',
        'payment_proof_received',
      ]) {
        expect(decide({'orderId': 'ORD1', 'type': type}), 'order-detail',
            reason: type);
      }
    });

    test('prescription request (no orderId) -> notifications fallback', () {
      expect(decide({'prescriptionId': 'P1', 'type': 'prescription_request'}),
          'notifications');
      expect(decide({'quoteId': 'Q1', 'type': 'quote_cancelled'}),
          'notifications');
    });

    test('empty / blank orderId -> notifications fallback', () {
      expect(decide({}), 'notifications');
      expect(decide({'orderId': ''}), 'notifications');
    });
  });
}
