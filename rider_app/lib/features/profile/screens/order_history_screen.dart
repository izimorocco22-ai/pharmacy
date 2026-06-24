import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/rider/orders');
    if (!mounted) return;
    if (res.success && res.data != null) {
      final list = List<Map<String, dynamic>>.from(
        (res.data['orders'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
      setState(() {
        _orders = list;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw.toString().substring(0, 10);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered':
        return AppTheme.success;
      case 'picked_up':
      case 'in_transit':
        return AppTheme.warning;
      case 'assigned':
        return AppTheme.info;
      case 'cancelled':
        return AppTheme.error;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'delivered':
        return 'Delivered';
      case 'picked_up':
        return 'Picked Up';
      case 'in_transit':
        return 'In Transit';
      case 'assigned':
        return 'Assigned';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'delivered':
        return Icons.check_circle;
      case 'picked_up':
      case 'in_transit':
        return Icons.delivery_dining;
      case 'assigned':
        return Icons.assignment_turned_in;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.receipt_long;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchHistory),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history,
                          size: 80,
                          color: AppTheme.textSecondary.withOpacity(0.4)),
                      const SizedBox(height: AppTheme.spacing16),
                      Text('No order history yet',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: AppTheme.spacing8),
                      Text('Completed deliveries will appear here',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchHistory,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    itemCount: _orders.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppTheme.spacing12),
                    itemBuilder: (context, index) {
                      final o = _orders[index];
                      final status = o['status']?.toString() ?? '';
                      final fee =
                          (o['deliveryFee'] as num?)?.toDouble() ?? 0.0;
                      final color = _statusColor(status);

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusLarge),
                          side: const BorderSide(color: AppTheme.divider),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacing16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    o['orderNumber']?.toString() ?? '',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(
                                          AppTheme.radiusSmall),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(_statusIcon(status),
                                            size: 12, color: color),
                                        const SizedBox(width: 4),
                                        Text(
                                          _statusLabel(status),
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: color),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spacing12),

                              // Pickup
                              _addressRow(
                                context,
                                Icons.store,
                                AppTheme.primary,
                                'Pickup',
                                o['pickupAddress']?.toString() ?? '',
                              ),
                              const SizedBox(height: AppTheme.spacing8),

                              // Delivery
                              _addressRow(
                                context,
                                Icons.location_on,
                                AppTheme.error,
                                'Delivery',
                                o['deliveryAddress']?.toString() ?? '',
                              ),

                              const Divider(height: AppTheme.spacing24),

                              // Footer
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time,
                                          size: 14,
                                          color: AppTheme.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatDate(o['deliveredAt'] ??
                                            o['createdAt']),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                  Text(
                                    status == 'delivered'
                                        ? '+${fee.toStringAsFixed(2)} MRO'
                                        : '—',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: status == 'delivered'
                                          ? AppTheme.success
                                          : AppTheme.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _addressRow(BuildContext context, IconData icon, Color color,
      String label, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppTheme.spacing8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.textSecondary)),
              Text(address,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}
