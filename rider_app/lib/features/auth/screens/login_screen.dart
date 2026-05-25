import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/input_field.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  bool _sendingOtp = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your phone number')),
      );
      return;
    }

    setState(() => _sendingOtp = true);

    final success = await context.read<AuthProvider>().sendOtp(_phoneController.text.trim());

    setState(() => _sendingOtp = false);

    if (!mounted) return;

    if (success) {
      setState(() => _otpSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP sent successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<AuthProvider>().error ?? 'Failed to send OTP'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final result = await context.read<AuthProvider>().loginWithOtp(
          _phoneController.text.trim(),
          _otpController.text.trim(),
        );

    if (!mounted) return;

    if (result == null || !result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<AuthProvider>().error ?? 'Login failed'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    // Same approval routing as before
    final status = result.approvalStatus ?? 'pending';
    final note = result.adminNote ?? '';

    if (status == 'approved') {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (status == 'rejected') {
      Navigator.pushReplacementNamed(context, '/rejected', arguments: note);
    } else {
      Navigator.pushReplacementNamed(context, '/pending-approval');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacing24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: AppTheme.spacing48),
                Center(
                  child: Image.asset('assets/images/logo.png', width: 120, height: 80),
                ),
                const SizedBox(height: AppTheme.spacing16),
                Text(
                  'Welcome Back',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: AppTheme.spacing8),
                Text(
                  'Login to your rider account',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppTheme.spacing48),
                // Phone + Send OTP button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: InputField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        hint: 'e.g. +212600000000',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your phone number';
                          }
                          if (!value.startsWith('+')) {
                            return 'Include country code (e.g. +212)';
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
                                _otpSent ? 'Resend' : 'Send OTP',
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
                InputField(
                  controller: _otpController,
                  label: 'Enter OTP',
                  hint: 'Enter the OTP sent to your phone',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  keyboardType: TextInputType.number,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter the OTP'
                      : null,
                ),
                const SizedBox(height: AppTheme.spacing32),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, _) => PrimaryButton(
                    text: 'Login',
                    onPressed: authProvider.isLoading ? null : _login,
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
                    child: const Text("Don't have an account? Register"),
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
