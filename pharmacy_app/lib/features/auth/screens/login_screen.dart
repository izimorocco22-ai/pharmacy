import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/input_field.dart';
import '../../../core/widgets/language_selector.dart';
import '../../../core/widgets/phone_number_field.dart';
import '../../../core/localization/app_localizations.dart';
import 'register_screen.dart';
import 'pending_approval_screen.dart';
import 'rejected_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  String _completePhone = '';
  bool _otpSent = false;
  bool _sendingOtp = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    final l10n = AppLocalizations.of(context)!;
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('enter_phone'))),
      );
      return;
    }

    setState(() => _sendingOtp = true);

    final success = await context.read<AuthProvider>().sendOtp(_completePhone.trim());

    setState(() => _sendingOtp = false);

    if (!mounted) return;

    if (success) {
      setState(() => _otpSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('otp_sent_success'))),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<AuthProvider>().error ?? l10n.translate('failed_send_otp')),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _handleLogin() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    final result = await context.read<AuthProvider>().loginWithOtp(
          _completePhone.trim(),
          _otpController.text.trim(),
        );

    if (!mounted) return;

    if (result == null || !result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<AuthProvider>().error ?? l10n.translate('login_failed')),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    // Route based on approval status
    final status = result.approvalStatus ?? 'pending';
    final note = result.adminNote ?? '';

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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacing24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Align(
                  alignment: Alignment.centerRight,
                  child: LanguageSelector(),
                ),
                const SizedBox(height: AppTheme.spacing16),
                Center(
                  child: Image.asset('assets/images/logo.png', width: 120, height: 80),
                ),
                const SizedBox(height: AppTheme.spacing16),
                Text(
                  l10n.translate('welcome_back'),
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: AppTheme.spacing8),
                Text(
                  l10n.translate('login_to_pharmacy_account'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppTheme.spacing48),
                // Phone + Send OTP button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: PhoneNumberField(
                        controller: _phoneController,
                        label: l10n.translate('phone_number'),
                        hint: l10n.translate('phone_hint'),
                        onChanged: (phone) => _completePhone = phone.completeNumber,
                        validator: (phone) {
                          if (phone == null || phone.number.trim().isEmpty) {
                            return l10n.translate('enter_phone');
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _sendingOtp ? null : _handleSendOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          ),
                        ),
                        child: _sendingOtp
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                _otpSent ? l10n.translate('resend') : l10n.translate('send_otp'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing16),
                // OTP field
                InputField(
                  controller: _otpController,
                  label: l10n.translate('enter_otp'),
                  hint: l10n.translate('otp_hint'),
                  prefixIcon: Icons.lock_outlined,
                  keyboardType: TextInputType.number,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? l10n.translate('please_enter_otp')
                      : null,
                ),
                const SizedBox(height: AppTheme.spacing32),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, _) => PrimaryButton(
                    text: l10n.translate('login'),
                    onPressed: authProvider.isLoading ? null : _handleLogin,
                    isLoading: authProvider.isLoading,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing16),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
                    child: Text(l10n.translate('no_account_register')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
