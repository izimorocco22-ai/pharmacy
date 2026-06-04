import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../core/localization/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('profile'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          children: [
            _buildProfileHeader(context, user),
            const SizedBox(height: AppTheme.spacing24),
            _buildMenuItem(context, icon: Icons.person, title: l10n.translate('edit_profile'),
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                if (mounted) context.read<AuthProvider>().refreshProfile();
              },
            ),
            _buildMenuItem(context, icon: Icons.language, title: l10n.translate('language'),
              onTap: () => _showLanguageDialog(context),
            ),
            _buildMenuItem(context, icon: Icons.account_balance_wallet_outlined, title: l10n.translate('wallet'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
            ),
            _buildMenuItem(context, icon: Icons.history, title: l10n.translate('history'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderHistoryScreen())),
            ),
            _buildMenuItem(context, icon: Icons.privacy_tip_outlined, title: l10n.translate('privacy_policy'),
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
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () => _showLogoutDialog(context),
        icon: const Icon(Icons.logout),
        label: Text(l10n.translate('logout')),
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
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.translate('logout')),
        content: Text(l10n.translate('logout_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.translate('cancel'))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthProvider>().logout();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
            child: Text(l10n.translate('logout'), style: const TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}
