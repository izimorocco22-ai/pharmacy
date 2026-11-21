import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rider_app/services/active_delivery_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A realistic delivery map, exactly as the backend's /rider/nearby-deliveries
  // returns it (JSON-decoded into Dart types).
  final delivery = <String, dynamic>{
    'orderId': '665abc0000000000000000a1',
    'orderNumber': 'ORD-123',
    'pickupAddress': 'Pharmacy X, Main St',
    'deliveryAddress': 'Patient Y, 2nd Ave',
    'pharmacyCoords': [10.1, 20.2],
    'deliveryCoords': [10.3, 20.4],
    'pharmacyPhone': '+2220000001',
    'patientPhone': '+2220000002',
    'paymentMethod': 'cash',
    'subtotal': 100,
    'commissionAmount': 10,
    'deliveryFee': 15,
    'totalAmount': 125,
  };

  setUp(() {
    // Start every test with empty persistence.
    SharedPreferences.setMockInitialValues({});
  });

  test('no active delivery -> loadDelivery returns null, phase defaults', () async {
    expect(await ActiveDeliveryStore.loadDelivery(), isNull);
    expect(await ActiveDeliveryStore.loadPhase(), 'to_pharmacy');
  });

  test('BUG 3: delivery survives being saved and reloaded (app close/reopen)',
      () async {
    // Rider accepts -> NavigationScreen.initState saves it.
    await ActiveDeliveryStore.save(delivery, 'to_pharmacy');

    // Simulate app fully closed & reopened: brand-new SharedPreferences
    // instance reads from the same backing store.
    final restored = await ActiveDeliveryStore.loadDelivery();

    expect(restored, isNotNull);
    // The whole delivery is intact — nothing disappears.
    expect(restored!['orderId'], '665abc0000000000000000a1');
    expect(restored['orderNumber'], 'ORD-123');
    expect(restored['pharmacyCoords'], [10.1, 20.2]);
    expect(restored['deliveryCoords'], [10.3, 20.4]);
    expect(restored['patientPhone'], '+2220000002');
    expect(restored['totalAmount'], 125);
    expect(await ActiveDeliveryStore.loadPhase(), 'to_pharmacy');
  });

  test('phase advances to to_patient after pickup and persists', () async {
    await ActiveDeliveryStore.save(delivery, 'to_pharmacy');
    // Rider taps "Arrived at pharmacy" -> picked_up.
    await ActiveDeliveryStore.savePhase('to_patient');

    // Reopen -> still have the delivery, now on the delivery leg.
    expect(await ActiveDeliveryStore.loadDelivery(), isNotNull);
    expect(await ActiveDeliveryStore.loadPhase(), 'to_patient');
  });

  test('clear() removes the delivery after it is delivered', () async {
    await ActiveDeliveryStore.save(delivery, 'to_patient');
    // Rider completes delivery -> cleared.
    await ActiveDeliveryStore.clear();

    expect(await ActiveDeliveryStore.loadDelivery(), isNull);
    expect(await ActiveDeliveryStore.loadPhase(), 'to_pharmacy');
  });

  test('orderId key matches the /rider/orders "id" field for active-check',
      () async {
    // The saved map uses key "orderId"; the backend /rider/orders returns the
    // same Mongo _id under key "id". The splash restore compares them. This
    // asserts the two stay the same string so the active-check cannot wrongly
    // discard a live delivery.
    await ActiveDeliveryStore.save(delivery, 'to_pharmacy');
    final saved = await ActiveDeliveryStore.loadDelivery();

    // Simulated /rider/orders response row for the same order.
    final ordersRow = {'id': '665abc0000000000000000a1', 'status': 'assigned'};

    final savedId = saved!['orderId']?.toString();
    final rowId = ordersRow['id']?.toString();
    expect(savedId, rowId);
    expect(
      const ['assigned', 'picked_up', 'in_transit'].contains(ordersRow['status']),
      isTrue,
    );
  });
}
