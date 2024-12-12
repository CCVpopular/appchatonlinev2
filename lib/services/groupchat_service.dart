import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/config.dart';
import 'SocketManager.dart';

class GroupChatService {
  final String groupId;
  late IO.Socket socket;
  final _messagesgroupStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final String baseUrl = Config.apiBaseUrl;
  List<Map<String, dynamic>> _currentMessages = [];
  final _recallStreamController = StreamController<String>.broadcast();

  GroupChatService(this.groupId) {
    _connectSocket();
    _loadMessages();
  }

  // Kết nối socket
  void _connectSocket() {
    socket = SocketManager(baseUrl).getSocket();

    print('Connected to chat group');

    // Lắng nghe tin nhắn mới
    socket.on('receiveGroupMessage', (data) {
      final newMessage = {
        'sender': data['senderName'],
        'message': data['message'],
        'timestamp': data['timestamp'],
        'senderId': data['sender'], // Add sender ID for notification handling
        'type': data['type'] ?? 'text', // Add type field
      };
      _currentMessages.add(newMessage);
      if (!_messagesgroupStreamController.isClosed) {
        _messagesgroupStreamController.add(_currentMessages);
      }
    });
    socket.emit('joinGroup', {'groupId': groupId});

    socket.on('groupMessageRecalled', (data) {
      _recallStreamController.add(data['messageId']);
    });
  }

  // Tải tin nhắn từ server
  Future<void> _loadMessages() async {
    final url = Uri.parse('$baseUrl/api/groups/group-messages/$groupId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _currentMessages = data.map((msg) {
          return {
            'id': msg['_id'],
            'sender': msg['sender']['username'],
            'message': msg['message'],
            'timestamp': msg['timestamp'],
            'senderId': msg['sender']['_id'],
            'isRecalled': msg['isRecalled'] ?? false,
            'type': msg['type'] ?? 'text', // Add type field
          };
        }).toList();

        if (!_messagesgroupStreamController.isClosed) {
          _messagesgroupStreamController.add(_currentMessages);
        }
      } else {
        throw Exception('Failed to load messages');
      }
    } catch (e) {
      print('Error loading messages: $e');
    }
  }

  // Gửi tin nhắn
  void sendMessage(String sender, String message) {
    socket.emit('sendGroupMessage', {
      'groupId': groupId,
      'sender': sender,
      'message': message,
    });
  }

  Future<void> sendImage(String sender, File imageFile, {Function(double)? onProgress}) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Emit temporary message to show loading state
      _messagesgroupStreamController.add([..._currentMessages, {
        'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
        'sender': '',
        'message': 'Uploading image...',
        'timestamp': DateTime.now().toIso8601String(),
        'senderId': sender,
        'type': 'loading',
        'isTemporary': true,
      }]);

      if (onProgress != null) onProgress(0.5); // Show 50% progress

      socket.emit('sendGroupImage', {
        'groupId': groupId,
        'sender': sender,
        'imageData': base64Image,
        'fileName': fileName,
      });

      if (onProgress != null) onProgress(1.0); // Show 100% progress
    } catch (e) {
      print('Error sending image: $e');
      rethrow;
    }
  }

  Future<void> sendFile(String sender, File file, String fileName, String mimeType, {Function(double)? onProgress}) async {
    try {
      // Emit temporary message to show loading state
      _messagesgroupStreamController.add([..._currentMessages, {
        'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
        'sender': '',
        'message': 'Uploading $fileName...',
        'timestamp': DateTime.now().toIso8601String(),
        'senderId': sender,
        'type': 'loading',
        'isTemporary': true,
      }]);

      final bytes = await file.readAsBytes();
      final base64File = base64Encode(bytes);

      if (onProgress != null) onProgress(0.5); // Show 50% progress

      socket.emit('sendGroupFile', {
        'groupId': groupId,
        'sender': sender,
        'fileData': base64File,
        'fileName': fileName,
        'fileType': mimeType,
      });

      if (onProgress != null) onProgress(1.0); // Show 100% progress
    } catch (e) {
      print('Error sending file: $e');
      rethrow;
    }
  }

  void recallMessage(String messageId) {
    socket.emit('recallGroupMessage', {
      'messageId': messageId,
      'groupId': groupId,
    });
  }

  // Stream để lắng nghe tin nhắn
  Stream<List<Map<String, dynamic>>> get messagesgruopStream =>
      _messagesgroupStreamController.stream;

  Stream<String> get recallStream => _recallStreamController.stream;

  // Đóng socket và Stream
  void dispose() {
    socket.emit('leaveGroup', {'groupId': groupId});
    socket.off('receiveGroupMessage');
    socket.disconnect();
    if (!_messagesgroupStreamController.isClosed) {
      _messagesgroupStreamController.close();
    }
    _recallStreamController.close();
  }
}
