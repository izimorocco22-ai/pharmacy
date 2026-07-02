import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';
import '../../../services/location_service.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../../services/push_notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isOnline = false;
  bool _togglingOnline = false;
  bool _loading = true;

  double _walletBalance = 0;
  double _todayEarnings = 0;
  int _todayDeliveries = 0;

  List<Map<String, dynamic>> _availableOrders = [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    PushNotificationService.registerToken();
    _fetchData();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    // Check rider's current online status from backend
    final profileRes = await ApiService.get('/rider/profile');
    if (!mounted) return;
    if (profileRes.success && profileRes.data != null) {
      final rider = profileRes.data['rider'];
      final backendOnline = rider?['isOnline'] == true;
      if (backendOnline != _isOnline) {
        setState(() => _isOnline = backendOnline);
        if (backendOnline) {
          _pollTimer?.cancel();
          _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchAvailableOrders());
        }
      }
    }
    final res = await ApiService.get('/rider/orders');
    if (!mounted) return;
    if (res.success && res.data != null) {
      final today = DateTime.now();
      double todayEarn = 0;
      int todayCount = 0;
      final orders = List<Map<String, dynamic>>.from(
        (res.data['orders'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
      for (final o in orders) {
        if (o['status'] == 'delivered') {
          try {
            final dt = DateTime.parse((o['deliveredAt'] ?? o['createdAt']).toString()).toLocal();
            if (dt.year == today.year && dt.month == today.month && dt.day == today.day) {
              todayEarn += (o['deliveryFee'] as num?)?.toDouble() ?? 0;
              todayCount++;
            }
          } catch (_) {}
        }
      }
      setState(() {
        _walletBalance = (res.data['totalEarnings'] as num?)?.toDouble() ?? 0;
        _todayEarnings = todayEarn;
        _todayDeliveries = todayCount;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
    if (_isOnline) _fetchAvailableOrders();
  }

  Future<void> _fetchAvailableOrders() async {
    final res = await ApiService.get('/rider/nearby-deliveries');
    if (!mounted) return;
    if (res.success && res.data != null) {
      setState(() {
        _availableOrders = List<Map<String, dynamic>>.from(
          (res.data['deliveries'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
        );
      });
    }
  }

  Future<void> _toggleOnline(bool value) async {
    setState(() => _togglingOnline = true);
    if (value) {
      final granted = await LocationService.requestPermission();
      if (!granted) {
        setState(() => _togglingOnline = false);
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('location_required'))),
          );
        }
        return;
      }
      await LocationService.updateLocation(isOnline: true);
      setState(() => _isOnline = true);
      LocationService.startTracking();
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchAvailableOrders());
      await _fetchAvailableOrders();
    } else {
      await LocationService.markOffline();
      setState(() {
        _isOnline = false;
        _availableOrders = [];
      });
      _pollTimer?.cancel();
    }
    setState(() => _togglingOnline = false);
  }

  Future<void> _acceptOrder(Map<String, dynamic> order) async {
    final res = await ApiService.post('/rider/accept-delivery', {'orderId': order['orderId'].toString()});
    if (!mounted) return;
    if (res.success) {
      setState(() => _availableOrders.removeWhere((o) => o['orderId'].toString() == order['orderId'].toString()));
      Navigator.pushNamed(context, '/navigation', arguments: order);
    } else {
      await _fetchAvailableOrders();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppTheme.error),
      );
    }
  }

  void _skipOrder(Map<String, dynamic> order) {
    setState(() => _availableOrders.removeWhere((o) => o['orderId'].toString() == order['orderId'].toString()));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _fetchData,
        child: CustomScrollView(
          slivers: [
            // Green header
            SliverToBoxAdapter(
              child: Container(
                color: AppTheme.primary,
                padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${l10n.translate('welcome_back')} ${user?.fullName?.split(' ').first ?? l10n.translate('rider')}!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.translate('ready_to_earn'),
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const NotificationBell(),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () async {
                                await context.read<AuthProvider>().logout();
                                if (mounted) Navigator.pushReplacementNamed(context, '/login');
                              },
                              child: const Icon(Icons.logout, color: Colors.white, size: 24),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Availability toggle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.power_settings_new,
                              color: _isOnline ? Colors.white : Colors.white70,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.translate('availability'),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                                Text(
                                  _isOnline ? l10n.translate('online') : l10n.translate('offline'),
                                  style: TextStyle(
                                    color: _isOnline ? Colors.white : Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _togglingOnline
                              ? const SizedBox(
                                  width: 36, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Switch(
                                  value: _isOnline,
                                  onChanged: _toggleOnline,
                                  activeColor: Colors.white,
                                  activeTrackColor: AppTheme.primaryDark,
                                  inactiveThumbColor: Colors.white,
                                  inactiveTrackColor: Colors.white30,
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Wallet balance card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(l10n.translate('wallet'),
                                style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            const Icon(Icons.account_balance_wallet_outlined,
                                color: Colors.white70, size: 20),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_walletBalance.toStringAsFixed(0)} ${l10n.translate('mad')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stats row
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          icon: Icons.trending_up,
                          label: l10n.translate('earnings'),
                          value: '${_todayEarnings.toStringAsFixed(0)} ${l10n.translate('mad')}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          icon: Icons.delivery_dining,
                          label: l10n.translate('deliveries'),
                          value: '$_todayDeliveries',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Online: show available orders / Offline: show offline state
                  if (!_isOnline) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        border: Border.all(color: const Color(0xFFFFE082)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFFF39C12), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.translate('you_are_offline'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFF39C12),
                                        fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(l10n.translate('toggle_availability_desc'),
                                    style: TextStyle(color: Colors.orange.shade700, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _quickTile(Icons.delivery_dining, l10n.translate('deliveries'),
                            () => Navigator.pushNamed(context, '/order-history'))),
                        const SizedBox(width: 12),
                        Expanded(child: _quickTile(Icons.trending_up, l10n.translate('earnings'),
                            () => Navigator.pushNamed(context, '/wallet'))),
                      ],
                    ),
                  ] else ...[
                    if (_availableOrders.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.delivery_dining,
                                size: 48, color: AppTheme.textSecondary.withOpacity(0.4)),
                            const SizedBox(height: 8),
                            Text(l10n.translate('no_jobs_nearby'),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text(l10n.translate('new_jobs_desc'),
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ],
                        ),
                      )
                    else ...[
                      Text(l10n.translate('new_tasks'),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ..._availableOrders.map((order) => _jobCard(order, l10n)),
                    ],
                  ],
                  const SizedBox(height: 16),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primary, size: 22),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _quickTile(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _jobCard(Map<String, dynamic> order, AppLocalizations l10n) {
    final fee = (order['deliveryFee'] as num?)?.toDouble() ?? 0;
    final distance = order['distance'];
    final pickup = order['pickupAddress']?.toString() ?? 'Pharmacy';
    final delivery = order['deliveryAddress']?.toString() ?? 'Patient';
    // Extract pharmacy name from pickup address (first part before comma)
    final pharmacyName = pickup.contains(',') ? pickup.split(',').first.trim() : pickup;
    final patientName = delivery.contains(',') ? delivery.split(',').first.trim() : delivery;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.primary.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(pharmacyName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${fee.toStringAsFixed(0)} ${l10n.translate('mad')}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.primary)),
                  Text(l10n.translate('payment'),
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${l10n.translate('pickup_for')} $patientName',
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          if (distance != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text('$distance km',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _acceptOrder(order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
                    elevation: 0,
                  ),
                  child: Text(l10n.translate('accept'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _skipOrder(order),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
                  ),
                  child: Text(l10n.translate('skip'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
