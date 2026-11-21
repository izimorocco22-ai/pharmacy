import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/services/push_notification_service.dart';

// Verifies where a rider notification tap deep-links, for every notification
// type the backend actually sends to a rider.
void main() {
  String decide(Map<String, dynamic> d) =>
      PushNotificationService.deepLinkDecision(d);

  group('rider deep-link decision', () {
    test('new delivery available (with orderId) -> order (active or home)', () {
      expect(decide({'orderId': 'ORD1', 'type': 'delivery_available'}), 'order');
      expect(decide({'orderId': 'ORD1', 'type': 'order_cancelled'}), 'order');
    });

    test('delivery_available without orderId (location fan-out) -> home', () {
      expect(decide({'type': 'delivery_available'}), 'home');
    });

    test('earnings credit/deduct -> wallet', () {
      expect(decide({'type': 'earnings_credit', 'amount': '50'}), 'wallet');
      expect(decide({'type': 'earnings_deduct', 'amount': '20'}), 'wallet');
    });

    test('empty / unknown payload -> notifications fallback', () {
      expect(decide({}), 'notifications');
      expect(decide({'type': 'something_else'}), 'notifications');
      expect(decide({'orderId': ''}), 'notifications');
    });
  });
}
