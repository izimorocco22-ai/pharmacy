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
  // Delivered orders and admin adjustments, newest first. Each entry has
  // title, subtitle (note), date and a signed amount.
  List<Map<String, dynamic>> _history = [];

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
      final orders = (res.data['orders'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .where((o) => o['status'] == 'delivered')
          .map((o) => <String, dynamic>{
                'title': o['orderNumber']?.toString() ?? '',
                'subtitle': null,
                'date': o['deliveredAt'] ?? o['createdAt'],
                'amount': (o['deliveryFee'] as num?)?.toDouble() ?? 0.0,
              });
      final adjustments = (res.data['adjustments'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .map((a) {
        final amount = (a['amount'] as num?)?.toDouble() ?? 0.0;
        final isDeduct = a['type'] == 'deduct';
        final note = a['note']?.toString() ?? '';
        return <String, dynamic>{
          'title': isDeduct ? 'Deducted by admin' : 'Added by admin',
          'subtitle': note.isEmpty ? null : note,
          'date': a['createdAt'],
          'amount': isDeduct ? -amount : amount,
        };
      });
      final history = [...orders, ...adjustments]
        ..sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));
      setState(() {
        _totalEarnings = (res.data['totalEarnings'] as num?)?.toDouble() ?? 0;
        _totalDeliveries = (res.data['totalDeliveries'] as num?)?.toInt() ?? 0;
        _history = history;
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
                        Text('Earnings History',
                            style: Theme.of(context).textTheme.titleMedium),
                        Text('${_history.length} entries',
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
                    child: _history.isEmpty
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
                            itemCount: _history.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final h = _history[index];
                              final amount = h['amount'] as double;
                              final isCredit = amount >= 0;
                              final color =
                                  isCredit ? AppTheme.success : AppTheme.error;
                              final note = h['subtitle'] as String?;
                              final sign = isCredit ? '+' : '-';
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: color.withOpacity(0.1),
                                  child: Icon(
                                      isCredit
                                          ? Icons.check_circle
                                          : Icons.remove_circle,
                                      color: color,
                                      size: 20),
                                ),
                                title: Text(
                                  h['title'] as String,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14),
                                ),
                                subtitle: Text(
                                  note == null
                                      ? _formatDate(h['date'])
                                      : '$note · ${_formatDate(h['date'])}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                trailing: Text(
                                  '$sign${amount.abs().toStringAsFixed(2)} MRO',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: color,
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
