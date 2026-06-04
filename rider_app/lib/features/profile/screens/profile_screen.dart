import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../providers/auth_provider.dart';
import 'edit_profile_screen.dart';
import 'wallet_screen.dart';
import 'order_history_screen.dart';
import 'privacy_policy_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refreshProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          children: [
            _buildProfileHeader(context, user),
            const SizedBox(height: AppTheme.spacing24),
            _buildMenuItem(context, icon: Icons.person, title: 'Edit Profile',
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                if (mounted) context.read<AuthProvider>().refreshProfile();
              },
            ),
            _buildMenuItem(context, icon: Icons.account_balance_wallet_outlined, title: 'Wallet',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
            ),
            _buildMenuItem(context, icon: Icons.history, title: 'Order History',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderHistoryScreen())),
            ),
            _buildMenuItem(context, icon: Icons.privacy_tip_outlined, title: 'Privacy Policy',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
            ),
            const SizedBox(height: AppTheme.spacing16),
            _buildLogoutButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, dynamic user) {
    ImageProvider? imageProvider;
    final profileImage = user?.profileImage;
    if (profileImage != null && profileImage.isNotEmpty) {
      if (profileImage.startsWith('data:image')) {
        imageProvider = MemoryImage(base64Decode(profileImage.split(',')[1]));
      } else if (profileImage.startsWith('http')) {
        imageProvider = NetworkImage(profileImage);
      }
    }

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spacing20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            backgroundImage: imageProvider,
            child: imageProvider == null
                ? Text(
                    user?.fullName?.isNotEmpty == true ? user!.fullName.substring(0, 1).toUpperCase() : 'R',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(color: AppTheme.primary),
                  )
                : null,
          ),
          const SizedBox(width: AppTheme.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user?.fullName ?? 'Rider', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppTheme.spacing4),
                Text(user?.phone ?? '', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Icon(icon, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: AppTheme.spacing16),
                Expanded(child: Text(title, style: Theme.of(context).textTheme.bodyLarge)),
                const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () => _showLogoutDialog(context),
        icon: const Icon(Icons.logout),
        label: const Text('Logout'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.error,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthProvider>().logout();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('Logout', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}
