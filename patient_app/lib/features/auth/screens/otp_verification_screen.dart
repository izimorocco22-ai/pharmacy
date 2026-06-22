import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/input_field.dart';
import '../../../core/widgets/language_selector.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../providers/auth_provider.dart';
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
    final l10n = AppLocalizations.of(context)!;
    if (_otpController.text.length != 6) {
      _showError(l10n.translate('enter_6_digit_otp'));
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
      _showError(l10n.translate('verification_failed'));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _completeRegistration() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final success = await context.read<AuthProvider>().register(widget.signupData);

      if (success && mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else if (mounted) {
        _showError(context.read<AuthProvider>().error ?? l10n.translate('registration_failed'));
      }
    } catch (e) {
      _showError(l10n.translate('registration_failed'));
    }
  }

  Future<void> _resendOTP() async {
    final l10n = AppLocalizations.of(context)!;
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
            SnackBar(content: Text(l10n.translate('otp_sent_success'))),
          );
        }
      } else {
        _showError(response.message);
      }
    } catch (e) {
      _showError(l10n.translate('failed_resend_otp'));
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('verify_phone')),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: LanguageSelector()),
          ),
        ],
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
              l10n.translate('verify_your_phone'),
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              l10n.translate('sent_code_to'),
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
              label: l10n.translate('enter_otp'),
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
                  : Text(l10n.translate('verify_continue')),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.translate('didnt_receive_code'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                TextButton(
                  onPressed: _secondsRemaining > 0 ? null : _resendOTP,
                  child: Text(
                    _secondsRemaining > 0
                        ? '${l10n.translate('resend_in')} ${_secondsRemaining}s'
                        : l10n.translate('resend_otp'),
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
