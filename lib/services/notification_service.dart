import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';

import '../config/config.dart';
import '../screens/call_screen.dart';
import '../widgets/incoming_call_dialog.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final String baseUrl = Config.apiBaseUrl;


  Future<void> init(String userId, {BuildContext? context}) async {
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
        _handleIncomingCall(message, context);
      }
    });

    // Handle call notifications when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data['type'] == 'video_call') {
        _handleIncomingCall(message, context);
      }
    });
  }

  void _handleIncomingCall(RemoteMessage message, BuildContext? context) {
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => IncomingCallDialog(
        callerName: message.data['callerName'] ?? 'Unknown',
        onAccept: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CallScreen(
                channelName: message.data['channelName'],
                token: '',
                isOutgoing: false,
                onCallEnded: () {
                  // Handle call ended
                },
              ),
            ),
          );
        },
        onDecline: () {
          Navigator.pop(context);
          _rejectCall(message.data['callerId']);
        },
      ),
    );
  }

  Future<void> _rejectCall(String callerId) async {
    // Implement call rejection logic here
    // You could send a notification back to the caller
    try {
      final url = Uri.parse('${Config.apiBaseUrl}/api/notifications/reject-call');
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'callerId': callerId,
        }),
      );
    } catch (e) {
      print('Error rejecting call: $e');
    }
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
