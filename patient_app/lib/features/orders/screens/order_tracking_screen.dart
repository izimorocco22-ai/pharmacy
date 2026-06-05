import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../providers/order_provider.dart';
import '../../../models/order_model.dart';
import '../../../services/api_service.dart';
import '../../../core/localization/app_localizations.dart';
import 'payment_proof_screen.dart';
import 'rider_tracking_screen.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late Razorpay _razorpay;
  Order? _pendingOrder;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<OrderProvider>();
      if (provider.orders.isEmpty) {
        await provider.fetchOrders();
      }
      provider.trackOrder(widget.orderId);
    });
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) async {
    if (_pendingOrder == null || !mounted) return;
    _showLoading('Confirming order...');
    try {
      final provider = context.read<OrderProvider>();
      final res = await provider.confirmQuote(
        quoteId: _pendingOrder!.quoteId!,
        paymentMethod: 'online',
      );
      if (mounted) Navigator.pop(context);
      if (res && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment successful! Order confirmed 🎉'), backgroundColor: Colors.green),
        );
        await provider.fetchOrders();
        if (mounted) Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
    _pendingOrder = null;
  }

  void _onPaymentError(PaymentFailureResponse response) {
    _pendingOrder = null;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed: ${response.message ?? 'Try again'}'),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    _pendingOrder = null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('order_details'))),
      body: Consumer<OrderProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final order = provider.currentOrder;
          if (order == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long, size: 64, color: AppTheme.textHint),
                  const SizedBox(height: AppTheme.spacing16),
                  Text(l10n.translate('order_not_found')),
                  const SizedBox(height: AppTheme.spacing16),
                  TextButton(
                    onPressed: () => context.read<OrderProvider>().trackOrder(widget.orderId),
                    child: Text(l10n.translate('retry')),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => context.read<OrderProvider>().trackOrder(widget.orderId),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusBanner(order, l10n),
                  const SizedBox(height: AppTheme.spacing16),
                  // Track Rider button
                  if (order.status == 'in_transit' || order.status == 'picked_up') ...[
                    _buildTrackRiderButton(order),
                    const SizedBox(height: AppTheme.spacing16),
                  ],
                  // Rejection History
                  if (order.quoteHistory.any((q) => q.status == 'rejected' && q.rejectionReason.isNotEmpty)) ...[
                    _buildRejectionHistory(order.quoteHistory),
                    const SizedBox(height: AppTheme.spacing16),
                  ],
                  // Pending quote actions
                  if (order.isPendingQuote && (order.expiresAt == null || order.expiresAt!.isAfter(DateTime.now()))) ...[
                    _buildPendingQuoteActions(order, l10n),
                    const SizedBox(height: AppTheme.spacing16),
                  ],
                  _buildOrderInfo(order, l10n),
                  const SizedBox(height: AppTheme.spacing16),
                  _buildDeliveryAddress(order, l10n),
                  const SizedBox(height: AppTheme.spacing16),
                  if (order.prescriptionImage != null && order.prescriptionImage!.isNotEmpty) ...[
                    _buildPrescriptionImage(order.prescriptionImage!),
                    const SizedBox(height: AppTheme.spacing16),
                  ],
                  if (order.medicines.isNotEmpty) ...[
                    _buildMedicinesList(order.medicines, l10n),
                    const SizedBox(height: AppTheme.spacing16),
                  ],
                  // Payment proof
                  if (order.paymentProofUrl != null && order.paymentProofUrl!.isNotEmpty) ...[
                    _buildPaymentProof(order.paymentProofUrl!, order.status),
                    const SizedBox(height: AppTheme.spacing16),
                  ],
                  // Quote details (medicines + pricing)
                  if (order.items.isNotEmpty) ...[
                    _buildQuoteDetails(order, l10n),
                    const SizedBox(height: AppTheme.spacing16),
                  ],
                  // Order status timeline (only for confirmed orders)
                  if (!order.isPendingQuote) ...[
                    _buildStatusTimeline(order, l10n),
                    const SizedBox(height: AppTheme.spacing16),
                  ],
                  if (!order.isPendingQuote) ...[
                    _buildAmountSummary(order, l10n),
                    const SizedBox(height: AppTheme.spacing16),
                  ],
                  if (order.rider != null) ...[
                    _buildRiderInfo(order.rider!, l10n),
                    const SizedBox(height: AppTheme.spacing16),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrackRiderButton(Order order) {
    // Parse delivery coords from deliveryAddress
    LatLng? deliveryLatLng;
    try {
      final loc = order.deliveryAddress?['location'];
      if (loc != null) {
        final coords = loc['coordinates'] as List?;
        if (coords != null && coords.length == 2) {
          deliveryLatLng = LatLng(
            (coords[1] as num).toDouble(),
            (coords[0] as num).toDouble(),
          );
        }
      }
    } catch (_) {}

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RiderTrackingScreen(
              orderId: order.id,
              deliveryAddress:
                  order.deliveryAddress?['address']?.toString() ?? '',
              deliveryLocation: deliveryLatLng,
            ),
          ),
        ),
        icon: const Icon(Icons.delivery_dining, size: 20),
        label: const Text('Track Rider'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(Order order, AppLocalizations l10n) {
    final isPending = order.isPendingQuote;
    final isSearching = order.status == 'searching';
    final isExpired = order.status == 'expired';
    final isPaymentVerification = order.status == 'payment_verification';
    
    final color = isPending ? Colors.orange 
                : isSearching ? AppTheme.primary 
                : isExpired ? AppTheme.error
                : isPaymentVerification ? Colors.blueGrey
                : _statusColor(order.status);
                
    final icon = isPending ? Icons.local_pharmacy 
               : isSearching ? Icons.search 
               : isExpired ? Icons.timer_off
               : isPaymentVerification ? Icons.hourglass_top
               : _statusIcon(order.status);
               
    final label = isPending ? l10n.translate('quote_received') 
                : isSearching ? l10n.translate('searching_pharmacy') 
                : isExpired ? l10n.translate('order_expired')
                : isPaymentVerification ? 'Payment Verification'
                : _statusLabel(order.status, l10n);
                
    final sub = isPending
        ? '${l10n.translate('total')}: ${order.totalAmount.toStringAsFixed(2)} MAD'
        : isSearching
            ? l10n.translate('finding_pharmacy_desc')
            : isExpired
                ? l10n.translate('no_pharmacy_timeout')
                : isPaymentVerification
                    ? 'Your payment proof is being reviewed by the pharmacy'
                    : (order.orderNumber.isNotEmpty ? order.orderNumber : 'Order #${order.id.substring(order.id.length > 6 ? order.id.length - 6 : 0).toUpperCase()}');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacing20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 40),
          const SizedBox(height: AppTheme.spacing8),
          Text(label,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppTheme.spacing4),
          Text(sub,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85)),
              textAlign: TextAlign.center),
          if (isPending && order.expiresAt != null) ...[
            const SizedBox(height: AppTheme.spacing8),
            _CountdownTimer(
              expiresAt: order.expiresAt!,
              onTimeout: () => context.read<OrderProvider>().trackOrder(widget.orderId),
              isBanner: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRejectionHistory(List<QuoteHistoryItem> history) {
    final rejections = history.where((q) => q.status == 'rejected' && q.rejectionReason.isNotEmpty).toList();
    if (rejections.isEmpty) return const SizedBox.shrink();

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.error, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Order Rejected ${rejections.length} ${rejections.length == 1 ? 'time' : 'times'}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),
            ...rejections.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.circle, size: 6, color: AppTheme.error),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.rejectionReason,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          _formatDate(r.createdAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingQuoteActions(Order order, AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _cancelQuote(order),
            icon: const Icon(Icons.close, size: 18),
            label: Text(l10n.translate('cancel')),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _confirmQuote(order),
            icon: const Icon(Icons.check, size: 18),
            label: Text(l10n.translate('confirm_order')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmQuote(Order order) async {
    final l10n = AppLocalizations.of(context)!;
    final paymentMethod = order.paymentMethodDetails;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.translate('confirm_order')),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.pop(_, false),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l10n.translate('confirm_order_desc')} ${order.totalAmount.toStringAsFixed(2)} MAD?'),
            if (paymentMethod != null) ...[
              const SizedBox(height: 16),
              _PaymentMethodCard(paymentMethod: paymentMethod),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(_, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Pay Now'),
            ),
          ),
        ],
      ),
    );

    if (proceed != true || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentProofScreen(order: order),
      ),
    );
  }

  Widget _paymentOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 13, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelQuote(Order order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Quote'),
        content: const Text("Cancel this quote? We'll send your request to the next nearest pharmacy."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Quote', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    _showLoading('Cancelling...');
    try {
      final provider = context.read<OrderProvider>();
      final res = await provider.cancelQuote(quoteId: order.quoteId!);
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res ? 'Quote cancelled. Request sent to next pharmacy!' : 'Quote cancelled.'),
            backgroundColor: Colors.orange,
          ),
        );
        await provider.fetchOrders();
        if (mounted) Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  void _showLoading(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Text(msg),
        ]),
      ),
    );
  }

  Widget _buildPaymentProof(String proofUrl, String status) {
    final isVerified = status != 'payment_verification';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16, AppTheme.spacing16,
                AppTheme.spacing16, AppTheme.spacing12),
            child: Row(
              children: [
                const Icon(Icons.receipt, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Payment Proof',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isVerified
                        ? AppTheme.success.withValues(alpha: 0.1)
                        : AppTheme.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isVerified ? Icons.check_circle : Icons.hourglass_top,
                        size: 12,
                        color: isVerified ? AppTheme.success : AppTheme.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isVerified ? 'Verified' : 'Pending',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isVerified ? AppTheme.success : AppTheme.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(AppTheme.radiusLarge),
              bottomRight: Radius.circular(AppTheme.radiusLarge),
            ),
            child: Image.network(
              proofUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : Container(
                      height: 200,
                      color: AppTheme.background,
                      child: const Center(child: CircularProgressIndicator()),
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
    );
  }

  Widget _buildQuoteDetails(Order order, AppLocalizations l10n) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.translate('quote_details'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppTheme.spacing12),
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: const Icon(Icons.medication, size: 16, color: AppTheme.primary),
                      ),
                      const SizedBox(width: AppTheme.spacing12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.medicineName, style: Theme.of(context).textTheme.bodyMedium),
                            Text('${l10n.translate('quantity')}: ${item.quantity} × ${item.unitPrice.toStringAsFixed(2)} MAD',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      Text('${item.totalPrice.toStringAsFixed(2)} MAD',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                )),
            const Divider(height: 20),
            _summaryRow(l10n.translate('subtotal'), order.subtotal),
            if (order.commissionAmount > 0)
              _summaryRow(
                '${l10n.translate('service_fee')} (${order.commissionRate.toStringAsFixed(0)}%)',
                order.commissionAmount,
              ),
            _summaryRow(l10n.translate('delivery_fee'), order.deliveryFee),
            const Divider(height: 12),
            _summaryRow(l10n.translate('total'), order.totalAmount, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                  fontSize: isTotal ? 15 : 13,
                  color: isTotal ? Colors.black : AppTheme.textSecondary)),
          Text('${amount.toStringAsFixed(2)} MAD',
              style: TextStyle(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                  fontSize: isTotal ? 15 : 13,
                  color: isTotal ? AppTheme.primary : AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildOrderInfo(Order order, AppLocalizations l10n) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.translate('order_information'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppTheme.spacing12),
            _infoRow(Icons.calendar_today, 'Date', _formatDate(order.createdAt)),
            if (order.paymentMethod != null)
              _infoRow(Icons.payment, 'Payment', order.paymentMethod!.toUpperCase()),
            if (order.estimatedDeliveryTime != null)
              _infoRow(Icons.access_time, l10n.translate('est_delivery'), _formatDate(order.estimatedDeliveryTime!)),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryAddress(Order order, AppLocalizations l10n) {
    final address = order.deliveryAddress?['address']?.toString();
    if (address == null || address.isEmpty) return const SizedBox.shrink();

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.translate('address'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppTheme.spacing12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, color: AppTheme.primary, size: 20),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text(address, style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicinesList(List<Map<String, dynamic>> medicines, AppLocalizations l10n) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medication, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(l10n.translate('requested_medicines'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),
            ...medicines.map((m) => Container(
                  margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing12, vertical: AppTheme.spacing12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: Text(
                          '${l10n.translate('quantity')}: ${m['quantity'] ?? 1}',
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
    );
  }

  Widget _buildPrescriptionImage(String imageUrl) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, AppTheme.spacing16, AppTheme.spacing16, AppTheme.spacing12),
            child: Text('Prescription', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(AppTheme.radiusLarge),
              bottomRight: Radius.circular(AppTheme.radiusLarge),
            ),
            child: Image.network(
              imageUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : Container(
                      height: 200,
                      color: AppTheme.background,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
              errorBuilder: (_, __, ___) => Container(
                height: 120,
                color: AppTheme.background,
                child: const Center(child: Icon(Icons.broken_image, color: AppTheme.textHint, size: 40)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline(Order order, AppLocalizations l10n) {
    final allStatuses = [
      {'status': 'pending', 'label': 'Order Placed', 'icon': Icons.receipt},
      {'status': 'payment_verification', 'label': 'Payment Verification', 'icon': Icons.hourglass_top},
      {'status': 'confirmed', 'label': l10n.translate('order_confirmed'), 'icon': Icons.check_circle},
      {'status': 'preparing', 'label': l10n.translate('order_preparing'), 'icon': Icons.medication},
      {'status': 'ready', 'label': l10n.translate('order_ready'), 'icon': Icons.shopping_bag},
      {'status': 'picked_up', 'label': l10n.translate('order_picked_up'), 'icon': Icons.shopping_bag},
      {'status': 'in_transit', 'label': l10n.translate('order_on_way'), 'icon': Icons.local_shipping},
      {'status': 'delivered', 'label': l10n.translate('order_delivered'), 'icon': Icons.done_all},
    ];

    if (order.status == 'cancelled') {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing8),
                decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                child: const Icon(Icons.cancel, color: Colors.white, size: 20),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Text(l10n.translate('order_cancelled'), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.error)),
            ],
          ),
        ),
      );
    }

    final currentIndex = allStatuses.indexWhere((s) => s['status'] == order.status);

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.translate('status'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppTheme.spacing16),
            ...List.generate(allStatuses.length, (i) {
              final done = i <= currentIndex;
              final active = i == currentIndex;
              final isLast = i == allStatuses.length - 1;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: done ? AppTheme.primary : AppTheme.background,
                          shape: BoxShape.circle,
                          border: Border.all(color: done ? AppTheme.primary : AppTheme.divider, width: 2),
                        ),
                        child: Icon(allStatuses[i]['icon'] as IconData, size: 16, color: done ? Colors.white : AppTheme.textHint),
                      ),
                      if (!isLast)
                        Container(width: 2, height: 32, color: done ? AppTheme.primary : AppTheme.divider),
                    ],
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      allStatuses[i]['label'] as String,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: active ? AppTheme.primary : done ? AppTheme.textPrimary : AppTheme.textHint,
                            fontWeight: active ? FontWeight.bold : FontWeight.normal,
                          ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList(Order order) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Items', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppTheme.spacing12),
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: const Icon(Icons.medication, size: 16, color: AppTheme.primary),
                      ),
                      const SizedBox(width: AppTheme.spacing12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.medicineName, style: Theme.of(context).textTheme.bodyMedium),
                            Text('Qty: ${item.quantity}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      Text('${item.totalPrice.toStringAsFixed(2)} MAD', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountSummary(Order order, AppLocalizations l10n) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment Summary', // Could localize
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppTheme.spacing12),
            if (order.subtotal > 0) _summaryRow(l10n.translate('subtotal'), order.subtotal),
            if (order.commissionAmount > 0)
              _summaryRow(
                '${l10n.translate('service_fee')} (${order.commissionRate.toStringAsFixed(0)}%)',
                order.commissionAmount,
              ),
            if (order.deliveryFee > 0) _summaryRow(l10n.translate('delivery_fee'), order.deliveryFee),
            const Divider(),
            const SizedBox(height: AppTheme.spacing8),
            _summaryRow(l10n.translate('total'), order.totalAmount, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildRiderInfo(RiderInfo rider, AppLocalizations l10n) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.translate('rider_info'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppTheme.spacing12),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.delivery_dining, color: AppTheme.primary),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rider.name, style: Theme.of(context).textTheme.titleMedium),
                      if (rider.phone.isNotEmpty)
                        Text(rider.phone, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
                      if (rider.vehicleNumber != null)
                        Text(rider.vehicleNumber!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: AppTheme.spacing8),
          Text('$label: ', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered': return AppTheme.success;
      case 'in_transit':
      case 'picked_up':
      case 'assigned':
        return AppTheme.info;
      case 'cancelled': return AppTheme.error;
      case 'payment_verification': return Colors.blueGrey;
      default: return AppTheme.warning;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'delivered': return Icons.done_all;
      case 'in_transit': return Icons.local_shipping;
      case 'picked_up': return Icons.shopping_bag;
      case 'preparing': return Icons.medication;
      case 'confirmed': return Icons.check_circle;
      case 'payment_verification': return Icons.hourglass_top;
      case 'cancelled': return Icons.cancel;
      default: return Icons.receipt_long;
    }
  }

  String _statusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case 'delivered': return l10n.translate('order_delivered');
      case 'in_transit': return l10n.translate('order_on_way');
      case 'picked_up': return l10n.translate('order_picked_up');
      case 'assigned': return l10n.translate('order_ready');
      case 'confirmed': return l10n.translate('order_confirmed');
      case 'payment_verification': return 'Payment Verification';
      case 'searching': return l10n.translate('searching_pharmacy');
      default: return l10n.translate('status');
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final hour = date.hour > 12 ? date.hour - 12 : date.hour == 0 ? 12 : date.hour;
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final min = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year}, $hour:$min $ampm';
  }
}

