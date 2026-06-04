import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../services/api_service.dart';
import '../../../services/location_service.dart';
import 'delivery_detail_screen.dart';

class NearbyDeliveriesScreen extends StatefulWidget {
  const NearbyDeliveriesScreen({super.key});

  @override
  State<NearbyDeliveriesScreen> createState() => _NearbyDeliveriesScreenState();
}

class _NearbyDeliveriesScreenState extends State<NearbyDeliveriesScreen> {
  bool _isLoading = false;
  bool _isOnline = false;
  List<dynamic> _deliveries = [];
  String? _error;

  Future<void> _loadDeliveries() async {
    if (!_isOnline) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      // Update location first so backend can filter by distance
      await LocationService.updateLocation();
      final res = await ApiService.get('/rider/nearby-deliveries');
      if (res.success) {
        setState(() {
          _deliveries = List<dynamic>.from(res.data?['deliveries'] ?? []);
        });
      } else {
        setState(() => _error = res.message);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleOnlineStatus() async {
    final newStatus = !_isOnline;
    setState(() {
      _isOnline = newStatus;
      if (!newStatus) _deliveries = [];
    });
    // Tell backend rider is online/offline
    await ApiService.put('/rider/update-location', {'isOnline': newStatus});
    if (newStatus) _loadDeliveries();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('available_orders')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppTheme.spacing8),
            child: Row(
              children: [
                Text(
                  _isOnline ? l10n.translate('online') : l10n.translate('offline'),
                  style: TextStyle(
                    color: _isOnline ? AppTheme.success : AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Switch(
                  value: _isOnline,
                  onChanged: (_) => _toggleOnlineStatus(),
                  activeColor: AppTheme.success,
                ),
              ],
            ),
          ),
        ],
      ),
      body: !_isOnline
          ? _buildOfflineState(l10n)
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildErrorState(l10n)
                  : _deliveries.isEmpty
                      ? _buildEmptyState(l10n)
                      : RefreshIndicator(
                          onRefresh: _loadDeliveries,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(AppTheme.spacing16),
                            itemCount: _deliveries.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppTheme.spacing12),
                            itemBuilder: (_, i) =>
                                _buildDeliveryCard(_deliveries[i], l10n),
                          ),
                        ),
    );
  }

  Widget _buildOfflineState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.power_settings_new,
              size: 80, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: AppTheme.spacing16),
          Text(l10n.translate('you_are_offline'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppTheme.spacing8),
          Text(l10n.translate('toggle_availability_desc'),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return RefreshIndicator(
      onRefresh: _loadDeliveries,
      child: ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delivery_dining,
                    size: 80,
                    color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                const SizedBox(height: AppTheme.spacing16),
                Text(l10n.translate('no_orders_nearby'),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppTheme.spacing8),
                Text(l10n.translate('new_jobs_desc'),
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: AppTheme.spacing24),
                TextButton.icon(
                  onPressed: _loadDeliveries,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.translate('retry')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: AppTheme.error),
          const SizedBox(height: 12),
          Text(_error ?? 'Error', style: const TextStyle(color: AppTheme.error)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadDeliveries,
            child: Text(l10n.translate('retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard(dynamic delivery, AppLocalizations l10n) {
    final distance = delivery['distance'];
    final deliveryFee = (delivery['deliveryFee'] ?? 0).toDouble();

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#${delivery['orderNumber'] ?? ''}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing12, vertical: AppTheme.spacing8),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Text(
                  '${deliveryFee.toStringAsFixed(2)} ${l10n.translate('mad')}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.success),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing16),
          _buildAddressRow(
            Icons.store,
            l10n.translate('pickup'),
            delivery['pickupAddress'] ?? '',
          ),
          const SizedBox(height: AppTheme.spacing12),
          _buildAddressRow(
            Icons.location_on,
            l10n.translate('delivery'),
            delivery['deliveryAddress'] ?? '',
          ),
          if (distance != null) ...[
            const SizedBox(height: AppTheme.spacing12),
            Row(
              children: [
                const Icon(Icons.directions_car,
                    size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: AppTheme.spacing4),
                Text('$distance km',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
          const SizedBox(height: AppTheme.spacing16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DeliveryDetailScreen(delivery: delivery),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
              ),
              child: Text(l10n.translate('view_details')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow(IconData icon, String label, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(width: AppTheme.spacing8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(address, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
