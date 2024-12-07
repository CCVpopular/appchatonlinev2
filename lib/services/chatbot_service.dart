import 'dart:convert';
import 'package:appchatonline/config/configapi.dart';
import 'package:http/http.dart' as http;

class ChatBotService {
  final String apiUrl = ConfigAip.GeminiAPI;

  Future<String> sendMessage(String message) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": message}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Lấy phần phản hồi từ bot (thay đổi tùy theo cấu trúc thực tế của API)
        final botResponse = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        return botResponse;
      } else {
        throw Exception('Failed to communicate with Gemini API');
      }
    } catch (e) {
      print('Error: $e');
      return 'Sorry, something went wrong.';
    }
  }
}