class _PaymentMethodCard extends StatefulWidget {
  final Map<String, dynamic> paymentMethod;

  const _PaymentMethodCard({required this.paymentMethod});

  @override
  State<_PaymentMethodCard> createState() => _PaymentMethodCardState();
}

class _PaymentMethodCardState extends State<_PaymentMethodCard> {
  bool _copied = false;

  void _copy() {
    final details = widget.paymentMethod['details']?.toString() ?? '';
    if (details.isEmpty) return;
    Clipboard.setData(ClipboardData(text: details));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final details = widget.paymentMethod['details']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.payment, color: AppTheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(details,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ),
          if (details.isNotEmpty)
            GestureDetector(
              onTap: _copy,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _copied
                      ? AppTheme.success.withValues(alpha: 0.1)
                      : AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  _copied ? Icons.check : Icons.copy,
                  size: 16,
                  color: _copied ? AppTheme.success : AppTheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CountdownTimer extends StatefulWidget {
  final DateTime expiresAt;
  final VoidCallback onTimeout;
  final bool isBanner;

  const _CountdownTimer({
    required this.expiresAt,
    required this.onTimeout,
    this.isBanner = false,
  });

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  Timer? _timer;
  late Duration _remaining;
  bool _hasCalledTimeout = false;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    if (_remaining.inSeconds > 0) {
      _startTimer();
    } else {
      _remaining = Duration.zero;
    }
  }

  void _calculateRemaining() {
    final now = DateTime.now();
    _remaining = widget.expiresAt.difference(now);
    if (_remaining.isNegative) {
      _remaining = Duration.zero;
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _calculateRemaining();
          if (_remaining.inSeconds <= 0 && !_hasCalledTimeout) {
            _hasCalledTimeout = true;
            timer.cancel();
            widget.onTimeout();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_remaining.inSeconds <= 0) {
      return Text(
        l10n.translate('expired'),
        style: TextStyle(
          fontSize: 13,
          color: widget.isBanner ? Colors.white : Colors.orange,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    final hours = _remaining.inHours;
    final minutes = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    final isExpiringSoon = _remaining.inMinutes < 15;

    String timeStr = hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: widget.isBanner 
            ? Colors.black.withValues(alpha: 0.1) 
            : (isExpiringSoon ? Colors.orange.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(20),
        border: widget.isBanner ? Border.all(color: Colors.white.withValues(alpha: 0.3)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 14,
            color: widget.isBanner ? Colors.white : (isExpiringSoon ? Colors.orange : Colors.grey),
          ),
          const SizedBox(width: 6),
          Text(
            '${l10n.translate('expires_in')} $timeStr',
            style: TextStyle(
              fontSize: 12,
              color: widget.isBanner ? Colors.white : (isExpiringSoon ? Colors.orange : Colors.grey),
              fontWeight: isExpiringSoon || widget.isBanner ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
