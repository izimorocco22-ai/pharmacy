import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import '../../services/api_service.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _isLoading = true;
  List<dynamic> _orders = [];
  String? _error;


  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final response = await ApiService.get('/pharmacy/orders');
      if (response.success) {
        setState(() {
          _orders = (response.data['orders'] as List?) ?? [];
          _isLoading = false;
        });
      } else {
        setState(() { _error = response.message; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('order_history'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: AppTheme.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadOrders, child: Text(l10n.translate('retry'))),
                    ],
                  ),
                )
              : _orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 80,
                              color: AppTheme.textSecondary.withOpacity(0.4)),
                          const SizedBox(height: 16),
                          Text(l10n.translate('no_orders_yet'),
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text(l10n.translate('confirmed_orders_desc'),
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadOrders,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppTheme.spacing16),
                        itemCount: _orders.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppTheme.spacing12),
                        itemBuilder: (context, i) =>
                            _buildOrderCard(context, _orders[i]),
                      ),
                    ),
    );
  }

  Widget _buildOrderCard(BuildContext context, dynamic order) {
    final l10n = AppLocalizations.of(context)!;
    final status = order['status'] ?? 'confirmed';
    final color = _statusColor(status);
    final orderId = order['id']?.toString() ?? order['_id']?.toString() ?? '$status$status';
    final items = (order['items'] as List?) ?? [];
    // Show only the pharmacy's quote subtotal (medicines only, no tax/delivery)
    final subtotal = (order['subtotal'] ?? 0).toDouble();

    return Card(
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          '/order-detail',
          arguments: order,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
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
                    '#${order['orderNumber'] ?? orderId.substring(0, 8)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      l10n.translate(status.toString().toLowerCase()).toUpperCase(),
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600, color: color),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing8),
              // Items count + subtotal + expand arrow
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${items.length} ${l10n.translate(items.length == 1 ? 'item' : 'items')}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Row(
                    children: [
                      Text(
                        '${subtotal.toStringAsFixed(2)} ${l10n.translate('mad')}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: AppTheme.primary),
                      ),
                      const SizedBox(width: AppTheme.spacing8),
                      const Icon(Icons.chevron_right,
                          size: 20, color: AppTheme.textSecondary),
                    ],
                  ),
                ],
              ),

            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered': return AppTheme.success;
      case 'cancelled': return AppTheme.error;
      case 'in_transit':
      case 'picked_up': return AppTheme.info;
      default: return AppTheme.warning;
    }
  }
}
