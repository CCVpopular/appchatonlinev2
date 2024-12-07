import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../config/config.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final String baseUrl = Config.apiBaseUrl;


  Future<void> init(String userId) async {
    // Yêu cầu quyền thông báo
    await _firebaseMessaging.requestPermission();

    // Lấy FCM Token
    String? token = await _firebaseMessaging.getToken();
    print('FCM Token: $token');

    // Gửi token đến server
    if (token != null) {
      await _sendTokenToServer(userId, token);
    }

    // Lắng nghe thông báo khi ứng dụng đang mở
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        print('Notification Title: ${message.notification!.title}');
        print('Notification Body: ${message.notification!.body}');
      }
    });
  }

  Future<void> _sendTokenToServer(String userId, String token) async {
    final url = Uri.parse('$baseUrl/api/users/save-fcm-token');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'fcmToken': token,
        }),
      );

      if (response.statusCode == 200) {
        print('FCM Token updated successfully on server');
      } else {
        print('Failed to update FCM Token: ${response.body}');
      }
    } catch (e) {
      print('Error sending FCM Token to server: $e');
    }
  }
}
