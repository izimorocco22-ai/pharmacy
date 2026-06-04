import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../models/quote_model.dart';
import '../../../services/api_service.dart';
import '../../../providers/order_provider.dart';
import '../../../core/localization/app_localizations.dart';

class QuoteDetailsScreen extends StatelessWidget {
  final Quote quote;

  const QuoteDetailsScreen({super.key, required this.quote});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('quote_details')),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacing20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppTheme.spacing12),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium,
                                ),
                              ),
                              child: const Icon(
                                Icons.local_pharmacy,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacing12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.translate('pharmacy_quote'),
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: AppTheme.spacing4),
                                  Text(
                                    '${l10n.translate('quote_expires_in')} ${_getTimeRemaining(quote.expiresAt, l10n)}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppTheme.warning,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.translate('medicine_breakdown'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppTheme.spacing16),
                        ...quote.items.map((item) => _buildMedicineItem(
                              context,
                              item,
                              l10n,
                            )),
                        const Divider(height: AppTheme.spacing24),
                        _buildPriceRow(
                          context,
                          l10n.translate('subtotal'),
                          quote.subtotal,
                          false,
                        ),
                        const SizedBox(height: AppTheme.spacing8),
                        _buildPriceRow(
                          context,
                          l10n.translate('delivery_fee'),
                          quote.deliveryFee,
                          false,
                        ),
                        const Divider(height: AppTheme.spacing24),
                        _buildPriceRow(
                          context,
                          l10n.translate('total'),
                          quote.totalAmount,
                          true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      text: l10n.translate('decline'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: PrimaryButton(
                      text: l10n.translate('accept'),
                      onPressed: () {
                        Navigator.pushNamed(context, '/payment-selection');
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineItem(BuildContext context, QuoteItem item, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.medicineName,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  '${l10n.translate('quantity')}: ${item.quantity} × ${item.unitPrice.toStringAsFixed(2)} MAD',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '${item.totalPrice.toStringAsFixed(2)} MAD',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    BuildContext context,
    String label,
    double amount,
    bool isTotal,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? Theme.of(context).textTheme.titleLarge
              : Theme.of(context).textTheme.bodyLarge,
        ),
        Text(
          '${amount.toStringAsFixed(2)} MAD',
          style: isTotal
              ? Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  )
              : Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }

  String _getTimeRemaining(DateTime expiresAt, AppLocalizations l10n) {
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return l10n.translate('expired');
    if (remaining.inMinutes < 60) return '${remaining.inMinutes} ${l10n.translate('minutes')}';
    return '${remaining.inHours} ${l10n.translate('hours')}';
  }
}
