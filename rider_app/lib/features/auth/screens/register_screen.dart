import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/input_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/language_selector.dart';
import '../../../core/widgets/phone_number_field.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/api_service.dart';
import 'otp_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  final Map<String, dynamic>? prefill;

  const RegisterScreen({super.key, this.prefill});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _licenseController = TextEditingController();
  String _completePhone = '';

  String _vehicleType = 'bike';
  File? _licenseImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.prefill;
    if (p != null) {
      _nameController.text = p['fullName'] ?? '';
      // Phone is re-entered via the country-code field on re-registration.
      _licenseController.text = p['licenseNumber'] ?? '';
      if (p['vehicleType'] != null) _vehicleType = p['vehicleType'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _pickLicenseImage() async {
    final l10n = AppLocalizations.of(context)!;
    final picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primary),
              title: Text(l10n.translate('take_photo')),
              onTap: () async {
                Navigator.pop(context);
                final img = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                if (img != null) setState(() => _licenseImage = File(img.path));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primary),
              title: Text(l10n.translate('choose_from_gallery')),
              onTap: () async {
                Navigator.pop(context);
                final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                if (img != null) setState(() => _licenseImage = File(img.path));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _uploadLicenseImage() async {
    if (_licenseImage == null) return null;
    try {
      final ext = _licenseImage!.path.toLowerCase().split('.').last;
      final mimeType = ext == 'png' ? 'image/png' : ext == 'webp' ? 'image/webp' : 'image/jpeg';
      final subtype = ext == 'png' ? 'png' : ext == 'webp' ? 'webp' : 'jpeg';

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConstants.baseUrl}/upload/media'),
      );
      request.fields['type'] = 'image';
      request.fields['folder'] = 'rider-licenses';
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        _licenseImage!.path,
        contentType: MediaType('image', subtype),
      ));

      final response = await request.send();
      final body = json.decode(await response.stream.bytesToString());
      if (response.statusCode == 200 && body['success'] == true) {
        return body['data']['url'];
      }
    } catch (_) {}
    return null;
  }

  Future<void> _register() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_licenseImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('please_upload_licence')),
            backgroundColor: AppTheme.error),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Send OTP first
      final otpRes = await ApiService.post(
        '/auth/send-otp',
        {'phone': _completePhone.trim(), 'role': 'rider'},
        includeAuth: false,
      );

      if (!mounted) return;

      if (!otpRes.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(otpRes.message), backgroundColor: AppTheme.error),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Upload licence image
      String? licenseImageUrl;
      if (_licenseImage != null) {
        licenseImageUrl = await _uploadLicenseImage();
      }

      setState(() => _isLoading = false);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OTPVerificationScreen(
            phone: _completePhone.trim(),
            registrationData: {
              'fullName': _nameController.text.trim(),
              'phone': _completePhone.trim(),
              'password': _passwordController.text,
              'role': 'rider',
              'vehicleType': _vehicleType,
              'vehicleNumber': '',
              'licenseNumber': _licenseController.text.trim(),
              'licenseImageUrl': licenseImageUrl ?? '',
            },
          ),
        ),
      );
    } catch (_) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('failed_send_otp')), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('register_as_rider')),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: LanguageSelector()),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Image.asset('assets/images/logo.png', width: 100, height: 70),
              ),
              const SizedBox(height: AppTheme.spacing24),

              // Personal Info
              Text(l10n.translate('personal_info'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppTheme.spacing12),
              InputField(
                controller: _nameController,
                label: l10n.translate('full_name'),
                hint: l10n.translate('enter_name'),
                prefixIcon: const Icon(Icons.person),
                validator: (v) => v!.isEmpty ? l10n.translate('required') : null,
              ),
              const SizedBox(height: AppTheme.spacing12),
              PhoneNumberField(
                controller: _phoneController,
                label: l10n.translate('phone_number'),
                hint: l10n.translate('phone_hint'),
                onChanged: (phone) => _completePhone = phone.completeNumber,
                validator: (phone) {
                  if (phone == null || phone.number.trim().isEmpty) {
                    return l10n.translate('required');
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacing12),
              InputField(
                controller: _passwordController,
                label: l10n.translate('password'),
                hint: l10n.translate('enter_password'),
                prefixIcon: const Icon(Icons.lock),
                isPassword: true,
                validator: (v) => v!.length < 6 ? l10n.translate('min_6_chars') : null,
              ),
              const SizedBox(height: AppTheme.spacing24),

              // Licence Info
              Text(l10n.translate('driving_licence'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppTheme.spacing12),
              InputField(
                controller: _licenseController,
                label: l10n.translate('licence_number'),
                hint: l10n.translate('enter_licence'),
                prefixIcon: const Icon(Icons.badge),
                validator: (v) => v!.isEmpty ? l10n.translate('required') : null,
              ),
              const SizedBox(height: AppTheme.spacing12),

              // Vehicle type
              DropdownButtonFormField<String>(
                value: _vehicleType,
                decoration: InputDecoration(
                  labelText: l10n.translate('vehicle_type'),
                  prefixIcon: const Icon(Icons.two_wheeler),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 'bike', child: Text(l10n.translate('bike'))),
                  DropdownMenuItem(value: 'scooter', child: Text(l10n.translate('scooter'))),
                  DropdownMenuItem(value: 'car', child: Text(l10n.translate('car'))),
                ],
                onChanged: (v) => setState(() => _vehicleType = v!),
              ),
              const SizedBox(height: AppTheme.spacing16),

              // Licence image upload
              GestureDetector(
                onTap: _pickLicenseImage,
                child: Container(
                  width: double.infinity,
                  height: _licenseImage != null ? 180 : 100,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _licenseImage != null ? AppTheme.primary : AppTheme.divider,
                      width: _licenseImage != null ? 2 : 1,
                    ),
                  ),
                  child: _licenseImage != null
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.file(_licenseImage!, width: double.infinity,
                                  height: double.infinity, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 8, right: 8,
                              child: GestureDetector(
                                onTap: _pickLicenseImage,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.white, shape: BoxShape.circle),
                                  child: const Icon(Icons.edit, size: 16, color: AppTheme.primary),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.upload_file, size: 32, color: AppTheme.primary),
                            const SizedBox(height: 8),
                            Text(l10n.translate('upload_licence_image'),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.primary)),
                            Text(l10n.translate('tap_to_upload'),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: AppTheme.spacing32),

              PrimaryButton(
                text: l10n.translate('send_otp_continue'),
                onPressed: _isLoading ? null : _register,
                isLoading: _isLoading,
              ),
              const SizedBox(height: AppTheme.spacing16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.translate('already_have_account_login')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
