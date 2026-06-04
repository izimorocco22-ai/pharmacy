import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../providers/order_provider.dart';
import '../../../services/api_service.dart';

class MyQuotesScreen extends StatefulWidget {
  const MyQuotesScreen({super.key});

  @override
  State<MyQuotesScreen> createState() => _MyQuotesScreenState();
}

class _MyQuotesScreenState extends State<MyQuotesScreen> {
  List<dynamic> _quotes = [];
  bool _loading = true;
  String? _error;
  late Razorpay _razorpay;
  dynamic _pendingQuote;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
    _fetchQuotes();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _fetchQuotes() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.get('/patient/quotes');
      if (res.success) {
        setState(() => _quotes = List<dynamic>.from(res.data?['quotes'] ?? []));
      } else {
        setState(() => _error = res.message);
      }
    } catch (_) {
      setState(() => _error = 'Failed to load quotes');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Payment handlers ──────────────────────────────────────────────────────

  void _onPaymentSuccess(PaymentSuccessResponse response) async {
    if (_pendingQuote == null || !mounted) return;
    _showLoading('Confirming order...');
    try {
      final res = await context.read<OrderProvider>().confirmQuote(
        quoteId: _pendingQuote['id'].toString(),
        paymentMethod: 'online',
      );
      if (mounted) Navigator.pop(context); // close loading
      if (res && mounted) {
        _showSuccess('Payment successful! Order confirmed 🎉');
        _fetchQuotes();
      }
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
    _pendingQuote = null;
  }

  void _onPaymentError(PaymentFailureResponse response) {
    _pendingQuote = null;
    if (!mounted) return;
    _showError('Payment failed: ${response.message ?? 'Try again'}');
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    _pendingQuote = null;
  }

  // ── Confirm flow (same as order_tracking_screen) ──────────────────────────

  Future<void> _confirmQuote(dynamic quote) async {
    final totalAmount = (quote['totalAmount'] as num?)?.toDouble() ?? 0;

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
        content: Text('Confirm this order for ${totalAmount.toStringAsFixed(2)} MAD?'),
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
        final res = await context.read<OrderProvider>().confirmQuote(
          quoteId: quote['id'].toString(),
          paymentMethod: 'cash',
        );
        if (mounted) Navigator.pop(context);
        if (mounted) {
          if (res) {
            _showSuccess('Order confirmed! Cash on delivery 🎉');
            _fetchQuotes();
          } else {
            _showError('Failed to confirm order');
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
      if (mounted) _showError('Payment not configured. Please contact support.');
      return;
    }

    _pendingQuote = quote;
    final amountInSmallestUnit = (totalAmount * 100).toInt();

    final options = {
      'key': razorpayKeyId,
      'amount': amountInSmallestUnit,
      'currency': 'INR',
      'name': 'OrdoGo',
      'description': 'Medicine Order Payment',
      'prefill': {'contact': '', 'email': ''},
      'theme': {'color': '#2ECC71'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      _pendingQuote = null;
      if (mounted) _showError('Could not open payment: $e');
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
          border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
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
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 13, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  // ── Cancel flow (same as order_tracking_screen) ───────────────────────────

  Future<void> _cancelQuote(dynamic quote) async {
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
      final res = await context.read<OrderProvider>().cancelQuote(quoteId: quote['id'].toString());
      if (mounted) Navigator.pop(context); // close loading
      if (mounted) {
        _showSuccess(res ? 'Quote cancelled. Request sent to next pharmacy!' : 'Quote cancelled.');
        _fetchQuotes();
      }
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

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

  void _showSuccess(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.success),
    );
  }

  void _showError(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Quotes'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchQuotes)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 60, color: AppTheme.error),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppTheme.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _fetchQuotes, child: const Text('Retry')),
                    ],
                  ),
                )
              : _quotes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('No quotes yet', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text('Quotes from pharmacies will appear here',
                              style: TextStyle(color: Colors.grey.shade500), textAlign: TextAlign.center),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchQuotes,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _quotes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _buildQuoteCard(_quotes[i]),
                      ),
                    ),
    );
  }

  Widget _buildQuoteCard(dynamic quote) {
    final items = List<dynamic>.from(quote['items'] ?? []);
    final totalAmount = (quote['totalAmount'] as num?)?.toDouble() ?? 0;
    final deliveryFee = (quote['deliveryFee'] as num?)?.toDouble() ?? 0;
    final subtotal = (quote['subtotal'] as num?)?.toDouble() ?? 0;
    final commissionAmount = (quote['commissionAmount'] as num?)?.toDouble() ?? 0;
    final commissionRate = (quote['commissionRate'] as num?)?.toDouble() ?? 0;
    final expiresAt = quote['expiresAt'] != null
        ? DateTime.tryParse(quote['expiresAt'].toString())
        : null;
    final isExpired = quote['status'] == 'expired' || 
                     (expiresAt != null && expiresAt.isBefore(DateTime.now()));

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.receipt_long, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Quote Received',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      if (expiresAt != null)
                        _CountdownTimer(
                          expiresAt: expiresAt,
                          onTimeout: _fetchQuotes,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${totalAmount.toStringAsFixed(2)} MAD',
                    style: const TextStyle(
                        color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),

            const Divider(height: 20),

            // Medicine items
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.medication, size: 14, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${item['medicineName']} × ${item['quantity']}',
                                style: const TextStyle(fontSize: 14)),
                            Text('${item['quantity']} × ${(item['unitPrice'] as num).toStringAsFixed(2)} MAD',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      Text('${(item['totalPrice'] as num).toStringAsFixed(2)} MAD',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )),

            const Divider(height: 16),

            // Price breakdown with service fee
            _priceRow('Subtotal', subtotal),
            if (commissionAmount > 0)
              _priceRow(
                'Service Fee (${commissionRate.toStringAsFixed(0)}%)',
                commissionAmount,
              ),
            _priceRow('Delivery Fee', deliveryFee),
            const SizedBox(height: 4),
            _priceRow('Total', totalAmount, isTotal: true),

            const SizedBox(height: 16),

            // Action buttons — same as order_tracking_screen
            if (!isExpired)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _cancelQuote(quote),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmQuote(quote),
                      icon: const Icon(Icons.payment, size: 18),
                      label: const Text('Pay Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _priceRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                  fontSize: isTotal ? 15 : 13,
                  color: isTotal ? AppTheme.textPrimary : AppTheme.textSecondary)),
          Text('${amount.toStringAsFixed(2)} MAD',
              style: TextStyle(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                  fontSize: isTotal ? 15 : 13,
                  color: isTotal ? AppTheme.primary : AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _CountdownTimer extends StatefulWidget {
  final DateTime expiresAt;
  final VoidCallback onTimeout;

  const _CountdownTimer({required this.expiresAt, required this.onTimeout});

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
    if (_remaining.inSeconds <= 0) {
      return const Text(
        'Expired',
        style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
      );
    }

    final hours = _remaining.inHours;
    final minutes = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    final isExpiringSoon = _remaining.inMinutes < 15;

    String timeStr = hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';

    return Text(
      'Expires in $timeStr',
      style: TextStyle(
        fontSize: 12,
        color: isExpiringSoon ? Colors.orange : Colors.grey,
        fontWeight: isExpiringSoon ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
