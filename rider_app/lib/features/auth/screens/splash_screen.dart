import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';
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
        Navigator.pushReplacementNamed(context, '/home');
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
