import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:io';
import 'dart:convert';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/input_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/profile_service.dart';
import '../../../core/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to pick image')),
        );
      }
    }
  }

  Future<Map<String, String>?> _uploadImage(File imageFile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.tokenKey);

      if (token == null) {
        print('❌ No auth token found');
        throw Exception('Authentication required. Please login again.');
      }

      print('🔍 Starting Cloudinary image upload...');
      print('📁 File path: ${imageFile.path}');
      final fileSize = await imageFile.length();
      print('📏 File size: $fileSize bytes (${(fileSize / 1024).toStringAsFixed(2)} KB)');

      // Check file size before upload (5MB limit)
      if (fileSize > 5 * 1024 * 1024) {
        throw Exception('Image too large. Maximum size is 5MB.');
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConstants.baseUrl}/upload/profile-image'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      
      // Determine MIME type from file extension
      String mimeType = 'image/jpeg'; // default
      final extension = imageFile.path.toLowerCase().split('.').last;
      if (extension == 'png') {
        mimeType = 'image/png';
      } else if (extension == 'jpg' || extension == 'jpeg') {
        mimeType = 'image/jpeg';
      } else if (extension == 'webp') {
        mimeType = 'image/webp';
      }
      
      print('📎 MIME Type: $mimeType');
      
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        contentType: MediaType('image', extension == 'png' ? 'png' : extension == 'webp' ? 'webp' : 'jpeg'),
      ));

      print('🌐 Uploading to: ${request.url}');

      var response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Upload timeout. Please check your internet connection.');
        },
      );
      
      var responseData = await response.stream.bytesToString();

      print('📊 Response Status: ${response.statusCode}');
      print('📥 Response Body: $responseData');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(responseData);
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          print('✅ Cloudinary upload successful!');
          return {
            'imageUrl': jsonResponse['data']['imageUrl'],
            'publicId': jsonResponse['data']['publicId'] ?? '',
          };
        } else {
          throw Exception('Invalid server response: ${jsonResponse['message'] ?? 'Unknown error'}');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode == 400) {
        try {
          final jsonResponse = json.decode(responseData);
          throw Exception(jsonResponse['message'] ?? 'Invalid image format or size.');
        } catch (e) {
          if (responseData.contains('<!DOCTYPE') || responseData.contains('<html')) {
            throw Exception('Server configuration error. The upload endpoint is not properly configured.');
          }
          throw Exception('Bad request: $responseData');
        }
      } else if (response.statusCode == 500) {
        try {
          final jsonResponse = json.decode(responseData);
          throw Exception('Server error: ${jsonResponse['message'] ?? 'Please try again later.'}');
        } catch (e) {
          if (responseData.contains('<!DOCTYPE') || responseData.contains('<html')) {
            throw Exception('Server error. Please check:\n1. Cloudinary credentials are set on Vercel\n2. Backend is properly deployed\n3. All environment variables are configured');
          }
          throw Exception('Server error: $responseData');
        }
      } else if (response.statusCode == 404) {
        throw Exception('Upload endpoint not found. Please ensure the backend is deployed correctly.');
      } else {
        // Check if response is HTML
        if (responseData.contains('<!DOCTYPE') || responseData.contains('<html')) {
          throw Exception('Server returned HTML instead of JSON. Status: ${response.statusCode}. This usually means the API route is not configured correctly on the server.');
        }
        throw Exception('Upload failed (${response.statusCode}): $responseData');
      }
    } catch (e) {
      print('❌ Upload error: $e');
      rethrow; // Propagate the error to show proper message to user
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? profileImageUrl;
      String? profileImagePublicId;

      // Upload image first if selected
      if (_selectedImage != null) {
        print('🔄 Uploading image to Cloudinary...');
        try {
          final uploadResult = await _uploadImage(_selectedImage!);
          if (uploadResult != null) {
            profileImageUrl = uploadResult['imageUrl'];
            profileImagePublicId = uploadResult['publicId'];
            print('✅ Image uploaded successfully: $profileImageUrl');
          }
        } catch (uploadError) {
          print('❌ Image upload failed: $uploadError');
          
          // Show error but allow user to continue without image
          if (mounted) {
            final shouldContinue = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Image Upload Failed'),
                content: Text(
                  'Failed to upload profile image:\n\n${uploadError.toString().replaceAll('Exception: ', '')}\n\nDo you want to save profile without image?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Save Without Image'),
                  ),
                ],
              ),
            );
            
            if (shouldContinue != true) {
              setState(() => _isLoading = false);
              return;
            }
          }
        }
      }

      print('🔄 Updating profile...');
      final result = await ProfileService.updateProfile(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        profileImageUrl: profileImageUrl,
        profileImagePublicId: profileImagePublicId,
      );

      setState(() => _isLoading = false);

      if (!mounted) return;

      if (result.success) {
        final authProvider = context.read<AuthProvider>();
        authProvider.updateUser(result.user!);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        // Check if error message contains HTML
        String errorMessage = result.message ?? 'Failed to update profile';
        if (errorMessage.contains('<!DOCTYPE') || errorMessage.contains('<html')) {
          errorMessage = 'Server error: The API endpoint is not responding correctly. Please check if the backend is deployed properly.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        String errorMessage = e.toString().replaceAll('Exception: ', '');
        
        // Check if it's an HTML response
        if (errorMessage.contains('<!DOCTYPE') || errorMessage.contains('<html')) {
          errorMessage = 'Server error: The API is not responding correctly. Please ensure:\n1. Backend is deployed on Vercel\n2. Cloudinary environment variables are set\n3. All routes are properly configured';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 7),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildProfilePicture(),
              const SizedBox(height: AppTheme.spacing32),
              InputField(
                controller: _nameController,
                label: 'Full Name',
                prefixIcon: const Icon(Icons.person),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Name is required';
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacing16),
              InputField(
                controller: _phoneController,
                label: 'Phone Number',
                prefixIcon: const Icon(Icons.phone),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Phone is required';
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacing32),
              PrimaryButton(
                text: 'Save Changes',
                onPressed: _saveProfile,
                isLoading: _isLoading,
              ),
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
    } else if (user?.profileImage != null) {
      final profileImage = user!.profileImage!;
      if (profileImage.startsWith('data:image')) {
        // Base64 image (legacy support)
        final base64String = profileImage.split(',')[1];
        imageProvider = MemoryImage(base64Decode(base64String));
      } else if (profileImage.startsWith('http')) {
        // Cloudinary URL or any HTTP URL
        imageProvider = NetworkImage(profileImage);
      } else {
        // Relative path (legacy support)
        imageProvider = NetworkImage(
            '${AppConstants.baseUrl.replaceAll('/api', '')}$profileImage');
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
                    user?.fullName?.isNotEmpty == true 
                        ? user!.fullName!.substring(0, 1).toUpperCase()
                        : 'U',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: AppTheme.primary,
                        ),
                  )
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacing8),
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
