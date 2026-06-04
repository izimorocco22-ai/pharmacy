import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

class MediaService {
  static Future<MediaUploadResult> uploadImage(File imageFile, {String folder = 'mediexpress/images'}) async {
    return _uploadFile(imageFile, 'image', folder: folder);
  }

  static Future<MediaUploadResult> uploadVideo(File videoFile) async {
    return _uploadFile(videoFile, 'video');
  }

  static Future<MediaUploadResult> _uploadFile(File file, String type, {String? folder}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.tokenKey);

      if (token == null) {
        return MediaUploadResult(
          success: false,
          message: 'Authentication required',
        );
      }

      // Determine MIME type from file extension
      String mimeType;
      final extension = file.path.toLowerCase().split('.').last;
      
      if (type == 'video') {
        if (extension == 'mp4') {
          mimeType = 'video/mp4';
        } else if (extension == 'mov') {
          mimeType = 'video/quicktime';
        } else if (extension == 'avi') {
          mimeType = 'video/x-msvideo';
        } else if (extension == 'webm') {
          mimeType = 'video/webm';
        } else {
          mimeType = 'video/mp4'; // default
        }
      } else {
        if (extension == 'png') {
          mimeType = 'image/png';
        } else if (extension == 'webp') {
          mimeType = 'image/webp';
        } else {
          mimeType = 'image/jpeg'; // default for jpg/jpeg
        }
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConstants.baseUrl}/upload/media'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['type'] = type;
      if (folder != null) request.fields['folder'] = folder;
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: MediaType(
          type == 'video' ? 'video' : 'image',
          extension == 'png' ? 'png' : extension == 'webp' ? 'webp' : extension == 'mp4' ? 'mp4' : extension == 'mov' ? 'quicktime' : extension == 'avi' ? 'x-msvideo' : extension == 'webm' ? 'webm' : 'jpeg',
        ),
      ));

      print('🌐 API Media Upload: ${request.url}');
      print('📤 Request Type: $type');
      print('📤 Request File: ${file.path}');
      print('📎 MIME Type: $mimeType');

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      print('✅ Response Status: ${response.statusCode}');
      print('📥 Response Body: $responseData');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(responseData);
        return MediaUploadResult(
          success: true,
          url: jsonResponse['data']['url'],
          publicId: jsonResponse['data']['publicId'],
          resourceType: jsonResponse['data']['resourceType'],
          format: jsonResponse['data']['format'],
          width: jsonResponse['data']['width'],
          height: jsonResponse['data']['height'],
          bytes: jsonResponse['data']['bytes'],
          message: jsonResponse['message'],
        );
      } else {
        final jsonResponse = json.decode(responseData);
        return MediaUploadResult(
          success: false,
          message: jsonResponse['message'] ?? 'Upload failed',
        );
      }
    } catch (e) {
      print('❌ Upload error: $e');
      return MediaUploadResult(
        success: false,
        message: 'Failed to upload $type',
      );
    }
  }
}

class MediaUploadResult {
  final bool success;
  final String? message;
  final String? url;
  final String? publicId;
  final String? resourceType;
  final String? format;
  final int? width;
  final int? height;
  final int? bytes;

  MediaUploadResult({
    required this.success,
    this.message,
    this.url,
    this.publicId,
    this.resourceType,
    this.format,
    this.width,
    this.height,
    this.bytes,
  });
}