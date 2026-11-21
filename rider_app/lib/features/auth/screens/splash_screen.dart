import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../services/api_service.dart';
import '../../../services/active_delivery_store.dart';
import 'pending_approval_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await context.read<AuthProvider>().checkAuth();

    if (!mounted) return;
    final isAuthenticated = context.read<AuthProvider>().isAuthenticated;

    if (!isAuthenticated) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // Check if rider is approved
    final res = await ApiService.get('/rider/approval-status');
    if (!mounted) return;

    if (res.success) {
      final status = res.data?['approvalStatus'];
      final note = res.data?['adminNote'] ?? '';
      if (status == 'approved') {
        await _goHomeOrResumeDelivery();
      } else if (status == 'rejected') {
        Navigator.pushReplacementNamed(context, '/rejected', arguments: note);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
        );
      }
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  /// If the rider has a delivery in progress (persisted locally) and it is
  /// still active on the backend, resume straight into the navigation screen.
  /// Otherwise go to home. This stops an in-progress delivery from vanishing
  /// when the app is closed and reopened.
  Future<void> _goHomeOrResumeDelivery() async {
    final saved = await ActiveDeliveryStore.loadDelivery();
    final orderId = saved?['orderId']?.toString();

    if (saved != null && orderId != null && orderId.isNotEmpty) {
      final stillActive = await _isDeliveryStillActive(orderId);
      if (!mounted) return;
      if (stillActive) {
        final nav = Navigator.of(context);
        nav.pushReplacementNamed('/home');
        nav.pushNamed('/navigation', arguments: saved);
        return;
      }
      // Delivered/cancelled while away — drop the stale record.
      await ActiveDeliveryStore.clear();
    }

    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  /// Confirms the saved delivery is still assigned/picked_up/in_transit on the
  /// backend. On a network error we keep the delivery (return true) so a
  /// transient failure never loses an active job.
  Future<bool> _isDeliveryStillActive(String orderId) async {
    final res = await ApiService.get('/rider/orders');
    if (!res.success || res.data == null) return true;
    final orders = (res.data['orders'] as List? ?? []);
    for (final o in orders) {
      final m = Map<String, dynamic>.from(o as Map);
      if (m['id']?.toString() == orderId &&
          const ['assigned', 'picked_up', 'in_transit'].contains(m['status'])) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', width: 120, height: 120),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              'Ordo Rider',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              AppLocalizations.of(context)?.translate('medicine_delivery_tagline') ??
                  'Medicine delivery at doorstep.',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
