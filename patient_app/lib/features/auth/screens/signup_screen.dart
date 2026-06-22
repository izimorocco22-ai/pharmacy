import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/input_field.dart';
import '../../../core/widgets/language_selector.dart';
import '../../../core/widgets/phone_number_field.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../services/api_service.dart';
import 'otp_verification_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _completePhone = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Send OTP to phone instead of email
      final response = await ApiService.post(
        '/auth/send-otp',
        {
          'phone': _completePhone.trim(),
          'role': 'patient',
        },
        includeAuth: false,
      );

      setState(() => _isLoading = false);

      if (!mounted) return;

      if (response.success) {
        // Navigate to OTP verification screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPVerificationScreen(
              phone: _completePhone.trim(),
              signupData: {
                'fullName': _fullNameController.text.trim(),
                'phone': _completePhone.trim(),
                'password': _passwordController.text,
                'role': 'patient',
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message)),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.translate('failed_send_otp'))),
        );
      }
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
                  l10n.translate('create_account'),
                  style: Theme.of(context).textTheme.displayMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacing8),
                Text(
                  l10n.translate('signup_subtitle'),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacing48),
                InputField(
                  label: l10n.translate('full_name'),
                  hint: l10n.translate('enter_full_name'),
                  controller: _fullNameController,
                  prefixIcon: const Icon(Icons.person_outline),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.translate('enter_name');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spacing16),
                PhoneNumberField(
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
                const SizedBox(height: AppTheme.spacing16),
                PasswordField(
                  label: l10n.translate('password'),
                  hint: l10n.translate('enter_password'),
                  controller: _passwordController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.translate('enter_a_password');
                    }
                    if (value.length < 6) {
                      return l10n.translate('password_min');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spacing16),
                PasswordField(
                  label: l10n.translate('confirm_password'),
                  hint: l10n.translate('reenter_password'),
                  controller: _confirmPasswordController,
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return l10n.translate('passwords_no_match');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spacing32),
                PrimaryButton(
                  text: l10n.translate('sign_up'),
                  onPressed: _handleSignup,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: AppTheme.spacing16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.translate('already_have_account'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.translate('login')),
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
