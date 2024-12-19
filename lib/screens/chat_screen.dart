import 'dart:convert';
import 'package:appchatonline/config/config.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/notification_service.dart';
import 'call_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/config.dart';
import '../services/chat_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../services/download_service.dart';

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
  int _currentPage = 1;
  static const int _pageSize = 20;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _initializeChatService();
  }

  void _initializeChatService() {
    chatService = ChatService(widget.userId, widget.friendId);
    messages.clear();
    _loadMessages();
    
    // Add recall stream listener
    chatService.recallStream.listen((messageId) {
      setState(() {
        final index = messages.indexWhere((msg) => msg['id'] == messageId); 
        if (index != -1) {
          messages[index]['isRecalled'] = 'true';
        }
      });
    });

    _updateMessageStream();
    NotificationService().init(widget.userId, context: context);
    _loadUserAvatars();
    DownloadService.initialize();
  }

  void _onScroll() {
    if (_scrollController.position.pixels == 0 && !_isLoadingMore && _hasMore) {
      _loadMoreMessages();
    }
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
      setState(() {
        isLoading = true;
      });

      final result = await chatService.loadMessages(page: _currentPage, limit: _pageSize);
      
      setState(() {
        messages.clear();
        messages.addAll(List<Map<String, String>>.from(result['messages']));
        _hasMore = result['hasMore'];
        isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error loading messages: $e');
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final result = await chatService.loadMessages(
        page: _currentPage + 1,
        limit: _pageSize,
      );

      setState(() {
        _currentPage++;
        messages.insertAll(0, List<Map<String, String>>.from(result['messages']));
        _hasMore = result['hasMore'];
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
      print('Error loading more messages: $e');
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
        
        // Check file size
        int fileSize = await file.length();
        if (fileSize > 500 * 1024 * 1024) { // 500MB limit
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File size must be less than 500MB')),
          );
          return;
        }
        
        await chatService.sendFile(
          file, 
          fileName, 
          mimeType,
          onProgress: (progress) {
            // Progress is handled by the upload progress card
          }
        );
      }
    } catch (e) {
      if (!mounted) return;
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

  Future<void> _initiateCall() async {
    try {
      chatService.sendMessage("📞 Calling...");

      final url = Uri.parse('${Config.apiBaseUrl}/api/notifications/call');
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

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          if (!mounted) return;

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CallScreen(
                channelName: responseData['channelName'],
                token: responseData['token'], // Use the token from server
                isOutgoing: true,
                onCallEnded: () {
                  chatService.sendMessage("📞 Call ended");
                },
                onCallRejected: () {
                  chatService.sendMessage("📞 Call was declined");
                },
              ),
            ),
          );
        } else {
          throw Exception('Call failed: ${responseData['error']}');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      chatService.sendMessage("📞 Call failed");
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
    _scrollController.removeListener(_onScroll);
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

  Future<void> _downloadImage(String imageUrl) async {
    try {
      final fileName = 'IMG_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageUrl)}';
      final taskId = await DownloadService.downloadFile(
        url: imageUrl,
        fileName: fileName,
        isImage: true,
      );

      if (taskId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image download started')),
        );
      } else {
        throw Exception('Download failed to start');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download image: $e')),
      );
    }
  }

  Future<void> _downloadFile(String fileUrl, String fileName) async {
    try {
      final taskId = await DownloadService.downloadFile(
        url: fileUrl,
        fileName: fileName,
        isImage: false,
      );

      if (taskId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File download started')),
        );
      } else {
        throw Exception('Download failed to start');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download file: $e')),
      );
    }
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
            GestureDetector(
              onTap: () => _downloadImage(message['message'] ?? ''),
              child: CachedNetworkImage(
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
            Row(
              children: [
                TextButton(
                  onPressed: () => launch(fileInfo['viewLink']),
                  child: Text('Open File'),
                ),
                TextButton(
                  onPressed: () => _downloadFile(fileInfo['viewLink'], fileInfo['fileName']),
                  child: Text('Download'),
                ),
              ],
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
                    controller: _scrollController,
                    reverse: false,
                    itemCount: messages.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == 0 && _hasMore) {
                        return Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(
                            child: _isLoadingMore
                                ? CircularProgressIndicator()
                                : Text('Pull to load more'),
                          ),
                        );
                      }
                      final actualIndex = _hasMore ? index - 1 : index;
                      final message = messages[actualIndex];
                      final isCurrentUser = message['sender'] == widget.userId;
                      final isRecalled = message['isRecalled'] == 'true';

                      return GestureDetector(
                        onLongPress: isCurrentUser && !isRecalled && message['id'] != null 
                            ? () => _showRecallDialog(message['id']!)
                            : null,
                        behavior: HitTestBehavior.translucent,
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
                      maxLength: 1000, // Add character limit
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => Container(), // Hide counter
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
