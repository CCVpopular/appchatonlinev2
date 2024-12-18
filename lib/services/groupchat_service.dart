import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/config.dart';
import 'SocketManager.dart';

class GroupChatService {
  final String groupId;
  late IO.Socket _socket;
  final _messagesgroupStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final String baseUrl = Config.apiBaseUrl;
  List<Map<String, dynamic>> _currentMessages = [];
  final _recallStreamController = StreamController<String>.broadcast();

  GroupChatService(this.groupId) {
    _connectSocket();
    _loadMessages();
  }

  // Make socket accessible
  IO.Socket get socket => _socket;

  // Kết nối socket
  void _connectSocket() {
    _socket = SocketManager(baseUrl).getSocket();

    print('Connected to chat group');

    // Lắng nghe tin nhắn mới
    _socket.on('receiveGroupMessage', (data) {
      final newMessage = {
        '_id': data['_id'], // Use _id for consistency
        'sender': data['senderName'],
        'message': data['message'],
        'timestamp': data['timestamp'],
        'senderId': data['sender'], // Add sender ID for notification handling
        'type': data['type'] ?? 'text', // Add type field
        'isRecalled': false,
      };
      _currentMessages.add(newMessage);
      if (!_messagesgroupStreamController.isClosed) {
        _messagesgroupStreamController.add(_currentMessages);
      }
    });
    _socket.emit('joinGroup', {'groupId': groupId});

    socket.on('groupMessageRecalled', (data) {
      final index = _currentMessages.indexWhere((msg) => 
        (msg['_id'] ?? msg['id']) == data['messageId']);
      if (index != -1) {
        _currentMessages[index]['isRecalled'] = true;
        if (!_messagesgroupStreamController.isClosed) {
          _messagesgroupStreamController.add(_currentMessages);
        }
      }
      _recallStreamController.add(data['messageId']);
    });
  }

  // Tải tin nhắn từ server
  Future<void> _loadMessages() async {
    final url = Uri.parse('$baseUrl/api/groups/group-messages/$groupId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> messages = data['messages']; // Get messages array from response
        _currentMessages = messages.map((msg) {
          return {
            'id': msg['_id'],
            'sender': msg['sender']['username'],
            'message': msg['message'],
            'timestamp': msg['timestamp'],
            'senderId': msg['sender']['_id'],
            'isRecalled': msg['isRecalled'] ?? false,
            'type': msg['type'] ?? 'text',
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

  Future<MessagePage> loadMoreMessages(int page, int limit) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/groups/group-messages/$groupId?page=$page&limit=$limit'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<Map<String, dynamic>> newMessages = (data['messages'] as List)
            .map((msg) => {
                  'id': msg['_id'],
                  'senderId': msg['sender']['_id'],
                  'sender': msg['sender']['username'],
                  'message': msg['message'],
                  'timestamp': msg['timestamp'],
                  'isRecalled': msg['isRecalled'] ?? false,
                  'type': msg['type'] ?? 'text',
                })
            .toList();

        _currentMessages = [...newMessages, ..._currentMessages];
        _messagesgroupStreamController.add(_currentMessages);
        
        return MessagePage(
          messages: newMessages,
          currentPage: data['currentPage'],
          totalPages: data['totalPages'],
        );
      }
      throw Exception('Failed to load messages');
    } catch (e) {
      print('Error loading more messages: $e');
      rethrow;
    }
  }

  // Gửi tin nhắn
  void sendMessage(String sender, String message) {
    _socket.emit('sendGroupMessage', {
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

      _socket.emit('sendGroupImage', {
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

      _socket.emit('sendGroupFile', {
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
    _socket.emit('recallGroupMessage', {
      'messageId': messageId,
      'groupId': groupId,
    });
  }

  Future<String?> initializeGroupCall(String groupId) async {
    try {
      print('Initializing group call for group: $groupId');
      final response = await http.post(
        Uri.parse('$baseUrl/api/groups/initialize-call'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'groupId': groupId,
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['token'] != null) {
          _addSystemMessage('Group call started');
          return data['token'];
        } else {
          throw Exception('Token not found in response');
        }
      } else {
        throw Exception('Failed to initialize call: ${response.statusCode}');
      }
    } catch (e) {
      print('Error initializing group call: $e');
      return null;
    }
  }

  void _addSystemMessage(String message) {
    // Add system message to the messages stream
    final systemMessage = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': 'system',
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
      'senderId': 'system',
      'sender': 'System',
    };
    
    // Add to messages stream
    _messagesgroupStreamController.add([..._currentMessages, systemMessage]);
  }

  // Stream để lắng nghe tin nhắn
  Stream<List<Map<String, dynamic>>> get messagesgruopStream =>
      _messagesgroupStreamController.stream;

  Stream<String> get recallStream => _recallStreamController.stream;

  // Đóng socket và Stream
  void dispose() {
    _socket.emit('leaveGroup', {'groupId': groupId});
    _socket.off('receiveGroupMessage');
    _socket.disconnect();
    if (!_messagesgroupStreamController.isClosed) {
      _messagesgroupStreamController.close();
    }
    _recallStreamController.close();
  }
}

class MessagePage {
  final List<Map<String, dynamic>> messages;
  final int currentPage;
  final int totalPages;

  MessagePage({
    required this.messages,
    required this.currentPage,
    required this.totalPages,
  });
}
