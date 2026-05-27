import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';
import 'pending_approval_screen.dart';
import 'rejected_screen.dart';

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
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final isLoggedIn = await AuthService.isLoggedIn();
    if (!isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final user = await AuthService.getCurrentUser();
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // For pharmacy role, check approval status
    if (user.role == 'pharmacy') {
      try {
        final res = await ApiService.get('/pharmacy/approval-status');
        if (!mounted) return;
        if (res.success) {
          final status = res.data?['approvalStatus'];
          final note = res.data?['adminNote'] ?? '';
          if (status == 'approved') {
            Navigator.pushReplacementNamed(context, '/home');
          } else if (status == 'rejected') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => RejectedScreen(adminNote: note)),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
            );
          }
          return;
        }
      } catch (_) {}
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
      );
      return;
    }

    Navigator.pushReplacementNamed(context, '/home');
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
              'Ordo Pharmacy Store',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
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
