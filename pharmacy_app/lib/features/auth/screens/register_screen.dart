import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/input_field.dart';
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
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pharmacyNameController = TextEditingController();
  final _licenseController = TextEditingController();
  final _addressController = TextEditingController();

  double _lat = 0.0;
  double _lng = 0.0;
  bool _locationSelected = false;
  bool _isSendingOtp = false;

  @override
  void initState() {
    super.initState();
    final d = widget.prefillData;
    if (d != null) {
      _nameController.text = d['fullName'] ?? '';
      _emailController.text = d['email'] ?? '';
      _phoneController.text = d['phone'] ?? '';
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
    _emailController.dispose();
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

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSendingOtp = true);

    try {
      final response = await ApiService.post(
        '/auth/send-otp',
        {'phone': _phoneController.text.trim(), 'role': 'pharmacy'},
        includeAuth: false,
      );

      setState(() => _isSendingOtp = false);

      if (!mounted) return;

      if (response.success) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OTPVerificationScreen(
              phone: _phoneController.text.trim(),
              registrationData: {
                'fullName': _nameController.text.trim(),
                'email': _emailController.text.trim(),
                'phone': _phoneController.text.trim(),
                'password': _passwordController.text,
                'role': 'pharmacy',
                'pharmacyName': _pharmacyNameController.text.trim(),
                'licenseNumber': _licenseController.text.trim(),
                'address': _addressController.text.trim(),
                'coordinates': [_lng, _lat],
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message), backgroundColor: AppTheme.error),
        );
      }
    } catch (e) {
      setState(() => _isSendingOtp = false);
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
      appBar: AppBar(title: const Text('Register Pharmacy')),
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
                child: Text('Create Pharmacy Account',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              const SizedBox(height: AppTheme.spacing32),

              // Personal Info
              Text('Personal Info',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textSecondary)),
              const SizedBox(height: AppTheme.spacing12),
              InputField(
                controller: _nameController,
                label: 'Full Name',
                prefixIcon: Icons.person,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: AppTheme.spacing12),
              InputField(
                controller: _emailController,
                label: 'Email',
                prefixIcon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: AppTheme.spacing12),
              InputField(
                controller: _phoneController,
                label: 'Phone Number',
                hint: 'e.g. +212600000000',
                prefixIcon: Icons.phone,
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
                prefixIcon: Icons.lock,
                isPassword: true,
                validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
              ),
              const SizedBox(height: AppTheme.spacing24),

              // Pharmacy Info
              Text('Pharmacy Info',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textSecondary)),
              const SizedBox(height: AppTheme.spacing12),
              InputField(
                controller: _pharmacyNameController,
                label: 'Pharmacy Name',
                prefixIcon: Icons.store,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: AppTheme.spacing12),
              InputField(
                controller: _licenseController,
                label: 'License Number',
                prefixIcon: Icons.badge,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: AppTheme.spacing12),

              // Address with map picker
              GestureDetector(
                onTap: _openMapPicker,
                child: AbsorbPointer(
                  child: InputField(
                    controller: _addressController,
                    label: 'Pharmacy Address',
                    prefixIcon: Icons.location_on,
                    validator: (v) => v!.isEmpty ? 'Please select location on map' : null,
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
                    _locationSelected ? 'Change Location on Map' : 'Select Location on Map',
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
                        'Location selected (${_lat.toStringAsFixed(4)}, ${_lng.toStringAsFixed(4)})',
                        style: const TextStyle(fontSize: 12, color: Colors.green),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: AppTheme.spacing32),

              Consumer<AuthProvider>(
                builder: (context, auth, _) => PrimaryButton(
                  text: 'Send OTP & Continue',
                  onPressed: _isSendingOtp ? null : _register,
                  isLoading: _isSendingOtp,
                ),
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
