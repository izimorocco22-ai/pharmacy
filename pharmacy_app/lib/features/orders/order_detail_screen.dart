import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';

class OrderDetailScreen extends StatelessWidget {
  final dynamic order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final status = order['status'] ?? 'confirmed';
    final items = (order['items'] as List?) ?? [];
    final prescriptionImage = order['prescriptionImage'] as String?;
    final medicines = (order['medicines'] as List?) ?? [];
    final subtotal = (order['subtotal'] ?? 0).toDouble();
    final paymentMethod = order['paymentMethod']?.toString();
    final createdAt = order['createdAt'] != null
        ? DateTime.tryParse(order['createdAt'].toString())?.toLocal()
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spacing20),
              decoration: BoxDecoration(
                color: _statusColor(status),
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
              child: Column(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.white, size: 36),
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    status.toString().toUpperCase(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  if (order['orderNumber'] != null) ...[
                    const SizedBox(height: AppTheme.spacing4),
                    Text(
                      '#${order['orderNumber']}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white.withOpacity(0.85)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),

            // Order info
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order Information',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: AppTheme.spacing12),
                    if (createdAt != null)
                      Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 16, color: AppTheme.textSecondary),
                          const SizedBox(width: AppTheme.spacing8),
                          Text(
                            _formatDate(createdAt),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    if (paymentMethod != null && paymentMethod.isNotEmpty) ...[
                      const SizedBox(height: AppTheme.spacing8),
                      Row(
                        children: [
                          const Icon(Icons.payment,
                              size: 16, color: AppTheme.textSecondary),
                          const SizedBox(width: AppTheme.spacing8),
                          Text(
                            paymentMethod == 'cash' ? 'Cash on Delivery' : 'Online Payment',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),

            // Prescription image
            if (prescriptionImage != null && prescriptionImage.isNotEmpty) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppTheme.spacing16, AppTheme.spacing16,
                          AppTheme.spacing16, AppTheme.spacing12),
                      child: Text('Prescription',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(AppTheme.radiusLarge),
                        bottomRight: Radius.circular(AppTheme.radiusLarge),
                      ),
                      child: Image.network(
                        prescriptionImage,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : Container(
                                height: 200,
                                color: AppTheme.background,
                                child: const Center(
                                    child: CircularProgressIndicator()),
                              ),
                        errorBuilder: (_, __, ___) => Container(
                          height: 120,
                          color: AppTheme.background,
                          child: const Center(
                              child: Icon(Icons.broken_image,
                                  color: AppTheme.textHint, size: 40)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
            ],

            // Medicines list (from prescription request)
            if (medicines.isNotEmpty) ...[
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.medication, color: AppTheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text('Requested Medicines',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacing12),
                      ...medicines.map((m) => Container(
                            margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacing12,
                                vertical: AppTheme.spacing12),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              border: Border.all(
                                  color: AppTheme.primary.withOpacity(0.15)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.medication_outlined,
                                      size: 16, color: AppTheme.primary),
                                ),
                                const SizedBox(width: AppTheme.spacing12),
                                Expanded(
                                  child: Text(
                                    m['name']?.toString() ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500, fontSize: 14),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.1),
                                    borderRadius:
                                        BorderRadius.circular(AppTheme.radiusSmall),
                                  ),
                                  child: Text(
                                    'Qty: ${m['quantity'] ?? 1}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primary),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
            ],

            // Order items (quoted medicines)
            if (items.isNotEmpty) ...[
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order Items',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: AppTheme.spacing12),
                      ...items.map((item) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppTheme.spacing8),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusSmall),
                                  ),
                                  child: const Icon(Icons.medication,
                                      size: 14, color: AppTheme.primary),
                                ),
                                const SizedBox(width: AppTheme.spacing8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['medicineName'] ?? 'Unknown',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                      Text(
                                        'Qty: ${item['quantity'] ?? 1} × ${(item['unitPrice'] ?? 0).toStringAsFixed(2)} MAD',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${(item['totalPrice'] ?? 0).toStringAsFixed(2)} MAD',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          )),
                      const Divider(height: AppTheme.spacing24),
                      _summaryRow(context, 'Total',
                          '${subtotal.toStringAsFixed(2)} MAD'),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.textSecondary)),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered':
        return AppTheme.success;
      case 'cancelled':
        return AppTheme.error;
      case 'in_transit':
      case 'picked_up':
        return AppTheme.info;
      default:
        return AppTheme.warning;
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day} ${months[date.month - 1]} ${date.year}, $hour:$minute $period';
  }
}
