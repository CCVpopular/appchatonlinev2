import 'dart:async';
import 'dart:convert';
import 'package:appchatonline/services/SocketManager.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../config/config.dart';

class ChatService {
  late IO.Socket socket;
  final _messageStreamController = StreamController<Map<String, String>>.broadcast();
  final _recallStreamController = StreamController<String>.broadcast();
  final String userId;
  final String friendId;

  final String baseUrl = Config.apiBaseUrl;

  ChatService(this.userId, this.friendId) {
    socket = SocketManager(Config.apiBaseUrl).getSocket();
    _connectSocket();
  }

  void _connectSocket() {
    // Remove any existing event listeners
    socket.off('receiveMessage');
    socket.off('messageRecalled');
    
    socket.on('receiveMessage', (data) {
      _messageStreamController.add({
        'id': data['_id'], // Use the MongoDB _id from server
        'sender': data['sender'],
        'message': data['message'],
        'isRecalled': 'false',
        'timestamp': DateTime.now().toIso8601String(),
      });
    });

    socket.on('messageRecalled', (data) {
      _recallStreamController.add(data['messageId']);
    });

    // Leave any existing rooms first
    socket.emit('leaveRoom', {'userId': userId, 'friendId': friendId});
    // Join new room
    socket.emit('joinRoom', {'userId': userId, 'friendId': friendId});
  }

  void sendMessage(String message) {
    socket.emit('sendMessage', {
      'sender': userId,
      'receiver': friendId,
      'message': message,
    });
    // Don't add message to stream here - wait for server response
  }

  void recallMessage(String messageId) {
    socket.emit('recallMessage', {
      'messageId': messageId,
      'sender': userId,
      'receiver': friendId,
    });
  }

  Stream<Map<String, String>> get oldMessageStream => _messageStreamController.stream;
  Stream<String> get recallStream => _recallStreamController.stream;

  void dispose() {
    socket.emit('leaveRoom', {'userId': userId, 'friendId': friendId});
    socket.off('receiveMessage');
    socket.off('messageRecalled');
    _messageStreamController.close();
    _recallStreamController.close();
  }

  // Hàm lấy tin nhắn cũ
  Future<List<Map<String, String>>> loadMessages() async {
    final url = Uri.parse('${baseUrl}/api/messages/messages/$userId/$friendId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((msg) {
          return {
            'id': msg['_id'].toString(),
            'sender': msg['sender'].toString(),
            'message': msg['message'].toString(),
            'isRecalled': msg['isRecalled']?.toString() ?? 'false',
            'timestamp': msg['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
          };
        }).toList().cast<Map<String, String>>();
      } else {
        throw Exception('Failed to load messages: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error loading messages: $e');
    }
  }

  // Stream để lắng nghe tin nhắn
  Stream<Map<String, String>> get messageStream => _messageStreamController.stream;

  // // Đóng Stream và Socket
  // void dispose() {
  //   socket.emit('leaveRoom', {
  //     'userId': userId,
  //     'friendId': friendId,
  //   });
  //   socket.disconnect();
  //   _messageStreamController.close();
  // }
}
