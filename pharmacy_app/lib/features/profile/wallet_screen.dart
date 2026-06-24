import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/api_service.dart';

class PharmacyWalletScreen extends StatefulWidget {
  const PharmacyWalletScreen({super.key});

  @override
  State<PharmacyWalletScreen> createState() => _PharmacyWalletScreenState();
}

class _PharmacyWalletScreenState extends State<PharmacyWalletScreen> {
  bool _loading = true;
  double _totalRevenue = 0;
  double _todayRevenue = 0;
  int _totalOrders = 0;
  int _todayOrders = 0;
  List<Map<String, dynamic>> _deliveredOrders = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/pharmacy/orders');
    if (!mounted) return;
    if (res.success && res.data != null) {
      final orders = List<Map<String, dynamic>>.from(
        (res.data['orders'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
      );

      final delivered = orders.where((o) => o['status'] == 'delivered').toList();
      final today = DateTime.now();

      double total = 0;
      double todayRev = 0;
      int todayCount = 0;

      for (final o in delivered) {
        final amount = (o['subtotal'] as num?)?.toDouble() ?? 0;
        total += amount;
        try {
          final dt = DateTime.parse((o['createdAt'] ?? '').toString()).toLocal();
          if (dt.year == today.year && dt.month == today.month && dt.day == today.day) {
            todayRev += amount;
            todayCount++;
          }
        } catch (_) {}
      }

      setState(() {
        _deliveredOrders = delivered;
        _totalRevenue = total;
        _todayRevenue = todayRev;
        _totalOrders = delivered.length;
        _todayOrders = todayCount;
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
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: Column(
                children: [
                  // Revenue card
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
                        const Text('Total Revenue', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: AppTheme.spacing8),
                        Text(
                          '${_totalRevenue.toStringAsFixed(2)} MRO',
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppTheme.spacing16),
                        Row(
                          children: [
                            Expanded(child: _miniStat('Today', '${_todayRevenue.toStringAsFixed(0)} MRO', Icons.today)),
                            Container(width: 1, height: 32, color: Colors.white30),
                            Expanded(child: _miniStat('Total Orders', '$_totalOrders', Icons.check_circle_outline)),
                            Container(width: 1, height: 32, color: Colors.white30),
                            Expanded(child: _miniStat('Today Orders', '$_todayOrders', Icons.delivery_dining)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // List header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Completed Orders', style: Theme.of(context).textTheme.titleMedium),
                        Text('${_deliveredOrders.length} orders',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing8),

                  Expanded(
                    child: _deliveredOrders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.account_balance_wallet_outlined,
                                    size: 64, color: AppTheme.textSecondary.withOpacity(0.4)),
                                const SizedBox(height: AppTheme.spacing12),
                                const Text('No completed orders yet',
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: AppTheme.spacing4),
                                Text('Revenue from delivered orders will appear here',
                                    style: Theme.of(context).textTheme.bodySmall,
                                    textAlign: TextAlign.center),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
                            itemCount: _deliveredOrders.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final o = _deliveredOrders[index];
                              final amount = (o['subtotal'] as num?)?.toDouble() ?? 0;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.success.withOpacity(0.1),
                                  child: const Icon(Icons.check_circle, color: AppTheme.success, size: 20),
                                ),
                                title: Text(
                                  o['orderNumber']?.toString() ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                subtitle: Text(
                                  _formatDate(o['createdAt']),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                trailing: Text(
                                  '+${amount.toStringAsFixed(2)} MRO',
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

  Widget _miniStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }
}
