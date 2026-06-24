import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/input_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/api_service.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final String phone = _phoneController.text.trim();

    final res = await ApiService.post(
      '/auth/patient/forgot-password',
      {'phone': phone},
      includeAuth: false,
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (res.success) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(
            phone: phone,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppTheme.spacing32),
              const Icon(Icons.lock_reset_outlined, size: 80, color: AppTheme.primary),
              const SizedBox(height: AppTheme.spacing24),
              Text('Reset Password',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: AppTheme.spacing8),
              Text(
                'Enter your phone number and we\'ll send you a verification code.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacing32),
              InputField(
                controller: _phoneController,
                label: 'Phone Number',
                hint: 'Include country code (e.g. +222)',
                prefixIcon: const Icon(Icons.phone_outlined),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter your phone number';
                  if (!v.startsWith('+')) return 'Include country code (e.g. +222)';
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacing24),
              PrimaryButton(
                text: 'Send OTP',
                onPressed: _isLoading ? null : _sendOtp,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
