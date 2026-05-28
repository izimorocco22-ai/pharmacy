import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/input_field.dart';
import '../../../core/widgets/primary_button.dart';
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

  String _vehicleType = 'bike';
  File? _licenseImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.prefill;
    if (p != null) {
      _nameController.text = p['fullName'] ?? '';
      _phoneController.text = p['phone'] ?? '';
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
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                final img = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                if (img != null) setState(() => _licenseImage = File(img.path));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primary),
              title: const Text('Choose from Gallery'),
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
    if (!_formKey.currentState!.validate()) return;
    if (_licenseImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload your driving licence image'),
            backgroundColor: AppTheme.error),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Send OTP first
      final otpRes = await ApiService.post(
        '/auth/send-otp',
        {'phone': _phoneController.text.trim(), 'role': 'rider'},
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
            phone: _phoneController.text.trim(),
            registrationData: {
              'fullName': _nameController.text.trim(),
              'phone': _phoneController.text.trim(),
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
          const SnackBar(content: Text('Failed to send OTP'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register as Rider')),
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
              Text('Personal Info',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppTheme.spacing12),
              InputField(
                controller: _nameController,
                label: 'Full Name',
                hint: 'Enter your full name',
                prefixIcon: const Icon(Icons.person),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: AppTheme.spacing12),
              InputField(
                controller: _phoneController,
                label: 'Phone Number',
                hint: 'e.g. +212600000000',
                prefixIcon: const Icon(Icons.phone),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (!v.startsWith('+')) return 'Include country code (e.g. +212)';
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacing12),
              InputField(
                controller: _passwordController,
                label: 'Password',
                hint: 'Enter your password',
                prefixIcon: const Icon(Icons.lock),
                isPassword: true,
                validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
              ),
              const SizedBox(height: AppTheme.spacing24),

              // Licence Info
              Text('Driving Licence',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppTheme.spacing12),
              InputField(
                controller: _licenseController,
                label: 'Licence Number',
                hint: 'Enter your driving licence number',
                prefixIcon: const Icon(Icons.badge),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: AppTheme.spacing12),

              // Vehicle type
              DropdownButtonFormField<String>(
                value: _vehicleType,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Type',
                  prefixIcon: Icon(Icons.two_wheeler),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'bike', child: Text('Bike')),
                  DropdownMenuItem(value: 'scooter', child: Text('Scooter')),
                  DropdownMenuItem(value: 'car', child: Text('Car')),
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
                            Text('Upload Driving Licence Image',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.primary)),
                            Text('Tap to take photo or choose from gallery',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: AppTheme.spacing32),

              PrimaryButton(
                text: 'Send OTP & Continue',
                onPressed: _isLoading ? null : _register,
                isLoading: _isLoading,
              ),
              const SizedBox(height: AppTheme.spacing16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Already have an account? Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
