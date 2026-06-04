import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/prescription_provider.dart';
import 'package:provider/provider.dart';
import '../../../services/api_service.dart';
import 'prescription_detail_screen.dart';

class PrescriptionRequestsScreen extends StatefulWidget {
  const PrescriptionRequestsScreen({super.key});

  @override
  State<PrescriptionRequestsScreen> createState() =>
      _PrescriptionRequestsScreenState();
}

class _PrescriptionRequestsScreenState
    extends State<PrescriptionRequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrescriptionProvider>().fetchPrescriptionRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prescription Requests'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<PrescriptionProvider>().fetchPrescriptionRequests(),
          ),
        ],
      ),
      body: Consumer<PrescriptionProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: AppTheme.error),
                  const SizedBox(height: 16),
                  Text(provider.error!,
                      style: const TextStyle(color: AppTheme.error),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.fetchPrescriptionRequests(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (provider.prescriptions.isEmpty) {
            return _buildEmptyState();
          }
          return RefreshIndicator(
            onRefresh: () => provider.fetchPrescriptionRequests(),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              itemCount: provider.prescriptions.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppTheme.spacing12),
              itemBuilder: (context, index) {
                final request = provider.prescriptions[index];
                return _buildRequestCard(context, request);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined,
              size: 80, color: AppTheme.textSecondary.withOpacity(0.5)),
          const SizedBox(height: AppTheme.spacing16),
          Text('No Requests Yet',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppTheme.spacing8),
          Text('New prescription requests will appear here',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, dynamic request) {
    final imageUrl = request['imageUrl']?.toString() ?? '';
    final assignedAt = request['assignedAt'] != null
        ? DateTime.tryParse(request['assignedAt'].toString()) ?? DateTime.now()
        : (request['createdAt'] != null 
            ? DateTime.tryParse(request['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now());

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PrescriptionDetailScreen(prescription: request),
          ),
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prescription image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusLarge)),
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 180,
                        color: Colors.grey.shade100,
                        child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (_, __, ___) => _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
            ),

            Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Countdown Timer
                  Align(
                    alignment: Alignment.centerRight,
                    child: _CountdownTimer(assignedAt: assignedAt, onTimeout: () {
                      context.read<PrescriptionProvider>().fetchPrescriptionRequests();
                    }),
                  ),

                  const SizedBox(height: AppTheme.spacing12),

                  // Action buttons
                  if (request['status'] != 'accepted') ...[
                    const SizedBox(height: AppTheme.spacing8),
                    Row(
                      children: [
                        // Reject button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showRejectDialog(context, request),
                            icon: const Icon(Icons.cancel_outlined, size: 16),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.error,
                              side: const BorderSide(color: AppTheme.error),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing8),
                        // View/Send Quote button
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PrescriptionDetailScreen(prescription: request),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(
                              request['existingQuote'] != null
                                  ? 'View & Edit Quote'
                                  : 'View & Send Quote',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: AppTheme.success,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('✓ Order Confirmed by Patient'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRejectDialog(BuildContext context, dynamic request) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Prescription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide a reason for rejection. The request will be sent to the next nearest pharmacy.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. Medicine out of stock, closed today...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject & Reassign'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Rejecting...'),
          ]),
        ),
      );
    }

    final res = await ApiService.post('/pharmacy/reject-prescription', {
      'prescriptionId': request['id']?.toString() ?? '',
      'reason': reasonController.text.trim(),
    });

    reasonController.dispose();

    if (context.mounted) {
      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.success
                ? (res.data?['reassigned'] == true
                    ? 'Rejected. Request sent to next pharmacy!'
                    : 'Rejected. No more pharmacies available.')
                : res.message,
          ),
          backgroundColor: res.success ? AppTheme.success : AppTheme.error,
        ),
      );
      if (res.success) {
        context.read<PrescriptionProvider>().fetchPrescriptionRequests();
      }
    }
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 180,
      color: Colors.grey.shade100,
      child: const Center(
        child: Icon(Icons.image_outlined, size: 48, color: Colors.grey),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _CountdownTimer extends StatefulWidget {
  final DateTime assignedAt;
  final VoidCallback onTimeout;

  const _CountdownTimer({required this.assignedAt, required this.onTimeout});

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _startTimer();
  }

  void _calculateRemaining() {
    final now = DateTime.now();
    final expiry = widget.assignedAt.add(const Duration(hours: 1));
    _remaining = expiry.difference(now);
    if (_remaining.isNegative) {
      _remaining = Duration.zero;
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _calculateRemaining();
          if (_remaining.inSeconds <= 0) {
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
    final minutes = _remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    final isExpiringSoon = _remaining.inMinutes < 10;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (isExpiringSoon ? AppTheme.error : AppTheme.warning).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, 
               size: 14, 
               color: isExpiringSoon ? AppTheme.error : AppTheme.warning),
          const SizedBox(width: 4),
          Text(
            '$minutes:$seconds',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isExpiringSoon ? AppTheme.error : AppTheme.warning),
          ),
        ],
      ),
    );
  }
}
