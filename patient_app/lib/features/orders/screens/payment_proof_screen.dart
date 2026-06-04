import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../models/order_model.dart';
import '../../../services/media_service.dart';
import '../../../providers/order_provider.dart';

class PaymentProofScreen extends StatefulWidget {
  // Accept either an Order object or raw map (from MyQuotesScreen)
  final Order? order;
  final Map<String, dynamic>? quoteMap;

  const PaymentProofScreen({super.key, this.order, this.quoteMap})
      : assert(order != null || quoteMap != null);

  String get quoteId => order?.quoteId ?? quoteMap!['id'].toString();
  double get totalAmount =>
      order?.totalAmount ?? (quoteMap!['totalAmount'] as num?)?.toDouble() ?? 0;
  Map<String, dynamic>? get paymentMethodDetails =>
      order?.paymentMethodDetails ??
      (quoteMap?['paymentMethodDetails'] is Map
          ? Map<String, dynamic>.from(quoteMap!['paymentMethodDetails'])
          : null);

  @override
  State<PaymentProofScreen> createState() => _PaymentProofScreenState();
}

class _PaymentProofScreenState extends State<PaymentProofScreen> {
  File? _proofImage;
  bool _isUploading = false;
  bool _isConfirming = false;
  String? _uploadedUrl;

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      _proofImage = File(picked.path);
      _uploadedUrl = null;
    });
  }

  void _showPickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primary),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primary),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_proofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload your payment receipt first')),
      );
      return;
    }

    setState(() => _isUploading = true);

    final uploadResult = await MediaService.uploadImage(
      _proofImage!,
      folder: 'mediexpress/payment-proofs',
    );
    if (!uploadResult.success || uploadResult.url == null) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(uploadResult.message ?? 'Failed to upload image'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return;
    }

    _uploadedUrl = uploadResult.url;
    setState(() => _isUploading = false);

    final provider = context.read<OrderProvider>();
    final saved = await provider.uploadPaymentProof(
      quoteId: widget.quoteId,
      imageUrl: _uploadedUrl!,
    );

    if (saved == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save payment proof. Try again.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return;
    }

    setState(() => _isConfirming = true);
    final confirmed = await provider.confirmQuote(
      quoteId: widget.quoteId,
      paymentMethod: 'manual',
    );
    setState(() => _isConfirming = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(confirmed
              ? 'Payment proof submitted! Waiting for pharmacy verification 🕐'
              : 'Failed to submit order'),
          backgroundColor: confirmed ? AppTheme.success : AppTheme.error,
        ),
      );
      if (confirmed) {
        await provider.fetchOrders();
        if (mounted) {
          // Pop back to order history list
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentMethod = widget.paymentMethodDetails;
    final isBusy = _isUploading || _isConfirming;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Proof')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
                      const SizedBox(width: 8),
                      Text('How to pay',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Transfer the amount using the payment details below\n'
                    '2. Take a screenshot or photo of the receipt\n'
                    '3. Upload it here — pharmacy will verify and confirm your order',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Amount to pay',
                    style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                Text(
                  '${widget.totalAmount.toStringAsFixed(2)} MAD',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Payment method details with copy button
            if (paymentMethod != null) ...[
              Text('Payment Details',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _ProofPaymentCard(paymentMethod: paymentMethod),
              const SizedBox(height: 24),
            ],

            // Upload section
            Text('Upload Receipt',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            GestureDetector(
              onTap: isBusy ? null : _showPickerSheet,
              child: Container(
                width: double.infinity,
                height: _proofImage != null ? null : 160,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _proofImage != null ? AppTheme.primary : AppTheme.divider,
                    width: _proofImage != null ? 2 : 1,
                  ),
                ),
                child: _proofImage != null
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.file(
                              _proofImage!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: isBusy
                                  ? null
                                  : () => setState(() {
                                        _proofImage = null;
                                        _uploadedUrl = null;
                                      }),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: isBusy ? null : _showPickerSheet,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit, color: Colors.white, size: 13),
                                    SizedBox(width: 4),
                                    Text('Change',
                                        style: TextStyle(color: Colors.white, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_upload_outlined,
                              size: 40, color: AppTheme.primary.withValues(alpha: 0.5)),
                          const SizedBox(height: 8),
                          const Text('Tap to upload receipt',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          const Text('Photo or screenshot of bank transfer',
                              style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 32),

            PrimaryButton(
              text: _isUploading
                  ? 'Uploading...'
                  : _isConfirming
                      ? 'Submitting...'
                      : 'Submit Payment Proof',
              icon: Icons.upload_file,
              onPressed: isBusy || _proofImage == null ? null : _submit,
              isLoading: isBusy,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ProofPaymentCard extends StatefulWidget {
  final Map<String, dynamic> paymentMethod;
  const _ProofPaymentCard({required this.paymentMethod});

  @override
  State<_ProofPaymentCard> createState() => _ProofPaymentCardState();
}

class _ProofPaymentCardState extends State<_ProofPaymentCard> {
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
    final name = widget.paymentMethod['name']?.toString() ?? '';
    final details = widget.paymentMethod['details']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.payment, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(details,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
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
