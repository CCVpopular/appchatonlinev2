import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../config/config.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final String baseUrl = Config.apiBaseUrl;


  Future<void> init(String userId) async {
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    String? token = await _firebaseMessaging.getToken();
    print('FCM Token: $token');

    if (token != null) {
      await _sendTokenToServer(userId, token);
    }

    // Handle incoming call notifications when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['type'] == 'video_call') {
        _handleIncomingCall(message);
      }
    });

    // Handle call notifications when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data['type'] == 'video_call') {
        _handleIncomingCall(message);
      }
    });
  }

  void _handleIncomingCall(RemoteMessage message) {
    // You can implement call handling UI here
    // For example, show a dialog with accept/reject options
    print('Incoming call from: ${message.data['callerName']}');
    print('Channel: ${message.data['channelName']}');
    
    // Here you can navigate to the CallScreen or show an incoming call UI
    // You'll need to implement this based on your app's navigation structure
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
