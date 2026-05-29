import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../providers/order_provider.dart';
import '../../../models/order_model.dart';
import '../../../services/api_service.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
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
                  const Text('Order not found'),
                  const SizedBox(height: AppTheme.spacing16),
                  TextButton(
                    onPressed: () => context.read<OrderProvider>().trackOrder(widget.orderId),
                    child: const Text('Retry'),
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
                  _buildStatusBanner(order),
                  const SizedBox(height: AppTheme.spacing16),
                  // Pending quote actions
                  if (order.isPendingQuote) ...[
                    _buildPendingQuoteActions(order),
                    const SizedBox(height: AppTheme.spacing16),
                  ],
                  _buildOrderInfo(order),
                  const SizedBox(height: AppTheme.spacing16),
                  _buildDeliveryAddress(order),
                  const SizedBox(height: AppTheme.spacing16),
                  if (order.prescriptionImage != null && order.prescriptionImage!.isNotEmpty) ...[
                    _buildPrescriptionImage(order.prescriptionImage!),
                    const SizedBox(height: AppTheme.spacing16),
                  ],
                  if (order.medicines.isNotEmpty) ...[
                    _buildMedicinesList(order.medicines),
                    const SizedBox(height: AppTheme.spacing16),
                  ],
                  // Quote details (medicines + pricing)
                  if (order.items.isNotEmpty) ...[
                    _buildQuoteDetails(order),
                    const SizedBox(height: AppTheme.spacing16),
                  ],
                  // Order status timeline (only for confirmed orders)
                  if (!order.isPendingQuote) ...[
                    _buildStatusTimeline(order),
                    const SizedBox(height: AppTheme.spacing16),
                  ],
                  if (!order.isPendingQuote) ...[
                    _buildAmountSummary(order),
                    const SizedBox(height: AppTheme.spacing16),
                  ],
                  if (order.rider != null) ...[
                    _buildRiderInfo(order.rider!),
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

  Widget _buildStatusBanner(Order order) {
    final isPending = order.isPendingQuote;
    final isSearching = order.status == 'searching';
    final color = isPending ? Colors.orange : isSearching ? AppTheme.primary : _statusColor(order.status);
    final icon = isPending ? Icons.local_pharmacy : isSearching ? Icons.search : _statusIcon(order.status);
    final label = isPending ? 'Quote Received!' : isSearching ? 'Searching for Pharmacy...' : _statusLabel(order.status);
    final sub = isPending
        ? 'Total: ${order.totalAmount.toStringAsFixed(2)} MAD'
        : isSearching
            ? 'Looking for the nearest pharmacy...'
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
        ],
      ),
    );
  }

  Widget _buildPendingQuoteActions(Order order) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _cancelQuote(order),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Cancel'),
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
            label: const Text('Confirm Order'),
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
    final method = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Confirm Order'),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.pop(_, null),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        content: Text('Confirm this order for ${order.totalAmount.toStringAsFixed(2)} MAD?'),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(_, 'cash'),
                  child: const Text('COD'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(_, 'online'),
                  child: const Text('Pay Now'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (method == null || !mounted) return;

    if (method == 'cash') {
      _showLoading('Confirming order...');
      try {
        final provider = context.read<OrderProvider>();
        final res = await provider.confirmQuote(
          quoteId: order.quoteId!,
          paymentMethod: 'cash',
        );
        if (mounted) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res ? 'Order confirmed! Cash on delivery 🎉' : 'Failed to confirm order'),
              backgroundColor: res ? AppTheme.success : AppTheme.error,
            ),
          );
          if (res) {
            await provider.fetchOrders();
            if (mounted) Navigator.pop(context);
          }
        }
      } catch (_) {
        if (mounted) Navigator.pop(context);
      }
      return;
    }

    // Pay Online — Razorpay flow
    final keyResponse = await ApiService.get('/settings/razorpay');
    final razorpayKeyId = keyResponse.success ? (keyResponse.data['keyId'] ?? '') : '';

    if (razorpayKeyId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment not configured. Please contact support.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return;
    }

    _pendingOrder = order;
    final amountInSmallestUnit = (order.totalAmount * 100).toInt();

    final options = {
      'key': razorpayKeyId,
      'amount': amountInSmallestUnit,
      'currency': 'INR',
      'name': 'OrdoGo',
      'description': 'Medicine Order Payment',
      'prefill': {'contact': '', 'email': ''},
      'theme': {'color': '#2E7D32'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      _pendingOrder = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open payment: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
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

  Widget _buildQuoteDetails(Order order) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quote Details',
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
                            Text('Qty: ${item.quantity} × ${item.unitPrice.toStringAsFixed(2)} MAD',
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
            _summaryRow('Subtotal', order.subtotal),
            if (order.commissionAmount > 0)
              _summaryRow(
                'Service Fee (${order.commissionRate.toStringAsFixed(0)}%)',
                order.commissionAmount,
              ),
            _summaryRow('Delivery Fee', order.deliveryFee),
            const Divider(height: 12),
            _summaryRow('Total', order.totalAmount, isTotal: true),
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

  Widget _buildOrderInfo(Order order) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order Information', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppTheme.spacing12),
            _infoRow(Icons.calendar_today, 'Date', _formatDate(order.createdAt)),
            if (order.paymentMethod != null)
              _infoRow(Icons.payment, 'Payment', order.paymentMethod!.toUpperCase()),
            if (order.estimatedDeliveryTime != null)
              _infoRow(Icons.access_time, 'Est. Delivery', _formatDate(order.estimatedDeliveryTime!)),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryAddress(Order order) {
    final address = order.deliveryAddress?['address']?.toString();
    if (address == null || address.isEmpty) return const SizedBox.shrink();

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delivery Address', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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

  Widget _buildMedicinesList(List<Map<String, dynamic>> medicines) {
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
                Text('Requested Medicines',
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

  Widget _buildStatusTimeline(Order order) {
    final allStatuses = [
      {'status': 'pending', 'label': 'Order Placed', 'icon': Icons.receipt},
      {'status': 'confirmed', 'label': 'Confirmed', 'icon': Icons.check_circle},
      {'status': 'preparing', 'label': 'Preparing', 'icon': Icons.medication},
      {'status': 'picked_up', 'label': 'Picked Up', 'icon': Icons.shopping_bag},
      {'status': 'in_transit', 'label': 'On the Way', 'icon': Icons.local_shipping},
      {'status': 'delivered', 'label': 'Delivered', 'icon': Icons.done_all},
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
              Text('Order Cancelled', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.error)),
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
            Text('Order Status', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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

  Widget _buildAmountSummary(Order order) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment Summary',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppTheme.spacing12),
            if (order.subtotal > 0) _summaryRow('Subtotal', order.subtotal),
            if (order.commissionAmount > 0)
              _summaryRow(
                'Service Fee (${order.commissionRate.toStringAsFixed(0)}%)',
                order.commissionAmount,
              ),
            if (order.deliveryFee > 0) _summaryRow('Delivery Fee', order.deliveryFee),
            const Divider(),
            const SizedBox(height: AppTheme.spacing8),
            _summaryRow('Total', order.totalAmount, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildRiderInfo(RiderInfo rider) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delivery Rider', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
      case 'picked_up': return AppTheme.info;
      case 'cancelled': return AppTheme.error;
      case 'confirmed':
      case 'preparing': return AppTheme.warning;
      default: return AppTheme.primary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'delivered': return Icons.done_all;
      case 'in_transit': return Icons.local_shipping;
      case 'picked_up': return Icons.shopping_bag;
      case 'preparing': return Icons.medication;
      case 'confirmed': return Icons.check_circle;
      case 'cancelled': return Icons.cancel;
      default: return Icons.receipt_long;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'delivered': return 'Delivered';
      case 'in_transit': return 'On the Way';
      case 'picked_up': return 'Picked Up';
      case 'preparing': return 'Preparing';
      case 'confirmed': return 'Confirmed';
      case 'cancelled': return 'Cancelled';
      default: return 'Order Placed';
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
