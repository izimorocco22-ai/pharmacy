import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../providers/delivery_provider.dart';

class DeliveryDetailScreen extends StatelessWidget {
  final dynamic delivery;

  const DeliveryDetailScreen({super.key, required this.delivery});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('delivery_details')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderInfo(context, l10n),
            const SizedBox(height: AppTheme.spacing16),
            _buildLocationInfo(context, l10n),
            const SizedBox(height: AppTheme.spacing16),
            _buildEarningsInfo(context, l10n),
            const SizedBox(height: AppTheme.spacing24),
            Consumer<DeliveryProvider>(
              builder: (context, provider, _) => PrimaryButton(
                text: l10n.translate('accept_delivery'),
                isLoading: provider.isLoading,
                onPressed: provider.isLoading ? null : () => _acceptDelivery(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderInfo(BuildContext context, AppLocalizations l10n) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.translate('order_information'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppTheme.spacing12),
            _buildInfoRow(Icons.receipt, l10n.translate('order'), delivery.orderNumber ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfo(BuildContext context, AppLocalizations l10n) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.translate('locations'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppTheme.spacing12),
            _buildInfoRow(Icons.store, l10n.translate('pickup'), delivery.pickupAddress ?? 'N/A'),
            _buildInfoRow(Icons.location_on, l10n.translate('delivery'), delivery.deliveryAddress ?? 'N/A'),
            _buildInfoRow(Icons.straighten, l10n.translate('distance'), '${delivery.distance ?? 0} km'),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsInfo(BuildContext context, AppLocalizations l10n) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.translate('delivery_fee'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '${delivery.deliveryFee ?? 0} ${l10n.translate('mad')}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.primary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: AppTheme.spacing8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _acceptDelivery(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final success = await context.read<DeliveryProvider>().acceptDelivery(delivery.orderId);

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('delivery_accepted')),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pushReplacementNamed(
        context,
        '/navigation',
        arguments: delivery,
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<DeliveryProvider>().error ?? l10n.translate('failed_to_accept')),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}
