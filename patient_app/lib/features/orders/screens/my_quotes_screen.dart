import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../providers/order_provider.dart';
import '../../../services/api_service.dart';
import '../../../core/localization/app_localizations.dart';
import 'payment_proof_screen.dart';

class MyQuotesScreen extends StatefulWidget {
  const MyQuotesScreen({super.key});

  @override
  State<MyQuotesScreen> createState() => _MyQuotesScreenState();
}

class _MyQuotesScreenState extends State<MyQuotesScreen> {
  List<dynamic> _quotes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchQuotes();
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

  // ── Confirm flow ──────────────────────────────────────────────────────────

  Future<void> _confirmQuote(dynamic quote) async {
    final totalAmount = (quote['totalAmount'] as num?)?.toDouble() ?? 0;
    final l10n = AppLocalizations.of(context)!;
    final paymentMethodRaw = quote['paymentMethodDetails'];
    final paymentMethod = paymentMethodRaw is Map
        ? Map<String, dynamic>.from(paymentMethodRaw)
        : null;

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
            Text('${l10n.translate('confirm_order_desc')} ${totalAmount.toStringAsFixed(2)} MRO?'),
            if (paymentMethod != null) ...[
              const SizedBox(height: 16),
              _QuotePaymentCard(paymentMethod: paymentMethod),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(_, true),
              icon: const Icon(Icons.payment, size: 18),
              label: Text(l10n.translate('pay_now')),
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
    );

    if (proceed != true || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentProofScreen(quoteMap: Map<String, dynamic>.from(quote)),
      ),
    );
    _fetchQuotes();
  }

  // ── Cancel flow ───────────────────────────────────────────────────────────

  Future<void> _cancelQuote(dynamic quote) async {
    final l10n = AppLocalizations.of(context)!;
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
      if (mounted) Navigator.pop(context);
      if (mounted) {
        _showSuccess(res ? l10n.translate('quote_cancelled_success') : l10n.translate('quote_cancelled_generic'));
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('my_quotes')),
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
                      ElevatedButton(onPressed: _fetchQuotes, child: Text(l10n.translate('retry'))),
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
                          Text(l10n.translate('no_quotes_yet'), style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text(l10n.translate('no_quotes_desc'),
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
                        itemBuilder: (_, i) => _buildQuoteCard(_quotes[i], l10n),
                      ),
                    ),
    );
  }

  Widget _buildQuoteCard(dynamic quote, AppLocalizations l10n) {
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
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.receipt_long, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.translate('quote_received'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      if (expiresAt != null)
                        _CountdownTimer(expiresAt: expiresAt, onTimeout: _fetchQuotes),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${totalAmount.toStringAsFixed(2)} MRO',
                    style: const TextStyle(
                        color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),

            const Divider(height: 20),

            // Medicine items
            ...items.take(2).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
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
                            Text('${item['quantity']} × ${(item['unitPrice'] as num).toStringAsFixed(2)} MRO',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      Text('${(item['totalPrice'] as num).toStringAsFixed(2)} MRO',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )),
            if (items.length > 2)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  '+ ${items.length - 2} ${l10n.translate('more_items')}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w500),
                ),
              ),

            const Divider(height: 16),

            _priceRow(l10n.translate('subtotal'), subtotal),
            if (commissionAmount > 0)
              _priceRow(
                '${l10n.translate('service_fee')} (${commissionRate.toStringAsFixed(0)}%)',
                commissionAmount,
              ),
            _priceRow(l10n.translate('delivery_fee'), deliveryFee),
            const SizedBox(height: 4),
            _priceRow(l10n.translate('total'), totalAmount, isTotal: true),

            const SizedBox(height: 16),

            if (!isExpired)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _cancelQuote(quote),
                      icon: const Icon(Icons.close, size: 18),
                      label: Text(l10n.translate('cancel')),
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
                      label: Text(l10n.translate('pay_now')),
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
          Text('${amount.toStringAsFixed(2)} MRO',
              style: TextStyle(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                  fontSize: isTotal ? 15 : 13,
                  color: isTotal ? AppTheme.primary : AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

// ── Payment method card with copy button ─────────────────────────────────────

class _QuotePaymentCard extends StatefulWidget {
  final Map<String, dynamic> paymentMethod;
  const _QuotePaymentCard({required this.paymentMethod});

  @override
  State<_QuotePaymentCard> createState() => _QuotePaymentCardState();
}

class _QuotePaymentCardState extends State<_QuotePaymentCard> {
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
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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

// ── Countdown timer ───────────────────────────────────────────────────────────

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
    if (_remaining.isNegative) _remaining = Duration.zero;
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
        style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
      );
    }

    final hours = _remaining.inHours;
    final minutes = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    final isExpiringSoon = _remaining.inMinutes < 15;
    final timeStr = hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';

    return Text(
      '${l10n.translate('expires_in')} $timeStr',
      style: TextStyle(
        fontSize: 12,
        color: isExpiringSoon ? Colors.orange : Colors.grey,
        fontWeight: isExpiringSoon ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
