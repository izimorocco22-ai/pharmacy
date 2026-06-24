import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/input_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/api_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String phone;
  const ResetPasswordScreen({super.key, required this.phone});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _otpVerified = false;
  int _secondsRemaining = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _secondsRemaining = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        t.cancel();
      }
    });
  }

  Future<void> _resendOtp() async {
    if (_secondsRemaining > 0) return;
    setState(() => _isLoading = true);
    final res = await ApiService.post(
      '/auth/patient/forgot-password',
      {'phone': widget.phone},
      includeAuth: false,
    );
    setState(() => _isLoading = false);
    if (res.success) {
      _startTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP resent to your phone')),
        );
      }
    } else {
      _showError(res.message);
    }
  }

  Future<void> _verifyOtp() async {
    if (!_otpFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final res = await ApiService.post(
      '/auth/verify-otp',
      {
        'phone': widget.phone,
        'otp': _otpController.text.trim(),
      },
      includeAuth: false,
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (res.success) {
      setState(() => _otpVerified = true);
    } else {
      _showError(res.message);
    }
  }

  Future<void> _resetPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final res = await ApiService.post(
      '/auth/patient/reset-password',
      {
        'phone': widget.phone,
        'otp': _otpController.text.trim(),
        'newPassword': _newPasswordController.text,
      },
      includeAuth: false,
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset successfully! Please login.'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      _showError(res.message);
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
      );
    }
  }

  Widget _buildOtpStep() {
    return Form(
      key: _otpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppTheme.spacing32),
          const Icon(
            Icons.phone_android_outlined,
            size: 80,
            color: AppTheme.primary,
          ),
          const SizedBox(height: AppTheme.spacing24),
          Text('Enter Verification Code',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: AppTheme.spacing8),
          Text('We sent a 6-digit code to',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(widget.phone,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppTheme.primary),
              textAlign: TextAlign.center),
          const SizedBox(height: AppTheme.spacing32),
          InputField(
            controller: _otpController,
            label: 'OTP Code',
            hint: 'Enter 6-digit code',
            prefixIcon: const Icon(Icons.pin_outlined),
            keyboardType: TextInputType.number,
            maxLength: 6,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter the OTP';
              if (v.length != 6) return 'OTP must be 6 digits';
              return null;
            },
          ),
          const SizedBox(height: AppTheme.spacing24),
          PrimaryButton(
            text: 'Verify OTP',
            onPressed: _isLoading ? null : _verifyOtp,
            isLoading: _isLoading,
          ),
          const SizedBox(height: AppTheme.spacing16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Didn't receive code? ",
                  style: Theme.of(context).textTheme.bodyMedium),
              TextButton(
                onPressed: _secondsRemaining > 0 ? null : _resendOtp,
                child: Text(_secondsRemaining > 0
                    ? 'Resend in ${_secondsRemaining}s'
                    : 'Resend OTP'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStep() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppTheme.spacing32),
          const Icon(Icons.lock_reset_outlined, size: 80, color: AppTheme.primary),
          const SizedBox(height: AppTheme.spacing24),
          Text('Set New Password',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: AppTheme.spacing8),
          Text('OTP verified! Enter your new password below.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: AppTheme.spacing32),
          PasswordField(
            controller: _newPasswordController,
            label: 'New Password',
            hint: 'Enter new password',
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter a new password';
              if (v.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: AppTheme.spacing16),
          PasswordField(
            controller: _confirmPasswordController,
            label: 'Confirm Password',
            hint: 'Re-enter new password',
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm your password';
              if (v != _newPasswordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: AppTheme.spacing24),
          PrimaryButton(
            text: 'Reset Password',
            onPressed: _isLoading ? null : _resetPassword,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: _otpVerified ? _buildPasswordStep() : _buildOtpStep(),
      ),
    );
  }
}
