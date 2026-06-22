import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/input_field.dart';
import '../../../core/widgets/language_selector.dart';
import '../../../core/widgets/phone_number_field.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../providers/auth_provider.dart';

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

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.sendOtp(_completePhone.trim());

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
          content: Text(authProvider.error ?? l10n.translate('failed_send_otp')),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _handleLogin() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.loginWithOtp(
      _completePhone.trim(),
      _otpController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? l10n.translate('login_failed')),
          backgroundColor: AppTheme.error,
        ),
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  l10n.translate('login_welcome'),
                  style: Theme.of(context).textTheme.displayMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacing8),
                Text(
                  l10n.translate('login_subtitle'),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacing48),
                // Phone number + Send OTP button
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
                  label: l10n.translate('enter_otp'),
                  hint: l10n.translate('otp_hint'),
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  prefixIcon: const Icon(Icons.lock_outlined),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.translate('please_enter_otp');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spacing24),
                Consumer<AuthProvider>(
                  builder: (context, auth, child) {
                    return PrimaryButton(
                      text: l10n.translate('login'),
                      onPressed: _handleLogin,
                      isLoading: auth.isLoading,
                    );
                  },
                ),
                const SizedBox(height: AppTheme.spacing16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.translate('dont_have_account'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/signup');
                      },
                      child: Text(l10n.translate('sign_up')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
