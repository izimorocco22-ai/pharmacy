import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../core/localization/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('profile')),
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
              title: l10n.translate('edit_profile'),
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
              icon: Icons.language,
              title: l10n.translate('language'),
              onTap: () => _showLanguageDialog(context),
            ),
            _buildMenuItem(
              context,
              icon: Icons.location_on,
              title: l10n.translate('saved_addresses'),
              onTap: () {},
            ),
            _buildMenuItem(
              context,
              icon: Icons.payment,
              title: l10n.translate('payment_methods'),
              onTap: () {},
            ),
            _buildMenuItem(
              context,
              icon: Icons.notifications,
              title: l10n.translate('notifications'),
              onTap: () {},
            ),
            _buildMenuItem(
              context,
              icon: Icons.help,
              title: l10n.translate('help_support'),
              onTap: () {},
            ),
            _buildMenuItem(
              context,
              icon: Icons.info,
              title: l10n.translate('about'),
              onTap: () {},
            ),
            const SizedBox(height: AppTheme.spacing16),
            _buildLogoutButton(context),
            const SizedBox(height: AppTheme.spacing8),
            _buildDeleteAccountButton(context),
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

  void _showLanguageDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageProvider = context.read<LanguageProvider>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('select_language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.translate('english')),
              onTap: () {
                languageProvider.setLanguage('en');
                Navigator.pop(context);
              },
              trailing: languageProvider.locale.languageCode == 'en'
                  ? const Icon(Icons.check, color: AppTheme.primary)
                  : null,
            ),
            ListTile(
              title: Text(l10n.translate('french')),
              onTap: () {
                languageProvider.setLanguage('fr');
                Navigator.pop(context);
              },
              trailing: languageProvider.locale.languageCode == 'fr'
                  ? const Icon(Icons.check, color: AppTheme.primary)
                  : null,
            ),
            ListTile(
              title: Text(l10n.translate('arabic')),
              onTap: () {
                languageProvider.setLanguage('ar');
                Navigator.pop(context);
              },
              trailing: languageProvider.locale.languageCode == 'ar'
                  ? const Icon(Icons.check, color: AppTheme.primary)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                l10n.translate('logout'),
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
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('logout')),
        content: Text(l10n.translate('logout_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('cancel')),
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
            child: Text(l10n.translate('logout'), style: const TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteAccountButton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      child: InkWell(
        onTap: () => _showDeleteAccountDialog(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.delete_forever, color: AppTheme.error),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                l10n.translate('delete_account'),
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

  void _showDeleteAccountDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.translate('delete_account')),
        content: Text(l10n.translate('delete_account_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.translate('cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              // Show a blocking loader while deleting
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );
              final ok = await context.read<AuthProvider>().deleteAccount();
              if (!context.mounted) return;
              Navigator.pop(context); // dismiss loader
              if (ok) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.translate('account_deleted'))),
                );
              } else {
                final error = context.read<AuthProvider>().error;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error ?? l10n.translate('delete_account_failed')),
                    backgroundColor: AppTheme.error,
                  ),
                );
              }
            },
            child: Text(
              l10n.translate('delete'),
              style: const TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
