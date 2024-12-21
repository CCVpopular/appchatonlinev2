import 'dart:async';
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
import 'package:flutter/services.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  final String friendId;

  const ChatScreen({Key? key, required this.userId, required this.friendId})
      : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  late ChatService chatService;
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> messages = [];
  bool isLoading = true;
  final ImagePicker _picker = ImagePicker();
  String? friendAvatar;
  String? myAvatar;
  String? friendName;
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  static const int _pageSize = 20;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isScreenVisible = true;
  Timer? _readStatusTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChatService();
    _onScreenVisible(); // Initial read status update
  }

  void _initializeChatService() {
    chatService = ChatService(widget.userId, widget.friendId);
    messages.clear();
    _loadMessages();
    _scrollController.addListener(_onScroll); // Add scroll listener
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
    // Load more when scrolled 70% up
    if (!_isLoadingMore && _hasMore) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      final triggerPoint = maxScroll * 0.3; // 70% from top (30% from bottom)

      if (currentScroll <= triggerPoint) {
        _loadMoreMessages();
      }
    }
  }

  Future<void> _loadUserAvatars() async {
    try {
      // Load friend's profile
      final friendProfile = await http.get(Uri.parse(
          '${Config.apiBaseUrl}/api/users/profile/${widget.friendId}'));

      // Load my profile
      final myProfile = await http.get(
          Uri.parse('${Config.apiBaseUrl}/api/users/profile/${widget.userId}'));

      if (mounted) {
        setState(() {
          friendName = jsonDecode(friendProfile.body)['username'];
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

      final result =
          await chatService.loadMessages(page: _currentPage, limit: _pageSize);

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

      if (mounted) {
        setState(() {
          _currentPage++;
          // Maintain scroll position when adding messages
          final oldPosition = _scrollController.position.pixels;
          messages.insertAll(
              0, List<Map<String, String>>.from(result['messages']));
          _hasMore = result['hasMore'];
          _isLoadingMore = false;

          // Restore scroll position after layout
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(oldPosition +
                  (_scrollController.position.maxScrollExtent - oldPosition));
            }
          });
        });
      }
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
        await chatService.sendImage(File(image.path), onProgress: (progress) {
          // Progress is now handled by the upload progress card
        });
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
        if (fileSize > 500 * 1024 * 1024) {
          // 500MB limit
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File size must be less than 500MB')),
          );
          return;
        }

        await chatService.sendFile(file, fileName, mimeType,
            onProgress: (progress) {
          // Progress is handled by the upload progress card
        });
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
    WidgetsBinding.instance.removeObserver(this);
    _readStatusTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    chatService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onScreenVisible();
    } else if (state == AppLifecycleState.paused) {
      _isScreenVisible = false;
      _readStatusTimer?.cancel();
    }
  }

  void _onScreenVisible() {
    _isScreenVisible = true;
    _markMessagesAsRead();

    // Setup periodic read status updates while screen is visible
    _readStatusTimer?.cancel();
    _readStatusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_isScreenVisible) {
        _markMessagesAsRead();
      }
    });
  }

  Future<void> _markMessagesAsRead() async {
    if (!_isScreenVisible) return;

    try {
      final response = await http.post(
        Uri.parse('${Config.apiBaseUrl}/api/messages/mark-read'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'senderId': widget.friendId, // Messages FROM friend
          'receiverId': widget.userId, // Messages TO current user
        }),
      );

      if (response.statusCode != 200) {
        print('Error marking messages as read: ${response.body}');
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
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
            backgroundColor:
                isCurrentUser ? Color.fromARGB(255, 3, 62, 72) : Colors.grey,
            radius: 20,
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
          errorWidget: (context, url, error) => CircleAvatar(
            backgroundColor:
                isCurrentUser ? Color.fromARGB(255, 3, 62, 72) : Colors.grey,
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
        backgroundColor:
            isCurrentUser ? Color.fromARGB(255, 3, 62, 72) : Colors.grey,
        radius: 20,
        child: Icon(Icons.person, color: Colors.white, size: 20),
      ),
    );
  }

  Future<void> _downloadImage(String imageUrl) async {
    try {
      final fileName =
          'IMG_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageUrl)}';
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
        width: 300, // Giới hạn chiều rộng
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
                  onPressed: () =>
                      _downloadFile(fileInfo['viewLink'], fileInfo['fileName']),
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color.fromARGB(255, 4, 4, 4),
                  ),
                ),
                if (message['sender'] == widget.userId) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message['status'] == 'read' ? Icons.done_all : Icons.done,
                    size: 12,
                    color:
                        message['status'] == 'read' ? Colors.blue : Colors.grey,
                  ),
                ],
              ],
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
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70), // Điều chỉnh chiều cao của AppBar
        child: Container(
          margin: EdgeInsets.only(
              top: 0,
              left: 10,
              right: 10,
              bottom: 10), // Thêm margin xung quanh AppBar
          child: AppBar(
            title: Padding(
              padding: EdgeInsets.only(
                  left: 15, bottom: 15), // Thêm padding cho tiêu đề
              child: Text(
                friendName ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            backgroundColor: Colors.transparent, // Nền trong suốt
            elevation: 0, // Xóa bóng đổ mặc định của AppBar
            flexibleSpace: Stack(
              // Sử dụng Stack để chồng các phần nền
              children: [
                // Nền thứ nhất (dưới cùng)
                Positioned(
                  top: 20, // Điều chỉnh vị trí nền thứ nhất
                  left: 20,
                  right: 0,
                  bottom: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Color.fromARGB(255, 57, 51, 66) // Nền tối
                          : Color.fromARGB(77, 83, 32, 120), // Nền sáng
                      borderRadius: BorderRadius.circular(25), // Bo góc
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white // Viền trắng khi chế độ tối
                            : Colors.black, // Viền đen khi chế độ sáng
                        width: 2, // Độ dày viền
                      ),
                    ),
                  ),
                ),
                // Nền thứ hai (chồng lên nền thứ nhất)
                Positioned(
                  top:
                      5, // Điều chỉnh vị trí nền thứ hai (giảm top để nền thứ hai nhỏ hơn)
                  left: 5, // Điều chỉnh khoảng cách từ bên trái
                  right: 8, // Điều chỉnh khoảng cách từ bên phải
                  bottom: 10, // Điều chỉnh khoảng cách từ dưới
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Color.fromARGB(
                              255, 77, 68, 89) // Nền nhẹ màu xám khi chế độ tối
                          : Color.fromARGB(255, 255, 255,
                              255), // Nền nhẹ màu trắng khi chế độ sáng
                      borderRadius: BorderRadius.circular(25), // Bo góc
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white // Viền trắng khi chế độ tối
                            : Colors.black, // Viền đen khi chế độ sáng
                        width: 2, // Độ dày viền
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding:
                    EdgeInsets.only(right: 10), // Thêm padding cho các icon
                child: IconButton(
                  icon: const Icon(Icons.video_call),
                  onPressed: _initiateCall,
                ),
              ),
            ],
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
                    itemCount: messages.length +
                        1, // Always add 1 for loading indicator
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Visibility(
                          visible: _isLoadingMore,
                          child: Container(
                            padding: EdgeInsets.all(8.0),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        );
                      }
                      // Adjust index for actual messages
                      final message = messages[index - 1];
                      final isCurrentUser = message['sender'] == widget.userId;
                      final isRecalled = message['isRecalled'] == 'true';

                      return GestureDetector(
                        onLongPress: isCurrentUser &&
                                !isRecalled &&
                                message['id'] != null
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
                            if (isCurrentUser) _buildAvatar(myAvatar, true),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color.fromARGB(255, 33, 33, 33) // Nền tối
                    : const Color.fromARGB(255, 255, 255, 255), // Nền sáng
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white // Viền trắng khi chế độ tối
                      : Colors.black, // Viền đen khi chế độ sáng
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: IconButton(
                        icon: const Icon(Icons.image),
                        onPressed: _pickAndSendImage,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : const Color.fromARGB(255, 103, 48, 129),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: IconButton(
                        icon: const Icon(Icons.attach_file),
                        onPressed: _pickAndSendFile,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : const Color.fromARGB(255, 103, 48, 129),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: TextField(
                          controller: _controller,
                          maxLength: 1000,
                          buildCounter: (context,
                                  {required currentLength,
                                  required isFocused,
                                  maxLength}) =>
                              null, // Ẩn bộ đếm ký tự
                          decoration: const InputDecoration(
                            hintText: 'Enter your message...',
                            border:
                                InputBorder.none, // Loại bỏ viền của TextField
                          ),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color.fromARGB(107, 128, 83, 180)
                            : const Color.fromARGB(255, 255, 255, 255),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                          width: 2,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _sendMessage,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color.fromARGB(255, 255, 255, 255)
                            : const Color.fromARGB(255, 103, 48, 129),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
