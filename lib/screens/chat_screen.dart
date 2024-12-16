import 'dart:convert';

import 'package:appchatonline/config/config.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import '../services/chat_service.dart';
import 'call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  final String friendId;

  const ChatScreen({Key? key, required this.userId, required this.friendId})
      : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ChatService chatService;
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> messages = [];
  bool isLoading = true;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    messages.clear(); // Clear messages when initializing
    chatService = ChatService(widget.userId, widget.friendId);

    // Load old messages
    _loadMessages();

    // Listen for new messages
    chatService.messageStream.listen((message) {
      setState(() {
        // Check if message already exists to prevent duplicates
        if (!messages.any((msg) => msg['id'] == message['id'])) {
          messages.add(message);
        }
      });
    });

    // Listen for message recalls
    chatService.recallStream.listen((messageId) {
      setState(() {
        final index = messages.indexWhere((msg) => msg['id'] == messageId);
        if (index != -1) {
          messages[index] = {...messages[index], 'isRecalled': 'true'};
        }
      });
    });
  }

  Future<void> _loadMessages() async {
    try {
      final oldMessages = await chatService.loadMessages();
      setState(() {
        // Clear existing messages before adding old ones
        messages.clear();
        messages.addAll(oldMessages);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error loading messages: $e');
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        await chatService.sendImage(File(image.path));
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      chatService.sendMessage(_controller.text);
      _controller.clear();
    }
  }

  void _showRecallDialog(String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recall Message'),
        content: const Text('Do you want to recall this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              chatService.recallMessage(messageId);
              Navigator.pop(context);
            },
            child: const Text('Recall'),
          ),
        ],
      ),
    );
  }

  Future<void> _initiateCall() async {
    try {
      final url = Uri.parse('${Config.apiBaseUrl}/api/notifications/call');
      print('Initiating call to URL: $url');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'receiverId': widget.friendId,
          'callerId': widget.userId,
          'type': 'video_call',
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          if (!mounted) return;
          
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CallScreen(
                channelName: responseData['channelName'],
                token: '',
                isOutgoing: true,
              ),
            ),
          );
        } else {
          throw Exception('Call failed: ${responseData['error']}');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}\n${response.body}');
      }
    } catch (e) {
      print('Call error: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Call failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    chatService.dispose();
    super.dispose();
  }

  Widget _buildMessageContent(Map<String, String> message) {
    final isRecalled = message['isRecalled'] == 'true';
    final isImage = message['type'] == 'image';
    final timestamp = DateTime.parse(
        message['timestamp'] ?? DateTime.now().toIso8601String());
    final timeStr =
        "${timestamp.day}/${timestamp.month} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}";

    if (isRecalled) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.replay, size: 16, color: Colors.grey),
          SizedBox(width: 4),
          Text(
            'Message has been recalled',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ],
      );
    } else if (isImage) {
      return Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.6,
          maxHeight: 200,
        ),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CachedNetworkImage(
              imageUrl: message['message'] ?? '',
              fit: BoxFit.contain,
              placeholder: (context, url) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(
                      'Loading...',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              errorWidget: (context, url, error) => Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.error, color: Colors.red, size: 32),
                  SizedBox(height: 4),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Add timestamp overlay
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  timeStr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.all(5.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: message['sender'] == widget.userId
              ? const Color.fromARGB(145, 130, 190, 197)
              : Colors.grey[300],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: message['sender'] == widget.userId
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(message['message'] ?? ''),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.video_call),
            onPressed: _initiateCall,
          ),
        ],
        backgroundColor: Colors.transparent, // Màu của AppBar
        elevation: 4.0, // Tạo hiệu ứng đổ bóng cho AppBar
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.fromARGB(207, 70, 131, 180), // Màu thứ hai
                Color.fromARGB(41, 130, 190, 197), // Màu đầu tiên
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isCurrentUser = message['sender'] == widget.userId;
                      final isRecalled = message['isRecalled'] == 'true';

                      return GestureDetector(
                        onLongPress: isCurrentUser &&
                                !isRecalled &&
                                message['id'] != null
                            ? () => _showRecallDialog(message['id']!)
                            : null,
                        child: Row(
                          mainAxisAlignment: isCurrentUser
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Avatar cho người gửi khác
                            if (!isCurrentUser)
                              const Padding(
                                padding: EdgeInsets.only(left: 8.0, right: 4.0),
                                child: CircleAvatar(
                                  backgroundColor:
                                      Colors.grey, // Màu xám cho avatar
                                  radius: 20, // Kích thước avatar
                                  child: Icon(
                                    Icons.person, // Biểu tượng người dùng
                                    color: Colors.white, // Màu icon
                                    size: 20, // Kích thước icon
                                  ),
                                ),
                              ),
                            // Bong bóng tin nhắn
                            Flexible(child: _buildMessageContent(message)),
                            if (isCurrentUser)
                              const Padding(
                                padding: EdgeInsets.only(left: 4.0, right: 8.0),
                                child: CircleAvatar(
                                  backgroundColor: Color.fromARGB(
                                      255, 3, 62, 72), // Màu xanh cho avatar
                                  radius: 20, // Kích thước avatar
                                  child: Icon(
                                    Icons.person, // Biểu tượng người dùng
                                    color: Colors.white, // Màu icon
                                    size: 20, // Kích thước icon
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.image),
                  onPressed: _pickAndSendImage,
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0), // Padding cho viền
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.fromARGB(
                              176, 70, 131, 180), // Màu thứ hai của gradient
                          Color.fromARGB(
                              39, 130, 190, 197), // Màu đầu tiên của gradient
                        ],
                      ),
                      borderRadius:
                          BorderRadius.circular(15), // Bo góc cho thanh ngoài
                    ),
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Enter a message',
                        border: InputBorder
                            .none, // Loại bỏ viền mặc định của TextField
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  iconSize: 30,
                  color: Color.fromARGB(227, 130, 190, 197), // Màu cho icon
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
