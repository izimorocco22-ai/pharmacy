import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/input_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../services/api_service.dart';
import 'pending_approval_screen.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phone;
  final Map<String, dynamic> registrationData;

  const OTPVerificationScreen({
    super.key,
    required this.phone,
    required this.registrationData,
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
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _verifyAndRegister() async {
    final l10n = AppLocalizations.of(context)!;
    if (_otpController.text.trim().length != 6) {
      _showError(l10n.translate('enter_6_digit_otp'));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final verifyRes = await ApiService.post(
        '/auth/verify-otp',
        {'phone': widget.phone, 'otp': _otpController.text.trim()},
        includeAuth: false,
      );
      if (!verifyRes.success) {
        _showError(verifyRes.message);
        setState(() => _isLoading = false);
        return;
      }

      final registerRes = await ApiService.post(
        '/auth/register',
        widget.registrationData,
        includeAuth: false,
      );

      if (registerRes.success && registerRes.data != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', registerRes.data['token']);
        await prefs.setString('user_data', json.encode(registerRes.data['user']));
        if (mounted) _showSuccessDialog();
      } else {
        _showError(registerRes.message);
      }
    } catch (_) {
      _showError(l10n.translate('something_went_wrong'));
    }
    setState(() => _isLoading = false);
  }

  void _showSuccessDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.hourglass_top_rounded, size: 40, color: Colors.orange),
            ),
            const SizedBox(height: 20),
            Text(l10n.translate('registration_submitted'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(l10n.translate('rider_under_review'),
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Icon(Icons.access_time, color: Colors.blue.shade600, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(l10n.translate('approval_time'),
                    style: TextStyle(fontSize: 13, color: Colors.blue.shade700))),
              ]),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
                    (_) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(l10n.translate('ok_got_it')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resendOTP() async {
    final l10n = AppLocalizations.of(context)!;
    if (_secondsRemaining > 0) return;
    setState(() => _isLoading = true);
    final res = await ApiService.post(
      '/auth/send-otp',
      {'phone': widget.phone, 'role': 'rider'},
      includeAuth: false,
    );
    setState(() => _isLoading = false);
    if (res.success) {
      _startTimer();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('otp_resent_success'))),
      );
    } else {
      _showError(res.message);
    }
  }

  void _showError(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('verify_phone'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppTheme.spacing32),
            const Icon(Icons.phone_android_outlined, size: 80, color: AppTheme.primary),
            const SizedBox(height: AppTheme.spacing24),
            Text(l10n.translate('verify_your_phone'),
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: AppTheme.spacing8),
            Text(l10n.translate('sent_code_to'),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(widget.phone,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.primary),
                textAlign: TextAlign.center),
            const SizedBox(height: AppTheme.spacing32),
            InputField(
              controller: _otpController,
              label: l10n.translate('enter_otp'),
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.lock_outline),
            ),
            const SizedBox(height: AppTheme.spacing24),
            PrimaryButton(
              text: l10n.translate('verify_register'),
              onPressed: _isLoading ? null : _verifyAndRegister,
              isLoading: _isLoading,
            ),
            const SizedBox(height: AppTheme.spacing16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(l10n.translate('didnt_receive_code'), style: Theme.of(context).textTheme.bodyMedium),
                TextButton(
                  onPressed: _secondsRemaining > 0 ? null : _resendOTP,
                  child: Text(_secondsRemaining > 0
                      ? '${l10n.translate('resend_in')} ${_secondsRemaining}s'
                      : l10n.translate('resend')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
