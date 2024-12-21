import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:appchatonline/services/SocketManager.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../config/config.dart';

class ChatService {
  late IO.Socket socket;
  final _messageStreamController = StreamController<Map<String, String>>.broadcast();
  final _recallStreamController = StreamController<String>.broadcast();
  final _latestMessageStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final String userId;
  final String friendId;

  final String baseUrl = Config.apiBaseUrl;

  ChatService(this.userId, this.friendId) {
    socket = SocketManager(Config.apiBaseUrl).getSocket();
    _connectSocket();
    _listenForLatestMessages();
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
        'type': data['type'] ?? 'text',
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

  void _listenForLatestMessages() {
    socket.on('latestMessage', (data) {
      _latestMessageStreamController.add(data);
    });
  }

  void sendMessage(String message) {
    socket.emit('sendMessage', {
      'sender': userId,
      'receiver': friendId,
      'message': message,
    });
    // Don't add message to stream here - wait for server response
  }

  void _emitTemporaryMessage(String fileName, String type) {
    _messageStreamController.add({
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'sender': userId,
      'message': 'Uploading $fileName...',
      'type': type,
      'isTemporary': 'true',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> sendImage(File imageFile, {Function(double)? onProgress}) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

      _emitTemporaryMessage(fileName, 'image');

      socket.emit('sendImage', {
        'sender': userId,
        'receiver': friendId,
        'imageData': base64Image,
        'fileName': fileName,
      });
    } catch (e) {
      print('Error sending image: $e');
      rethrow;
    }
  }

  Future<void> sendFile(File file, String fileName, String mimeType, {Function(double)? onProgress}) async {
    try {
      if (!file.existsSync()) {
        throw Exception('File does not exist');
      }

      final bytes = await file.readAsBytes();
      if (bytes.length > 500 * 1024 * 1024) { // 500MB limit
        throw Exception('File size exceeds 500MB limit');
      }

      _emitTemporaryMessage(fileName, 'file');
      final base64File = base64Encode(bytes);

      socket.emitWithAck('sendFile', {
        'sender': userId,
        'receiver': friendId,
        'fileData': base64File,
        'fileName': fileName,
        'fileType': mimeType,
      }, ack: (data) {
        // Handle acknowledgment here
      });

      // Add a longer timeout for larger files
      Future.delayed(const Duration(minutes: 10), () {
        throw Exception('Upload timeout');
      });
    } catch (e) {
      print('Error sending file: $e');
      rethrow;
    }
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
  Stream<Map<String, dynamic>> get latestMessageStream => _latestMessageStreamController.stream;

  void dispose() {
    socket.emit('leaveRoom', {'userId': userId, 'friendId': friendId});
    socket.off('receiveMessage');
    socket.off('messageRecalled');
    _messageStreamController.close();
    _recallStreamController.close();
    _latestMessageStreamController.close();
  }

  // Hàm lấy tin nhắn cũ
  Future<Map<String, dynamic>> loadMessages({int page = 1, int limit = 20}) async {
    final url = Uri.parse('${baseUrl}/api/messages/messages/$userId/$friendId?page=$page&limit=$limit');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> messagesList = data['messages'];
        
        return {
          'messages': messagesList.map((msg) {
            return {
              'id': msg['_id'].toString(),
              'sender': msg['sender'].toString(),
              'message': msg['message'].toString(),
              'type': msg['type']?.toString() ?? 'text',
              'isRecalled': msg['isRecalled']?.toString() ?? 'false',
              'timestamp': msg['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
            };
          }).toList(),
          'hasMore': data['hasMore'],
          'total': data['total'],
        };
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
