import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../providers/auth_provider.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch fresh profile data from backend on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refreshProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          children: [
            _buildProfileHeader(context, user),
            const SizedBox(height: AppTheme.spacing24),
            _buildMenuItem(
              context,
              icon: Icons.person,
              title: 'Edit Profile',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
                // Refresh profile after returning from edit
                if (mounted) {
                  context.read<AuthProvider>().refreshProfile();
                }
              },
            ),
            _buildMenuItem(
              context,
              icon: Icons.location_on,
              title: 'Saved Addresses',
              onTap: () {},
            ),
            _buildMenuItem(
              context,
              icon: Icons.payment,
              title: 'Payment Methods',
              onTap: () {},
            ),
            _buildMenuItem(
              context,
              icon: Icons.notifications,
              title: 'Notifications',
              onTap: () {},
            ),
            _buildMenuItem(
              context,
              icon: Icons.help,
              title: 'Help & Support',
              onTap: () {},
            ),
            _buildMenuItem(
              context,
              icon: Icons.info,
              title: 'About',
              onTap: () {},
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
        final base64String = profileImage.split(',')[1];
        imageProvider = MemoryImage(base64Decode(base64String));
      } else if (profileImage.startsWith('http')) {
        imageProvider = NetworkImage(profileImage);
      }
    }
    
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
              backgroundImage: imageProvider,
              child: imageProvider == null
                  ? Text(
                      user?.fullName?.substring(0, 1).toUpperCase() ?? 'U',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: AppTheme.primary,
                          ),
                    )
                  : null,
            ),
            const SizedBox(width: AppTheme.spacing16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.fullName ?? 'User',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppTheme.spacing4),
                  Text(
                    user?.phone ?? '',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
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
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return AppCard(
      child: InkWell(
        onTap: () => _showLogoutDialog(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout, color: AppTheme.error),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                'Logout',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.error,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              }
            },
            child: const Text('Logout', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}
