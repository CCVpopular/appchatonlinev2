import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/config.dart';
import '../services/chat_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

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
  String? friendAvatar;
  String? myAvatar;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    messages.clear(); // Clear messages when initializing
    chatService = ChatService(widget.userId, widget.friendId);

    // Load old messages
    _loadMessages();

    // Listen for new messages
    _updateMessageStream();

    // Listen for message recalls
    chatService.recallStream.listen((messageId) {
      setState(() {
        final index = messages.indexWhere((msg) => msg['id'] == messageId);
        if (index != -1) {
          messages[index] = {...messages[index], 'isRecalled': 'true'};
        }
      });
    });

    _loadUserAvatars();
  }

  Future<void> _loadUserAvatars() async {
    try {
      // Load friend's profile
      final friendProfile = await http.get(
        Uri.parse('${Config.apiBaseUrl}/api/users/profile/${widget.friendId}')
      );
      
      // Load my profile
      final myProfile = await http.get(
        Uri.parse('${Config.apiBaseUrl}/api/users/profile/${widget.userId}')
      );

      if (mounted) {
        setState(() {
          friendAvatar = jsonDecode(friendProfile.body)['avatar'];
          myAvatar = jsonDecode(myProfile.body)['avatar'];
        });
      }
    } catch (e) {
      print('Error loading avatars: $e');
    }
  }

  Future<void> _loadMessages() async {
    try {
      final oldMessages = await chatService.loadMessages();
      setState(() {
        // Clear existing messages before adding old ones
        messages.clear();
        messages.addAll(oldMessages);
        isLoading = false;
        
        // Auto scroll after loading messages
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
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
        await chatService.sendImage(
          File(image.path),
          onProgress: (progress) {
            // Progress is now handled by the upload progress card
          }
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending image: $e')),
      );
      print('Error picking image: $e');
    }
  }

  Future<void> _pickAndSendFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        File file = File(result.files.single.path!);
        String fileName = result.files.single.name;
        String? mimeType = result.files.single.extension != null 
            ? 'application/${result.files.single.extension}'
            : 'application/octet-stream';
        
        await chatService.sendFile(
          file, 
          fileName, 
          mimeType,
          onProgress: (progress) {
            // Progress is now handled by the upload progress card
          }
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending file: $e')),
      );
      print('Error picking file: $e');
    }
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      chatService.sendMessage(_controller.text);
      _controller.clear();
      // Scroll to bottom after sending
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
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

  @override
  void dispose() {
    _scrollController.dispose();
    chatService.dispose();
    super.dispose();
  }

  Widget _buildAvatar(String? avatarUrl, bool isCurrentUser) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return Padding(
        padding: EdgeInsets.only(
          left: isCurrentUser ? 4.0 : 8.0,
          right: isCurrentUser ? 8.0 : 4.0,
        ),
        child: CachedNetworkImage(
          imageUrl: avatarUrl,
          imageBuilder: (context, imageProvider) => CircleAvatar(
            backgroundImage: imageProvider,
            radius: 20,
          ),
          placeholder: (context, url) => CircleAvatar(
            backgroundColor: isCurrentUser 
              ? Color.fromARGB(255, 3, 62, 72)
              : Colors.grey,
            radius: 20,
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
          errorWidget: (context, url, error) => CircleAvatar(
            backgroundColor: isCurrentUser 
              ? Color.fromARGB(255, 3, 62, 72)
              : Colors.grey,
            radius: 20,
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        left: isCurrentUser ? 4.0 : 8.0,
        right: isCurrentUser ? 8.0 : 4.0,
      ),
      child: CircleAvatar(
        backgroundColor: isCurrentUser 
          ? Color.fromARGB(255, 3, 62, 72)
          : Colors.grey,
        radius: 20,
        child: Icon(Icons.person, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildMessageContent(Map<String, String> message) {
    final isTemporary = message['isTemporary'] == 'true';
    
    if (isTemporary) {
      return Container(
        margin: const EdgeInsets.all(5.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
              ),
            ),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                message['message'] ?? '',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

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
    } else if (message['type'] == 'file') {
      final fileInfo = jsonDecode(message['message']!);
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.file_present),
                SizedBox(width: 8),
                Expanded(
                  child: Text(fileInfo['fileName'],
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            TextButton(
              onPressed: () => launch(fileInfo['viewLink']),
              child: Text('Open File'),
            ),
            Text(
              timeStr,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
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

  void _updateMessageStream() {
    chatService.messageStream.listen((message) {
      setState(() {
        if (message['isTemporary'] == 'true') {
          // Add temporary message
          messages.add(message);
        } else {
          // Remove temporary message and add real message
          messages.removeWhere((msg) => msg['isTemporary'] == 'true');
          if (!messages.any((msg) => msg['id'] == message['id'])) {
            messages.add(message);
          }
        }
        // Scroll to bottom after setState
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      });
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
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
                    controller: _scrollController,
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
                              _buildAvatar(friendAvatar, false),
                            // Bong bóng tin nhắn
                            Flexible(child: _buildMessageContent(message)),
                            if (isCurrentUser)
                              _buildAvatar(myAvatar, true),
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
                IconButton(
                  icon: Icon(Icons.attach_file),
                  onPressed: _pickAndSendFile,
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
