import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/order_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/notification_bell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().fetchOrders();
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['tab'] != null) {
        setState(() => _selectedIndex = args['tab'] as int);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textSecondary,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home_outlined), activeIcon: const Icon(Icons.home), label: l10n.translate('home')),
          BottomNavigationBarItem(icon: const Icon(Icons.receipt_long_outlined), activeIcon: const Icon(Icons.receipt_long), label: l10n.translate('orders')),
          BottomNavigationBarItem(icon: const Icon(Icons.person_outline), activeIcon: const Icon(Icons.person), label: l10n.translate('profile')),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: return _HomeTab(onTabChange: (i) => setState(() => _selectedIndex = i));
      case 1: return _OrdersTab();
      case 2: return _ProfileTab();
      default: return _HomeTab(onTabChange: (i) => setState(() => _selectedIndex = i));
    }
  }
}

class _HomeTab extends StatelessWidget {
  final ValueChanged<int> onTabChange;
  const _HomeTab({required this.onTabChange});

  String _greeting(AppLocalizations l10n) {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning'; // Could add these to l10n later
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'delivered': return AppTheme.success;
      case 'in_transit': case 'picked_up': case 'assigned': return AppTheme.info;
      case 'cancelled': return AppTheme.error;
      default: return AppTheme.warning;
    }
  }

  String _statusLabel(String s, AppLocalizations l10n) {
    switch (s) {
      case 'delivered': return l10n.translate('order_delivered');
      case 'in_transit': return l10n.translate('order_on_way');
      case 'picked_up': return l10n.translate('order_picked_up');
      case 'assigned': return l10n.translate('order_ready'); // or rider assigned
      case 'confirmed': return l10n.translate('order_confirmed');
      case 'searching': return l10n.translate('searching_pharmacy');
      case 'quote_pending': return l10n.translate('quote_received');
      default: return l10n.translate('status');
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'delivered': return Icons.check_circle;
      case 'in_transit': return Icons.local_shipping;
      case 'picked_up': return Icons.shopping_bag;
      case 'assigned': return Icons.delivery_dining;
      case 'quote_pending': return Icons.receipt;
      default: return Icons.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final l10n = AppLocalizations.of(context)!;

    return Consumer<OrderProvider>(
      builder: (context, orderProvider, _) {
        final orders = orderProvider.orders;
        final active = orders.where((o) => !['delivered', 'cancelled'].contains(o.status)).length;
        final completed = orders.where((o) => o.status == 'delivered').length;
        final pending = orders.where((o) => o.status == 'quote_pending').length;
        final recent = orders.take(3).toList();

        return RefreshIndicator(
          onRefresh: () => orderProvider.fetchOrders(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusXLarge)),
                  ),
                  padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_greeting(l10n), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(user?.fullName ?? 'User',
                                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const NotificationBell(),
                              const SizedBox(width: 4),
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                child: Text(
                                  (user?.fullName ?? 'U').substring(0, 1).toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                        child: Row(
                          children: [
                            _headerStat(l10n.translate('active_orders'), '$active', Icons.local_shipping_outlined),
                            Container(width: 1, height: 40, color: Colors.white30),
                            _headerStat(l10n.translate('order_delivered'), '$completed', Icons.check_circle_outline),
                            Container(width: 1, height: 40, color: Colors.white30),
                            _headerStat(l10n.translate('my_quotes'), '$pending', Icons.receipt_outlined),
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
                    // Upload prescription CTA
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/upload-prescription'),
                      child: Container(
                        padding: const EdgeInsets.all(AppTheme.spacing16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.primary, AppTheme.primary.withOpacity(0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l10n.translate('upload_prescription'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 2),
                                  const Text('Get quotes from nearby pharmacies', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Quick actions
                    Text(l10n.translate('how_can_we_help'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _actionTile(context, Icons.receipt_long, l10n.translate('orders'), AppTheme.info,
                            badge: active > 0 ? '$active' : null,
                            onTap: () => onTabChange(1))),
                        const SizedBox(width: 12),
                        Expanded(child: _actionTile(context, Icons.local_pharmacy, l10n.translate('my_quotes'), AppTheme.warning,
                            badge: pending > 0 ? '$pending' : null,
                            onTap: () => Navigator.pushNamed(context, '/my-quotes'))),
                        const SizedBox(width: 12),
                        Expanded(child: _actionTile(context, Icons.history, l10n.translate('order_history'), AppTheme.success,
                            onTap: () => Navigator.pushNamed(context, '/order-history'))),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Recent orders
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.translate('active_orders'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        TextButton(onPressed: () => onTabChange(1), child: Text(l10n.translate('view_all'))),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (orderProvider.isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (recent.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 48, color: AppTheme.textSecondary.withOpacity(0.4)),
                            const SizedBox(height: 8),
                            Text(l10n.translate('no_active_orders'), style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(l10n.translate('prescription_desc'),
                                style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
                          ],
                        ),
                      )
                    else
                      ...recent.map((o) => GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/order-tracking', arguments: o.id),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: _statusColor(o.status).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(_statusIcon(o.status), color: _statusColor(o.status), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(o.orderNumber.isNotEmpty ? o.orderNumber : l10n.translate('quote_received'),
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    Text(_statusLabel(o.status, l10n),
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${o.totalAmount.toStringAsFixed(0)} MRO',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _statusColor(o.status).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(_statusLabel(o.status, l10n),
                                        style: TextStyle(fontSize: 10, color: _statusColor(o.status), fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _headerStat(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _actionTile(BuildContext context, IconData icon, String label, Color color,
      {VoidCallback? onTap, String? badge}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 8),
                Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
              ],
            ),
            if (badge != null)
              Positioned(
                top: 0, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.error, borderRadius: BorderRadius.circular(10)),
                  child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OrdersTab extends StatelessWidget {
  Color _statusColor(String s) {
    switch (s) {
      case 'delivered': return AppTheme.success;
      case 'in_transit': case 'picked_up': case 'assigned': return AppTheme.info;
      case 'cancelled': return AppTheme.error;
      default: return AppTheme.warning;
    }
  }

  String _statusLabel(String s, AppLocalizations l10n) {
    switch (s) {
      case 'delivered': return l10n.translate('order_delivered');
      case 'in_transit': return l10n.translate('order_on_way');
      case 'picked_up': return l10n.translate('order_picked_up');
      case 'assigned': return l10n.translate('order_ready');
      case 'confirmed': return l10n.translate('order_confirmed');
      case 'searching': return l10n.translate('searching_pharmacy');
      case 'quote_pending': return l10n.translate('quote_received');
      default: return l10n.translate('status');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('orders')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<OrderProvider>().fetchOrders(),
          ),
        ],
      ),
      body: Consumer<OrderProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) return const Center(child: CircularProgressIndicator());
          if (provider.orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 80, color: AppTheme.textSecondary.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  Text(l10n.translate('no_active_orders'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(l10n.translate('prescription_desc'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => provider.fetchOrders(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: provider.orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final o = provider.orders[i];
                final color = _statusColor(o.status);
                return GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/order-tracking', arguments: o.id),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      side: const BorderSide(color: AppTheme.divider),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(o.orderNumber.isNotEmpty ? o.orderNumber : l10n.translate('quote_received'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                ),
                                child: Text(_statusLabel(o.status, l10n),
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${o.createdAt.day.toString().padLeft(2, '0')}/${o.createdAt.month.toString().padLeft(2, '0')}/${o.createdAt.year}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                              Text('${o.totalAmount.toStringAsFixed(2)} MRO',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 14)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('profile'))),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: AppTheme.surface,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                    backgroundImage: (user?.profileImage != null &&
                            user!.profileImage!.toString().startsWith('http'))
                        ? NetworkImage(user.profileImage!)
                        : null,
                    child: (user?.profileImage == null ||
                            !user!.profileImage!.toString().startsWith('http'))
                        ? Text(
                            (user?.fullName ?? 'U').substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(user?.fullName ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  if (user?.email != null) Text(user!.email!, style: const TextStyle(color: AppTheme.textSecondary)),
                  Text(user?.phone ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _menuItem(context, Icons.person_outline, l10n.translate('edit_profile'), () => Navigator.pushNamed(context, '/edit-profile')),
            _menuItem(context, Icons.language_outlined, l10n.translate('language'), () => _showLanguageDialog(context)),
            _menuItem(context, Icons.location_on_outlined, l10n.translate('saved_addresses'), () => Navigator.pushNamed(context, '/saved-addresses')),
            _menuItem(context, Icons.history, l10n.translate('order_history'), () => Navigator.pushNamed(context, '/order-history')),
            _menuItem(context, Icons.receipt_long_outlined, l10n.translate('my_quotes'), () => Navigator.pushNamed(context, '/my-quotes')),
            _menuItem(context, Icons.help_outline, l10n.translate('help_support'), () => Navigator.pushNamed(context, '/help-support')),
            const Divider(height: 1),
            _menuItem(context, Icons.logout, l10n.translate('logout'), () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(l10n.translate('logout')),
                  content: Text(l10n.translate('logout_confirm')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.translate('cancel'))),
                    TextButton(onPressed: () => Navigator.pop(context, true),
                        child: Text(l10n.translate('logout'), style: const TextStyle(color: AppTheme.error))),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await context.read<AuthProvider>().logout();
                Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
              }
            }, color: AppTheme.error),
            _menuItem(context, Icons.delete_forever, l10n.translate('delete_account'),
                () => _confirmDeleteAccount(context),
                color: AppTheme.error),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.translate('delete_account')),
        content: Text(l10n.translate('delete_account_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.translate('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.translate('delete'), style: const TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Blocking loader while the account is deleted
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final ok = await context.read<AuthProvider>().deleteAccount();
    if (!context.mounted) return;
    Navigator.pop(context); // dismiss loader

    if (ok) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('account_deleted'))),
      );
    } else {
      final error = context.read<AuthProvider>().error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? l10n.translate('delete_account_failed')),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _showLanguageDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageProvider = context.read<LanguageProvider>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('select_language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.translate('english')),
              onTap: () {
                languageProvider.setLanguage('en');
                Navigator.pop(context);
              },
              trailing: languageProvider.locale.languageCode == 'en'
                  ? const Icon(Icons.check, color: AppTheme.primary)
                  : null,
            ),
            ListTile(
              title: Text(l10n.translate('french')),
              onTap: () {
                languageProvider.setLanguage('fr');
                Navigator.pop(context);
              },
              trailing: languageProvider.locale.languageCode == 'fr'
                  ? const Icon(Icons.check, color: AppTheme.primary)
                  : null,
            ),
            ListTile(
              title: Text(l10n.translate('arabic')),
              onTap: () {
                languageProvider.setLanguage('ar');
                Navigator.pop(context);
              },
              trailing: languageProvider.locale.languageCode == 'ar'
                  ? const Icon(Icons.check, color: AppTheme.primary)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(BuildContext context, IconData icon, String label, VoidCallback onTap, {Color? color}) {
    final c = color ?? AppTheme.textPrimary;
    return Material(
      color: AppTheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: c, size: 22),
              const SizedBox(width: 16),
              Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: c))),
              Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondary.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
