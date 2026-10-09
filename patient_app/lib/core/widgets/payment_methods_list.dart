import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// The pharmacy's payment methods from a quote, one row per method with its
/// own copy button. The quote stores them as lines of "Name: number"; the
/// copy button copies just the number. A line without "Name:" is shown and
/// copied as is (older quotes with free-text details).
class PaymentMethodsList extends StatelessWidget {
  final Map<String, dynamic> paymentMethod;

  const PaymentMethodsList({super.key, required this.paymentMethod});

  @override
  Widget build(BuildContext context) {
    final lines = (paymentMethod['details']?.toString() ?? '')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _PaymentMethodRow(line: lines[i]),
        ],
      ],
    );
  }
}

class _PaymentMethodRow extends StatefulWidget {
  final String line;

  const _PaymentMethodRow({required this.line});

  @override
  State<_PaymentMethodRow> createState() => _PaymentMethodRowState();
}

class _PaymentMethodRowState extends State<_PaymentMethodRow> {
  bool _copied = false;

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sep = widget.line.indexOf(':');
    final name = sep > 0 ? widget.line.substring(0, sep).trim() : '';
    final value = sep > 0 ? widget.line.substring(sep + 1).trim() : widget.line;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet_outlined,
                color: AppTheme.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (name.isNotEmpty)
                  Text(name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: value.isEmpty ? null : () => _copy(value),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _copied
                    ? AppTheme.success.withValues(alpha: 0.1)
                    : AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_copied ? Icons.check : Icons.copy,
                  size: 16,
                  color: _copied ? AppTheme.success : AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
