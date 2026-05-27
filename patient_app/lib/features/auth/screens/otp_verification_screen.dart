import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/input_field.dart';
import '../../../services/api_service.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phone;
  final Map<String, dynamic> signupData;

  const OTPVerificationScreen({
    super.key,
    required this.phone,
    required this.signupData,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
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
    super.dispose();
  }

  void _startTimer() {
    _secondsRemaining = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.length != 6) {
      _showError('Please enter 6-digit OTP');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.post(
        '/auth/verify-otp',
        {
          'phone': widget.phone,
          'otp': _otpController.text,
        },
        includeAuth: false,
      );

      if (response.success) {
        // OTP verified, proceed with registration
        await _completeRegistration();
      } else {
        _showError(response.message);
      }
    } catch (e) {
      _showError('Verification failed');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _completeRegistration() async {
    try {
      final response = await ApiService.post(
        '/auth/register',
        widget.signupData,
        includeAuth: false,
      );

      if (response.success && mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else {
        _showError(response.message);
      }
    } catch (e) {
      _showError('Registration failed');
    }
  }

  Future<void> _resendOTP() async {
    if (_secondsRemaining > 0) return;

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.post(
        '/auth/send-otp',
        {
          'phone': widget.phone,
          'role': 'patient',
        },
        includeAuth: false,
      );

      if (response.success) {
        _startTimer();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OTP sent successfully')),
          );
        }
      } else {
        _showError(response.message);
      }
    } catch (e) {
      _showError('Failed to resend OTP');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Phone'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.phone_android_outlined,
              size: 80,
              color: AppTheme.primary,
            ),
            const SizedBox(height: AppTheme.spacing24),
            Text(
              'Verify Your Phone Number',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              'We sent a 6-digit code to',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            Text(
              widget.phone,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.primary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing32),
            InputField(
              controller: _otpController,
              label: 'Enter OTP',
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            const SizedBox(height: AppTheme.spacing24),
            ElevatedButton(
              onPressed: _isLoading ? null : _verifyOTP,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verify & Continue'),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Didn't receive code? ",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                TextButton(
                  onPressed: _secondsRemaining > 0 ? null : _resendOTP,
                  child: Text(
                    _secondsRemaining > 0
                        ? 'Resend in ${_secondsRemaining}s'
                        : 'Resend OTP',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
