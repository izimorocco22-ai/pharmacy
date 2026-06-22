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
      appBar: AppBar(
        title: Text(l10n.translate('order_history')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.translate('refresh'),
            onPressed: _isLoading ? null : _loadOrders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadOrders,
              child: _error != null
                  ? _buildScrollableCenter(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_error!, style: const TextStyle(color: AppTheme.error)),
                          const SizedBox(height: 16),
                          ElevatedButton(onPressed: _loadOrders, child: Text(l10n.translate('retry'))),
                        ],
                      ),
                    )
                  : _orders.isEmpty
                      ? _buildScrollableCenter(
                          Column(
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
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
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

  /// Wraps a centered child in a scroll view that can always be over-scrolled,
  /// so pull-to-refresh works even when the content is empty or short.
  Widget _buildScrollableCenter(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
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
    final subtotal = (order['subtotal'] ?? 0).toDouble();
    final statusLabel = _statusLabel(status);

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '#${order['orderNumber'] ?? orderId.substring(0, 8)}',
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600, color: color),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing8),
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

  String _statusLabel(String status) {
    switch (status) {
      case 'payment_verification': return 'VERIFYING';
      case 'confirmed': return 'CONFIRMED';
      case 'preparing': return 'PREPARING';
      case 'ready': return 'READY';
      case 'assigned': return 'ASSIGNED';
      case 'picked_up': return 'PICKED UP';
      case 'in_transit': return 'IN TRANSIT';
      case 'delivered': return 'DELIVERED';
      case 'cancelled': return 'CANCELLED';
      default: return status.toUpperCase();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered': return AppTheme.success;
      case 'cancelled': return AppTheme.error;
      case 'payment_verification': return Colors.blueGrey;
      case 'in_transit':
      case 'picked_up': return AppTheme.info;
      default: return AppTheme.warning;
    }
  }
}
