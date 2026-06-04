import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/input_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/profile_service.dart';
import '../../../core/constants/app_constants.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  bool _isLoading = false;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 80);
    if (image != null) setState(() => _selectedImage = File(image.path));
  }

  Future<Map<String, String>?> _uploadImage(File imageFile) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    if (token == null) throw Exception('Authentication required. Please login again.');

    final ext = imageFile.path.toLowerCase().split('.').last;
    final subtype = ext == 'png' ? 'png' : ext == 'webp' ? 'webp' : 'jpeg';

    final request = http.MultipartRequest('POST', Uri.parse('${AppConstants.baseUrl}/upload/profile-image'));
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path, contentType: MediaType('image', subtype)));

    final response = await request.send().timeout(const Duration(seconds: 30));
    final body = json.decode(await response.stream.bytesToString());

    if (response.statusCode == 200 && body['success'] == true) {
      return {'imageUrl': body['data']['imageUrl'], 'publicId': body['data']['publicId'] ?? ''};
    }
    throw Exception(body['message'] ?? 'Upload failed');
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String? profileImageUrl;
      String? profileImagePublicId;

      if (_selectedImage != null) {
        try {
          final result = await _uploadImage(_selectedImage!);
          profileImageUrl = result?['imageUrl'];
          profileImagePublicId = result?['publicId'];
        } catch (e) {
          final cont = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Image Upload Failed'),
              content: Text('${e.toString().replaceAll('Exception: ', '')}\n\nSave profile without image?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save Without Image')),
              ],
            ),
          );
          if (cont != true) { setState(() => _isLoading = false); return; }
        }
      }

      final result = await ProfileService.updateProfile(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        profileImageUrl: profileImageUrl,
        profileImagePublicId: profileImagePublicId,
      );

      setState(() => _isLoading = false);
      if (!mounted) return;

      if (result.success) {
        context.read<AuthProvider>().updateUser(result.user!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully'), backgroundColor: AppTheme.success),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Failed to update profile'), backgroundColor: AppTheme.error),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildProfilePicture(),
              const SizedBox(height: AppTheme.spacing32),
              InputField(
                controller: _nameController,
                label: 'Full Name',
                prefixIcon: const Icon(Icons.person_outline),
                validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: AppTheme.spacing16),
              InputField(
                controller: _phoneController,
                label: 'Phone Number',
                prefixIcon: const Icon(Icons.phone_outlined),
                keyboardType: TextInputType.phone,
                validator: (v) => v == null || v.isEmpty ? 'Phone is required' : null,
              ),
              const SizedBox(height: AppTheme.spacing32),
              PrimaryButton(text: 'Save Changes', onPressed: _saveProfile, isLoading: _isLoading),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePicture() {
    final user = context.watch<AuthProvider>().user;
    ImageProvider? imageProvider;

    if (_selectedImage != null) {
      imageProvider = FileImage(_selectedImage!);
    } else if (user?.profileImage != null && user!.profileImage!.isNotEmpty) {
      final img = user.profileImage!;
      if (img.startsWith('data:image')) {
        imageProvider = MemoryImage(base64Decode(img.split(',')[1]));
      } else if (img.startsWith('http')) {
        imageProvider = NetworkImage(img);
      }
    }

    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            backgroundImage: imageProvider,
            child: imageProvider == null
                ? Text(
                    user?.fullName?.isNotEmpty == true ? user!.fullName.substring(0, 1).toUpperCase() : 'R',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(color: AppTheme.primary),
                  )
                : null,
          ),
          Positioned(
            bottom: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacing8),
              decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
