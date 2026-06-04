import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../services/api_service.dart';
import '../../deliveries/screens/navigation_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  Timer? _pollTimer;
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    // Poll every 10 seconds for real-time updates
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchOrders());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    final res = await ApiService.get('/rider/nearby-deliveries');
    if (!mounted) return;
    if (res.success && res.data != null) {
      final list = List<Map<String, dynamic>>.from(
        (res.data['deliveries'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
      setState(() {
        _orders = list;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _acceptOrder(String orderId) async {
    setState(() => _processingIds.add(orderId));
    final res = await ApiService.post('/rider/accept-delivery', {'orderId': orderId});
    if (!mounted) return;
    setState(() => _processingIds.remove(orderId));
    if (res.success) {
      // Find the order data to pass to navigation
      final order = _orders.firstWhere((o) => o['orderId'].toString() == orderId);
      setState(() => _orders.removeWhere((o) => o['orderId'].toString() == orderId));
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NavigationScreen(delivery: order),
          ),
        );
      }
    } else {
      await _fetchOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    setState(() => _processingIds.add(orderId));
    await ApiService.post('/rider/cancel-delivery', {'orderId': orderId});
    if (!mounted) return;
    setState(() {
      _processingIds.remove(orderId);
      _orders.removeWhere((o) => o['orderId'].toString() == orderId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('available_orders')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _fetchOrders();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delivery_dining, size: 80, color: AppTheme.textSecondary.withOpacity(0.4)),
                      const SizedBox(height: AppTheme.spacing16),
                      Text(l10n.translate('no_orders_nearby'), style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: AppTheme.spacing8),
                      Text(l10n.translate('pull_to_refresh_desc'), style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchOrders,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    itemCount: _orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spacing12),
                    itemBuilder: (context, index) => _OrderCard(
                      order: _orders[index],
                      isProcessing: _processingIds.contains(_orders[index]['orderId'].toString()),
                      onAccept: () => _acceptOrder(_orders[index]['orderId'].toString()),
                      onCancel: () => _cancelOrder(_orders[index]['orderId'].toString()),
                    ),
                  ),
                ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isProcessing;
  final VoidCallback onAccept;
  final VoidCallback onCancel;

  const _OrderCard({
    required this.order,
    required this.isProcessing,
    required this.onAccept,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final deliveryFee = (order['deliveryFee'] ?? 0).toDouble();
    final distance = order['distance'];
    final pickupAddress = order['pickupAddress'] ?? 'Pharmacy';
    final deliveryAddress = order['deliveryAddress'] ?? 'Patient';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        side: const BorderSide(color: AppTheme.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order['orderNumber'] ?? '',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Text(
                    '${deliveryFee.toStringAsFixed(0)} ${l10n.translate('mad')}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.success,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing16),

            // Route: Pharmacy → Patient
            Row(
              children: [
                // Left icons column
                Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.store, size: 16, color: AppTheme.primary),
                    ),
                    Container(
                      width: 2,
                      height: 28,
                      color: AppTheme.divider,
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.location_on, size: 16, color: AppTheme.error),
                    ),
                  ],
                ),
                const SizedBox(width: AppTheme.spacing12),
                // Right address column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pickup', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
                          Text(pickupAddress, style: Theme.of(context).textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacing16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Delivery', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
                          Text(deliveryAddress, style: Theme.of(context).textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacing12),
            const Divider(),
            const SizedBox(height: AppTheme.spacing8),

            // Distance + total row
            Row(
              children: [
                if (distance != null) ...[
                  const Icon(Icons.directions_bike, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text('${distance} km', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: AppTheme.spacing16),
                ],

              ],
            ),

            const SizedBox(height: AppTheme.spacing16),

            // Accept / Cancel buttons
            isProcessing
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onCancel,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.error,
                            side: const BorderSide(color: AppTheme.error),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
                          ),
                          child: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacing12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: onAccept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
                          ),
                          child: const Text('Accept Order'),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
