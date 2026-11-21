import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/services/push_notification_service.dart';

// Verifies where a patient notification tap deep-links, for every notification
// type the backend actually sends to a patient.
void main() {
  String decide(Map<String, dynamic> d) =>
      PushNotificationService.deepLinkDecision(d);

  group('patient deep-link decision', () {
    test('order updates -> order-tracking (uses orderId)', () {
      for (final type in [
        'order_confirmed',
        'rider_assigned',
        'order_picked_up',
        'order_in_transit',
        'order_delivered',
        'payment_confirmed',
      ]) {
        expect(decide({'orderId': 'ORD1', 'type': type}), 'order-tracking',
            reason: type);
      }
    });

    test('quote notifications -> my-quotes (uses quoteId)', () {
      expect(decide({'quoteId': 'Q1', 'type': 'quote_received'}), 'my-quotes');
      expect(decide({'quoteId': 'Q1', 'type': 'quote_expired'}), 'my-quotes');
    });

    test('prescription notifications (no ids) -> my-quotes', () {
      expect(decide({'type': 'prescription_submitted'}), 'my-quotes');
      expect(decide({'type': 'prescription_reassigned'}), 'my-quotes');
    });

    test('orderId wins even if a type string is present', () {
      expect(decide({'orderId': 'ORD1', 'quoteId': 'Q1'}), 'order-tracking');
    });

    test('empty / unknown payload -> notifications fallback', () {
      expect(decide({}), 'notifications');
      expect(decide({'type': 'something_else'}), 'notifications');
      expect(decide({'orderId': ''}), 'notifications');
    });
  });
}
