import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../localization/app_localizations.dart';
import '../../providers/language_provider.dart';

/// A compact language switcher (e.g. "EN ▾") that opens a dropdown letting the
/// user pick the app language. Drop it into any screen — it reads/writes the
/// shared [LanguageProvider], so the choice persists and updates the whole app.
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  static String _shortLabel(String code) {
    switch (code) {
      case 'fr':
        return 'FR';
      case 'ar':
        return 'AR';
      default:
        return 'EN';
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = context.watch<LanguageProvider>().locale.languageCode;
    final l10n = AppLocalizations.of(context)!;

    return PopupMenuButton<String>(
      tooltip: l10n.translate('language'),
      onSelected: (code) => context.read<LanguageProvider>().setLanguage(code),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      itemBuilder: (context) => [
        _buildItem('en', l10n.translate('english'), current),
        _buildItem('fr', l10n.translate('french'), current),
        _buildItem('ar', l10n.translate('arabic'), current),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.divider),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, size: 18, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text(
              _shortLabel(current),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 20, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildItem(String code, String name, String current) {
    return PopupMenuItem<String>(
      value: code,
      child: Row(
        children: [
          Expanded(child: Text(name)),
          if (code == current)
            const Icon(Icons.check, size: 18, color: AppTheme.primary),
        ],
      ),
    );
  }
}
