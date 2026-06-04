import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/auth_service.dart';
import '../../../services/api_service.dart';
import '../../../core/localization/app_localizations.dart';

class RejectedScreen extends StatelessWidget {
  final String adminNote;

  const RejectedScreen({super.key, required this.adminNote});

  Future<void> _tryAgain(BuildContext context) async {
    final user = await AuthService.getCurrentUser();
    Map<String, dynamic>? prefill;
    if (user != null) {
      try {
        final res = await ApiService.get('/rider/profile');
        if (res.success && res.data != null) {
          final r = res.data['rider'] ?? res.data;
          prefill = {
            'fullName': user.fullName,
            'email': user.email,
            'phone': user.phone,
            'licenseNumber': r['licenseNumber'] ?? '',
            'vehicleType': r['vehicleType'] ?? 'bike',
          };
        } else {
          prefill = {
            'fullName': user.fullName,
            'email': user.email,
            'phone': user.phone,
          };
        }
      } catch (_) {
        prefill = {
          'fullName': user.fullName,
          'email': user.email,
          'phone': user.phone,
        };
      }
    }
    await AuthService.logout();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/register', arguments: prefill);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cancel_outlined, size: 52, color: Colors.red),
              ),
              const SizedBox(height: 32),
              Text(
                l10n.translate('application_rejected'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.translate('rider_rejected_desc'),
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600, height: 1.5),
                textAlign: TextAlign.center,
              ),
              if (adminNote.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.red.shade600, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            l10n.translate('admin_note'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        adminNote,
                        style: TextStyle(fontSize: 14, color: Colors.red.shade800, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _tryAgain(context),
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.translate('try_again')),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
