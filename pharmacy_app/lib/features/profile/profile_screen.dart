import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/input_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../core/localization/app_localizations.dart';
import 'wallet_screen.dart';
import 'pharmacy_info_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('profile')), automaticallyImplyLeading: false),
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
              l10n.translate('edit_profile'),
              () => _showEditProfile(context, user),
            ),
            _buildMenuItem(
              context,
              Icons.language,
              l10n.translate('language'),
              () => _showLanguageDialog(context),
            ),
            _buildMenuItem(
              context,
              Icons.account_balance_wallet_outlined,
              l10n.translate('wallet'),
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmacyWalletScreen())),
            ),
            _buildMenuItem(
              context,
              Icons.store,
              l10n.translate('pharmacy_info'),
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmacyInfoScreen())),
            ),
            _buildMenuItem(
              context,
              Icons.lock,
              l10n.translate('change_password'),
              () => _showChangePassword(context),
            ),
            _buildMenuItem(context, Icons.help, l10n.translate('help_support'), () {
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
                      Text(l10n.translate('logout'),
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
    final l10n = AppLocalizations.of(context)!;

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
            Text(l10n.translate('edit_profile'),
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            InputField(
                controller: nameCtrl,
                label: l10n.translate('full_name'),
                prefixIcon: Icons.person),
            const SizedBox(height: 12),
            InputField(
                controller: phoneCtrl,
                label: l10n.translate('phone'),
                prefixIcon: Icons.phone,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 20),
            PrimaryButton(
              text: l10n.translate('save_changes'),
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
    final l10n = AppLocalizations.of(context)!;

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
            Text(l10n.translate('change_password'),
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            InputField(
                controller: currentCtrl,
                label: l10n.translate('current_password'),
                prefixIcon: Icons.lock,
                isPassword: true),
            const SizedBox(height: 12),
            InputField(
                controller: newCtrl,
                label: l10n.translate('new_password'),
                prefixIcon: Icons.lock_outline,
                isPassword: true),
            const SizedBox(height: 20),
            PrimaryButton(
              text: l10n.translate('update_password'),
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
