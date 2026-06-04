import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../models/order_model.dart';
import '../../../services/media_service.dart';
import '../../../providers/order_provider.dart';

class PaymentProofScreen extends StatefulWidget {
  final Order order;

  const PaymentProofScreen({super.key, required this.order});

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

    // Upload image
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

    // Save proof URL to quote
    final provider = context.read<OrderProvider>();
    final saved = await provider.uploadPaymentProof(
      quoteId: widget.order.quoteId!,
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

    // Confirm the order
    setState(() => _isConfirming = true);
    final confirmed = await provider.confirmQuote(
      quoteId: widget.order.quoteId!,
      paymentMethod: 'manual',
    );
    setState(() => _isConfirming = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(confirmed
              ? 'Order confirmed! Payment proof submitted 🎉'
              : 'Failed to confirm order'),
          backgroundColor: confirmed ? AppTheme.success : AppTheme.error,
        ),
      );
      if (confirmed) {
        await provider.fetchOrders();
        if (mounted) {
          Navigator.pop(context); // pop proof screen
          Navigator.pop(context); // pop tracking screen
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentMethod = widget.order.paymentMethodDetails;
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
                    '3. Upload it here to confirm your order',
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
                  '${widget.order.totalAmount.toStringAsFixed(2)} MAD',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Payment method details
            if (paymentMethod != null) ...[
              Text('Payment Details',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
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
                          Text(paymentMethod['name']?.toString() ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(paymentMethod['details']?.toString() ?? '',
                              style: const TextStyle(
                                  fontSize: 13, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
                    color: _proofImage != null
                        ? AppTheme.primary
                        : AppTheme.divider,
                    width: _proofImage != null ? 2 : 1,
                    style: _proofImage != null ? BorderStyle.solid : BorderStyle.solid,
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
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: isBusy ? null : _showPickerSheet,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
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
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 12)),
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
                              size: 40,
                              color: AppTheme.primary.withValues(alpha: 0.5)),
                          const SizedBox(height: 8),
                          const Text('Tap to upload receipt',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          const Text('Photo or screenshot of bank transfer',
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.textHint)),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 32),

            PrimaryButton(
              text: _isUploading
                  ? 'Uploading...'
                  : _isConfirming
                      ? 'Confirming Order...'
                      : 'Confirm Order',
              icon: Icons.check_circle_outline,
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
