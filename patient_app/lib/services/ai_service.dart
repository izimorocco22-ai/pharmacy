import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiService {
  static String? get _apiKey => dotenv.env['OPENAI_API_KEY'];
  static const String _url = 'https://api.openai.com/v1/chat/completions';

  static Future<bool> isPrescription(File imageFile) async {
    final apiKey = _apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      print('OpenAI API Key is missing');
      return true; // Fallback to true if API key is missing to not block users
    }

    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse(_url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': 'Is this image a medical prescription? Answer with only "YES" or "NO".'
                },
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/jpeg;base64,$base64Image'
                  }
                }
              ]
            }
          ],
          'max_tokens': 10,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['choices'][0]['message']['content'].toString().trim().toUpperCase();
        return result.contains('YES');
      } else {
        print('OpenAI API Error: ${response.body}');
        return true; // Fallback to true on API error
      }
    } catch (e) {
      print('AI Service Error: $e');
      return true; // Fallback to true on exception
    }
  }
}
