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
  final _licenseController = TextEditingController();
  final _permitController = TextEditingController();
  String _completePhone = '';

  String _vehicleType = 'bike';
  File? _licenseImage;
  // Second legal document authorising the rider to carry deliveries.
  File? _permitImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.prefill;
    if (p != null) {
      _nameController.text = p['fullName'] ?? '';
      // Phone typed on the login screen carries over so the user doesn't
      // have to enter it twice.
      if ((p['phone'] ?? '').toString().isNotEmpty) {
        _phoneController.text = p['phone'];
      }
      if ((p['completePhone'] ?? '').toString().isNotEmpty) {
        _completePhone = p['completePhone'];
      }
      _licenseController.text = p['licenseNumber'] ?? '';
      if (p['vehicleType'] != null) _vehicleType = p['vehicleType'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(void Function(File) onPicked) async {
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
                if (img != null) setState(() => onPicked(File(img.path)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primary),
              title: Text(l10n.translate('choose_from_gallery')),
              onTap: () async {
                Navigator.pop(context);
                final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                if (img != null) setState(() => onPicked(File(img.path)));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _uploadImage(File? file, String folder) async {
    if (file == null) return null;
    try {
      final ext = file.path.toLowerCase().split('.').last;
      final subtype = ext == 'png' ? 'png' : ext == 'webp' ? 'webp' : 'jpeg';

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConstants.baseUrl}/upload/media'),
      );
      request.fields['type'] = 'image';
      request.fields['folder'] = folder;
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
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
      final licenseImageUrl = await _uploadImage(_licenseImage, 'rider-licenses');
      final permitImageUrl = await _uploadImage(_permitImage, 'rider-permits');

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
              'role': 'rider',
              'vehicleType': _vehicleType,
              'vehicleNumber': '',
              'licenseNumber': _licenseController.text.trim(),
              'licenseImageUrl': licenseImageUrl ?? '',
              'permitNumber': _permitController.text.trim(),
              'permitImageUrl': permitImageUrl ?? '',
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

  /// One document upload tile. Used for both the driving licence and the
  /// permit, so the two stay visually identical.
  Widget _buildUploadCard({
    required File? image,
    required String label,
    required VoidCallback onTap,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: image != null ? 180 : 100,
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: image != null ? AppTheme.primary : AppTheme.divider,
            width: image != null ? 2 : 1,
          ),
        ),
        child: image != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.file(image,
                        width: double.infinity, height: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onTap,
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
                  Text('$label (${l10n.translate('optional')})',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppTheme.primary)),
                  Text(l10n.translate('tap_to_upload'),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.textSecondary)),
                ],
              ),
      ),
    );
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
              const SizedBox(height: AppTheme.spacing24),

              // Licence Info
              Text(l10n.translate('driving_licence'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppTheme.spacing12),
              InputField(
                controller: _licenseController,
                label:
                    '${l10n.translate('licence_number')} (${l10n.translate('optional')})',
                hint: l10n.translate('enter_licence'),
                prefixIcon: const Icon(Icons.badge),
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
              _buildUploadCard(
                image: _licenseImage,
                label: l10n.translate('upload_licence_image'),
                onTap: () => _pickImage((f) => _licenseImage = f),
              ),
              const SizedBox(height: AppTheme.spacing16),

              // Second legal document: the permit allowing the rider to
              // carry deliveries. Optional at registration, like the licence —
              // the admin checks it before approving the account.
              TextField(
                controller: _permitController,
                decoration: InputDecoration(
                  labelText:
                      '${l10n.translate('permit_number')} (${l10n.translate('optional')})',
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              _buildUploadCard(
                image: _permitImage,
                label: l10n.translate('upload_permit_image'),
                onTap: () => _pickImage((f) => _permitImage = f),
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
