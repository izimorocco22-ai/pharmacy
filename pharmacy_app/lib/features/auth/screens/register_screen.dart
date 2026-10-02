import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/input_field.dart';
import '../../../core/widgets/language_selector.dart';
import '../../../core/widgets/phone_number_field.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/api_service.dart';
import 'otp_verification_screen.dart';
import 'map_picker_screen.dart';

class RegisterScreen extends StatefulWidget {
  final Map<String, dynamic>? prefillData;
  const RegisterScreen({super.key, this.prefillData});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pharmacyNameController = TextEditingController();
  final _licenseController = TextEditingController();
  final _addressController = TextEditingController();
  String _completePhone = '';

  double _lat = 0.0;
  double _lng = 0.0;
  bool _locationSelected = false;
  bool _isSendingOtp = false;

  // Registration documents: pharmacy license and identity proof.
  File? _licenseImage;
  File? _idProofImage;

  @override
  void initState() {
    super.initState();
    final d = widget.prefillData;
    if (d != null) {
      _nameController.text = d['fullName'] ?? '';
      // Phone is re-entered via the country-code field on re-registration.
      _pharmacyNameController.text = d['pharmacyName'] ?? '';
      _licenseController.text = d['licenseNumber'] ?? '';
      _addressController.text = d['address'] ?? '';
      if (d['lat'] != null && d['lng'] != null) {
        _lat = d['lat'];
        _lng = d['lng'];
        _locationSelected = true;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _pharmacyNameController.dispose();
    _licenseController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLocation: _locationSelected ? LatLng(_lat, _lng) : null,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _addressController.text = result['address'] as String;
        _lat = result['lat'] as double;
        _lng = result['lng'] as double;
        _locationSelected = true;
      });
    }
  }

  Future<void> _pickDocumentImage(void Function(File) onPicked) async {
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
                final img = await picker.pickImage(
                    source: ImageSource.camera, imageQuality: 80);
                if (img != null) setState(() => onPicked(File(img.path)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primary),
              title: Text(l10n.translate('choose_from_gallery')),
              onTap: () async {
                Navigator.pop(context);
                final img = await picker.pickImage(
                    source: ImageSource.gallery, imageQuality: 80);
                if (img != null) setState(() => onPicked(File(img.path)));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _uploadDocument(File file) async {
    try {
      final ext = file.path.toLowerCase().split('.').last;
      final subtype = ext == 'png' ? 'png' : ext == 'webp' ? 'webp' : 'jpeg';

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConstants.baseUrl}/upload/media'),
      );
      request.fields['type'] = 'image';
      // 'registration' is one of the folders the backend allows without auth.
      request.fields['folder'] = 'registration';
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
    if (_licenseImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l10n.translate('please_upload_license_image')),
            backgroundColor: AppTheme.error),
      );
      return;
    }
    if (_idProofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l10n.translate('please_upload_id_proof')),
            backgroundColor: AppTheme.error),
      );
      return;
    }

    setState(() => _isSendingOtp = true);

    try {
      final response = await ApiService.post(
        '/auth/send-otp',
        {'phone': _completePhone.trim(), 'role': 'pharmacy'},
        includeAuth: false,
      );

      if (!mounted) return;

      if (!response.success) {
        setState(() => _isSendingOtp = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message), backgroundColor: AppTheme.error),
        );
        return;
      }

      // Upload the documents before moving to OTP verification.
      final licenseImageUrl = await _uploadDocument(_licenseImage!);
      final idProofUrl = await _uploadDocument(_idProofImage!);

      setState(() => _isSendingOtp = false);

      if (!mounted) return;

      if (licenseImageUrl == null || idProofUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(l10n.translate('document_upload_failed')),
              backgroundColor: AppTheme.error),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OTPVerificationScreen(
            phone: _completePhone.trim(),
            registrationData: {
              'fullName': _nameController.text.trim(),
              'phone': _completePhone.trim(),
              'password': _passwordController.text,
              'role': 'pharmacy',
              'pharmacyName': _pharmacyNameController.text.trim(),
              'licenseNumber': _licenseController.text.trim(),
              'licenseImageUrl': licenseImageUrl,
              'idProofUrl': idProofUrl,
              'address': _addressController.text.trim(),
              'coordinates': [_lng, _lat],
            },
          ),
        ),
      );
    } catch (e) {
      setState(() => _isSendingOtp = false);
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
        title: Text(l10n.translate('register_pharmacy')),
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
                child: Image.asset('assets/images/logo.png', width: 120, height: 80),
              ),
              const SizedBox(height: AppTheme.spacing8),
              Center(
                child: Text(l10n.translate('create_pharmacy_account'),
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              const SizedBox(height: AppTheme.spacing32),

              // Personal Info
              Text(l10n.translate('personal_info'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textSecondary)),
              const SizedBox(height: AppTheme.spacing12),
              InputField(
                controller: _nameController,
                label: l10n.translate('full_name'),
                prefixIcon: Icons.person,
                validator: (v) => v!.isEmpty ? l10n.translate('required') : null,
              ),
              const SizedBox(height: AppTheme.spacing12),
              PhoneNumberField(
                controller: _phoneController,
                label: l10n.translate('phone_number'),
                hint: '612345678',
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
                prefixIcon: Icons.lock,
                isPassword: true,
                validator: (v) => v!.length < 6 ? l10n.translate('min_6_chars') : null,
              ),
              const SizedBox(height: AppTheme.spacing24),

              // Pharmacy Info
              Text(l10n.translate('pharmacy_info'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textSecondary)),
              const SizedBox(height: AppTheme.spacing12),
              InputField(
                controller: _pharmacyNameController,
                label: l10n.translate('pharmacy_name'),
                prefixIcon: Icons.store,
                validator: (v) => v!.isEmpty ? l10n.translate('required') : null,
              ),
              const SizedBox(height: AppTheme.spacing12),
              InputField(
                controller: _licenseController,
                label: l10n.translate('license_number'),
                prefixIcon: Icons.badge,
                validator: (v) => v!.isEmpty ? l10n.translate('required') : null,
              ),
              const SizedBox(height: AppTheme.spacing12),

              // Address with map picker
              GestureDetector(
                onTap: _openMapPicker,
                child: AbsorbPointer(
                  child: InputField(
                    controller: _addressController,
                    label: l10n.translate('pharmacy_address'),
                    prefixIcon: Icons.location_on,
                    validator: (v) => v!.isEmpty ? l10n.translate('please_select_location') : null,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openMapPicker,
                  icon: Icon(
                    _locationSelected ? Icons.edit_location_alt : Icons.map,
                    color: AppTheme.primary,
                  ),
                  label: Text(
                    _locationSelected ? l10n.translate('change_location_map') : l10n.translate('select_location_map'),
                    style: const TextStyle(color: AppTheme.primary),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _locationSelected ? Colors.green : AppTheme.primary,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (_locationSelected)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${l10n.translate('location_selected')} (${_lat.toStringAsFixed(4)}, ${_lng.toStringAsFixed(4)})',
                        style: const TextStyle(fontSize: 12, color: Colors.green),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: AppTheme.spacing24),

              // Registration documents
              Text(l10n.translate('documents'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textSecondary)),
              const SizedBox(height: AppTheme.spacing12),
              _buildDocumentUpload(
                label: l10n.translate('upload_license_image'),
                file: _licenseImage,
                onTap: () => _pickDocumentImage((f) => _licenseImage = f),
              ),
              const SizedBox(height: AppTheme.spacing12),
              _buildDocumentUpload(
                label: l10n.translate('upload_id_proof'),
                file: _idProofImage,
                onTap: () => _pickDocumentImage((f) => _idProofImage = f),
              ),

              const SizedBox(height: AppTheme.spacing32),

              Consumer<AuthProvider>(
                builder: (context, auth, _) => PrimaryButton(
                  text: l10n.translate('send_otp_continue'),
                  onPressed: _isSendingOtp ? null : _register,
                  isLoading: _isSendingOtp,
                ),
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

  Widget _buildDocumentUpload({
    required String label,
    required File? file,
    required VoidCallback onTap,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: file != null ? 180 : 100,
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: file != null ? AppTheme.primary : AppTheme.divider,
            width: file != null ? 2 : 1,
          ),
        ),
        child: file != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.file(file,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover),
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
                        child: const Icon(Icons.edit,
                            size: 16, color: AppTheme.primary),
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
                  Text(label,
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
}
