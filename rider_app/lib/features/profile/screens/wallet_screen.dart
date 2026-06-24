import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _loading = true;
  double _totalEarnings = 0;
  int _totalDeliveries = 0;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/rider/orders');
    if (!mounted) return;
    if (res.success && res.data != null) {
      final list = List<Map<String, dynamic>>.from(
        (res.data['orders'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
      setState(() {
        _totalEarnings = (res.data['totalEarnings'] as num?)?.toDouble() ?? 0;
        _totalDeliveries = (res.data['totalDeliveries'] as num?)?.toInt() ?? 0;
        _orders = list.where((o) => o['status'] == 'delivered').toList();
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
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return raw.toString().substring(0, 10);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: Column(
                children: [
                  // Earnings card
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(AppTheme.spacing16),
                    padding: const EdgeInsets.all(AppTheme.spacing24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Earnings',
                            style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: AppTheme.spacing8),
                        Text(
                          '${_totalEarnings.toStringAsFixed(2)} MRO',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppTheme.spacing12),
                        Row(
                          children: [
                            const Icon(Icons.delivery_dining,
                                color: Colors.white70, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '$_totalDeliveries deliveries completed',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Transactions header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Delivery Earnings',
                            style: Theme.of(context).textTheme.titleMedium),
                        Text('${_orders.length} orders',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing8),

                  // Transactions list
                  Expanded(
                    child: _orders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.account_balance_wallet_outlined,
                                    size: 64,
                                    color: AppTheme.textSecondary
                                        .withOpacity(0.4)),
                                const SizedBox(height: AppTheme.spacing12),
                                Text('No earnings yet',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: AppTheme.spacing4),
                                Text('Complete deliveries to earn',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacing16),
                            itemCount: _orders.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final o = _orders[index];
                              final fee =
                                  (o['deliveryFee'] as num?)?.toDouble() ??
                                      0.0;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor:
                                      AppTheme.success.withOpacity(0.1),
                                  child: const Icon(Icons.check_circle,
                                      color: AppTheme.success, size: 20),
                                ),
                                title: Text(
                                  o['orderNumber']?.toString() ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14),
                                ),
                                subtitle: Text(
                                  _formatDate(o['deliveredAt'] ?? o['createdAt']),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                trailing: Text(
                                  '+${fee.toStringAsFixed(2)} MRO',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.success,
                                    fontSize: 14,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
