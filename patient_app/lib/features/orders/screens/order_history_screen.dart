import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../providers/order_provider.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    await context.read<OrderProvider>().fetchOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
      ),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, _) {
          if (orderProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (orderProvider.orders.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: _loadOrders,
            child: ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              itemCount: orderProvider.orders.length,
              itemBuilder: (context, index) {
                final order = orderProvider.orders[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
                  child: _buildOrderCard(order),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 80,
            color: AppTheme.textHint,
          ),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            'No orders yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            'Your order history will appear here',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(dynamic order) {
    return AppCard(
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          '/order-tracking',
          arguments: order.id,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderNumber?.isNotEmpty == true ? order.orderNumber! : 'Pending Quote',
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(order.status),
                ],
              ),
              const SizedBox(height: AppTheme.spacing8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: AppTheme.spacing4),
                  Text(
                    _formatDate(order.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const Divider(height: AppTheme.spacing24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Amount',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    '${order.totalAmount.toStringAsFixed(2)} MAD',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.primary,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Text(
        _getStatusText(status),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _getStatusColor(status),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'delivered':
        return Colors.green;
      case 'in_transit':
      case 'picked_up':
        return AppTheme.info;
      case 'cancelled':
      case 'expired':
        return Colors.red;
      case 'searching':
      case 'quote_pending':
        return Colors.orange;
      default:
        return AppTheme.primary;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'delivered':
        return 'Delivered';
      case 'in_transit':
        return 'On the way';
      case 'picked_up':
        return 'Picked up';
      case 'confirmed':
        return 'Confirmed';
      case 'cancelled':
        return 'Cancelled';
      case 'searching':
        return 'Finding pharmacy';
      case 'quote_pending':
        return 'Quote received';
      case 'expired':
        return 'Cancelled (No Pharmacy)';
      default:
        return status;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }
}
