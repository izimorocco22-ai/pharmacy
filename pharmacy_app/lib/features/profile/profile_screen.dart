import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/input_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../providers/auth_provider.dart';
import 'wallet_screen.dart';
import 'pharmacy_info_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          children: [
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppTheme.primary.withOpacity(0.1),
                      child: Text(
                        user?.fullName.isNotEmpty == true
                            ? user!.fullName[0].toUpperCase()
                            : 'P',
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.fullName ?? '',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(user?.phone ?? '',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            _buildMenuItem(
              context,
              Icons.edit,
              'Edit Profile',
              () => _showEditProfile(context, user),
            ),
            _buildMenuItem(
              context,
              Icons.account_balance_wallet_outlined,
              'Wallet',
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmacyWalletScreen())),
            ),
            _buildMenuItem(
              context,
              Icons.store,
              'Pharmacy Info',
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmacyInfoScreen())),
            ),
            _buildMenuItem(
              context,
              Icons.lock,
              'Change Password',
              () => _showChangePassword(context),
            ),
            _buildMenuItem(context, Icons.help, 'Help & Support', () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Contact: support@mediexpress.com')),
              );
            }),
            const SizedBox(height: AppTheme.spacing16),
            AppCard(
              child: InkWell(
                onTap: () async {
                  await context.read<AuthProvider>().logout();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout, color: AppTheme.error),
                      const SizedBox(width: AppTheme.spacing8),
                      Text('Logout',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: AppTheme.error)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
      BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: AppCard(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.primary),
                const SizedBox(width: AppTheme.spacing16),
                Expanded(
                    child: Text(title,
                        style: Theme.of(context).textTheme.bodyLarge)),
                const Icon(Icons.arrow_forward_ios,
                    size: 16, color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditProfile(BuildContext context, dynamic user) {
    final nameCtrl = TextEditingController(text: user?.fullName ?? '');
    final phoneCtrl = TextEditingController(text: user?.phone ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Profile',
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            InputField(
                controller: nameCtrl,
                label: 'Full Name',
                prefixIcon: Icons.person),
            const SizedBox(height: 12),
            InputField(
                controller: phoneCtrl,
                label: 'Phone',
                prefixIcon: Icons.phone,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 20),
            PrimaryButton(
              text: 'Save Changes',
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await context.read<AuthProvider>().updateProfile(
                      fullName: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(ok ? 'Profile updated' : 'Update failed'),
                        backgroundColor: ok ? AppTheme.success : AppTheme.error),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }


  void _showChangePassword(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Change Password',
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            InputField(
                controller: currentCtrl,
                label: 'Current Password',
                prefixIcon: Icons.lock,
                isPassword: true),
            const SizedBox(height: 12),
            InputField(
                controller: newCtrl,
                label: 'New Password',
                prefixIcon: Icons.lock_outline,
                isPassword: true),
            const SizedBox(height: 20),
            PrimaryButton(
              text: 'Update Password',
              onPressed: () async {
                if (newCtrl.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Password must be at least 6 characters')),
                  );
                  return;
                }
                if (currentCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter current password')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                final ok = await context.read<AuthProvider>().changePassword(
                      currentPassword: currentCtrl.text,
                      newPassword: newCtrl.text,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(ok ? 'Password updated' : 'Incorrect current password'),
                        backgroundColor: ok ? AppTheme.success : AppTheme.error),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
