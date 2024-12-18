import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/config.dart';
import '../services/download_service.dart';
import '../services/groupchat_service.dart';
import 'group_call_screen.dart';
import 'invitemember_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String userId;

  const GroupChatScreen({Key? key, required this.groupId, required this.userId}) : super(key: key);

  @override
  _GroupChatScreenState createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  late GroupChatService groupChatService;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _currentMessages = [];
  String? groupAvatar;
  String? groupName;
  Map<String, String> userAvatars = {};  // Add this line to store user avatars

  // Add these variables
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  int _currentPage = 1;
  final int _messagesPerPage = 20;
  bool _shouldAutoScroll = true;  // Add this flag

  @override
  void initState() {
    super.initState();
    groupChatService = GroupChatService(widget.groupId);
    _setupScrollController();
    
    // Update recall stream listener
    groupChatService.recallStream.listen((messageId) {
      setState(() {
        final index = _currentMessages.indexWhere((msg) => 
          (msg['_id'] ?? msg['id']) == messageId);
        if (index != -1) {
          _currentMessages[index]['isRecalled'] = true;
          // Trigger UI update since we're modifying the list directly
          _currentMessages = List.from(_currentMessages);
        }
      });
    });

    _loadGroupInfo();
    
    DownloadService.initialize();
    _loadMemberAvatars();  // Add this line
    _setupCallNotifications();
  }

  void _setupScrollController() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == 0 && !_isLoadingMore && _hasMoreMessages) {
        _loadMoreMessages();
      }
    });
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
      _shouldAutoScroll = false;  // Disable auto-scroll when loading more
    });

    try {
      final result = await groupChatService.loadMoreMessages(_currentPage + 1, _messagesPerPage);
      
      setState(() {
        _hasMoreMessages = _currentPage < result.totalPages;
        if (_hasMoreMessages) {
          _currentPage++;
        }
      });
    } catch (e) {
      print('Error loading more messages: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading messages')),
      );
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadGroupInfo() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.apiBaseUrl}/api/groups/group-info/${widget.groupId}')
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          groupAvatar = data['avatar'];
          groupName = data['name'];
        });
      }
    } catch (e) {
      print('Error loading group info: $e');
    }
  }

  Future<void> _loadMemberAvatars() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.apiBaseUrl}/api/groups/members/${widget.groupId}')
      );
      print(response.statusCode);
      if (response.statusCode == 200) {
        final members = jsonDecode(response.body) as List;
        for (var member in members) {
          userAvatars[member['_id']] = member['avatar'] ?? '';
        }
        if (mounted) setState(() {});
      }
    } catch (e) {
      print('Error loading member avatars: $e');
    }
  }

  Future<void> _updateGroupAvatar() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${Config.apiBaseUrl}/api/groups/update-avatar/${widget.groupId}')
        );

        request.files.add(
          await http.MultipartFile.fromPath('avatar', image.path)
        );

        final response = await request.send();
        final responseData = await response.stream.bytesToString();
        final data = jsonDecode(responseData);

        if (response.statusCode == 200) {
          setState(() {
            groupAvatar = data['avatarUrl'];
          });
        }
      }
    } catch (e) {
      print('Error updating group avatar: $e');
    }
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
  void dispose() {
    groupChatService.socket.off('groupCallStarted');
    _scrollController.dispose();
    groupChatService.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      _shouldAutoScroll = true;  // Enable auto-scroll for new messages
      groupChatService.sendMessage(widget.userId, _controller.text);
      _controller.clear();
      // Scroll to bottom after sending
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        File imageFile = File(image.path);
        await groupChatService.sendImage(
          widget.userId, 
          imageFile,
          onProgress: (progress) {
            // Progress is handled by temporary message
            print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
          },
        );
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending image: $e')),
      );
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
        
        await groupChatService.sendFile(
          widget.userId,
          file,
          fileName,
          mimeType,
          onProgress: (progress) {
            // Progress is handled by temporary message
            print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
          },
        );
      }
    } catch (e) {
      print('Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending file: $e')),
      );
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
              groupChatService.recallMessage(messageId);
              Navigator.pop(context);
            },
            child: const Text('Recall'),
          ),
        ],
      ),
    );
  }

  String _formatTime(String timestamp) {
    final dateTime = DateTime.parse(timestamp).toLocal();
    final now = DateTime.now();
    
    if (dateTime.year == now.year && 
        dateTime.month == now.month && 
        dateTime.day == now.day) {
      // Today, just show time
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      // Other days, show date and time
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildMessageContent(Map<String, dynamic> message) {
    final isRecalled = message['isRecalled'] == true;
    final isSender = message['senderId'] == widget.userId;
    
    if (message['type'] == 'loading') {
      return Container(
        margin: const EdgeInsets.all(5.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
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
            Text(
              message['message'],
              style: TextStyle(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    if (message['type'] == 'image') {
      return Container(
        padding: EdgeInsets.all(4),
        child: GestureDetector(
          onLongPress: isSender && !isRecalled 
              ? () => _showRecallDialog(message['id'])
              : null,
          onTap: () => _downloadImage(message['message']),
          child: Column(
            crossAxisAlignment: isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isSender && !isRecalled)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    message['sender'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              CachedNetworkImage(
                imageUrl: message['message'],
                placeholder: (context, url) => Container(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (context, url, error) => Icon(Icons.error),
              ),
              Text(
                _formatTime(message['timestamp']),
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (message['type'] == 'file') {
      final fileInfo = jsonDecode(message['message']);
      return Container(
        margin: const EdgeInsets.all(5.0),
        child: GestureDetector(
          onLongPress: isSender && !isRecalled 
              ? () => _showRecallDialog(message['id'])
              : null,
          child: Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: isSender
                  ? const Color.fromARGB(145, 130, 190, 197)
                  : Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isSender && !isRecalled)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      message['sender'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Icon(Icons.file_present),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileInfo['fileName'],
                        style: TextStyle(fontWeight: FontWeight.bold)
                      ),
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
                  _formatTime(message['timestamp']),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onLongPress: isSender && !isRecalled 
          ? () => _showRecallDialog(message['id'])
          : null,
      child: Container(
        margin: const EdgeInsets.all(5.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: isSender
              ? const Color.fromARGB(145, 130, 190, 197)
              : Colors.grey[300],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isSender && !isRecalled)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message['sender'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            if (!isRecalled)
              message['type'] == 'image'
                ? CachedNetworkImage(
                    imageUrl: message['message'],
                    placeholder: (context, url) => Container(
                      width: 50,
                      height: 50,
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) => Icon(Icons.error),
                  )
                : message['type'] == 'file'
                  ? _buildFileMessageContent(message)
                  : Text(message['message'] ?? ''),
            if (isRecalled)
              Row(
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
              ),
            const SizedBox(height: 2),
            Text(
              _formatTime(message['timestamp']),
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileMessageContent(Map<String, dynamic> message) {
    final fileInfo = jsonDecode(message['message']);
    return Container(
      margin: const EdgeInsets.all(5.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: message['senderId'] == widget.userId
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
                child: Text(
                  fileInfo['fileName'],
                  style: TextStyle(fontWeight: FontWeight.bold)
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: () => launch(fileInfo['viewLink']),
            child: Text('Open File'),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberAvatar(String? userId, bool isSender) {
    String? avatarUrl = userId != null ? userAvatars[userId] : null;

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return Padding(
        padding: EdgeInsets.only(
          left: isSender ? 4.0 : 8.0,
          right: isSender ? 8.0 : 4.0,
        ),
        child: CachedNetworkImage(
          imageUrl: avatarUrl,
          imageBuilder: (context, imageProvider) => CircleAvatar(
            backgroundImage: imageProvider,
            radius: 20,
          ),
          placeholder: (context, url) => CircleAvatar(
            backgroundColor: isSender 
              ? Color.fromARGB(255, 3, 62, 72)
              : Colors.grey,
            radius: 20,
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
          errorWidget: (context, url, error) => CircleAvatar(
            backgroundColor: isSender 
              ? Color.fromARGB(255, 3, 62, 72)
              : Colors.grey,
            radius: 20,
            child: Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ),
      );
    }

    return CircleAvatar(
      backgroundColor: isSender 
        ? Color.fromARGB(255, 3, 62, 72)
        : Colors.grey,
      radius: 20,
      child: Icon(Icons.person, color: Colors.white, size: 20),
    );
  }

  Future<void> _downloadImage(String imageUrl) async {
    try {
      final fileName = 'IMG_${DateTime.now().millisecondsSinceEpoch}.jpg';
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

  void _setupCallNotifications() {
    groupChatService.socket.on('groupCallStarted', (data) {
      if (!mounted) return;
      
      // Don't show notification to call initiator
      if (data['initiatorId'] == widget.userId) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Incoming Group Call'),
          content: Text('${data['initiatorName']} started a group call'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
              },
              child: Text('Decline'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                final token = await groupChatService.initializeGroupCall(widget.groupId);
                if (token != null && mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroupCallScreen(
                        groupId: widget.groupId,
                        channelName: widget.groupId,
                        token: token,
                        userId: widget.userId,
                        isInitiator: false,
                      ),
                    ),
                  );
                }
              },
              child: Text('Join'),
            ),
          ],
        ),
      );
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            GestureDetector(
              onTap: _updateGroupAvatar,
              child: CircleAvatar(
                backgroundImage: groupAvatar != null ? 
                  CachedNetworkImageProvider(groupAvatar!) : null,
                child: groupAvatar == null ? Icon(Icons.group) : null,
              ),
            ),
            SizedBox(width: 8),
            Text(groupName ?? 'Group Chat'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.call),
            onPressed: () async {
              final token = await groupChatService.initializeGroupCall(widget.groupId);
              if (token != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupCallScreen(
                      groupId: widget.groupId,
                      channelName: widget.groupId,
                      token: token,
                      userId: widget.userId,
                      isInitiator: true,
                    ),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.person_add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InviteMemberScreen(
                    groupId: widget.groupId,
                    userId: widget.userId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: groupChatService.messagesgruopStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('No messages yet'));
                }

                final messages = snapshot.data!;
                _currentMessages = messages;
                
                // Only auto scroll for new messages, not when loading old ones
                if (_shouldAutoScroll) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                    }
                  });
                }
                
                return ListView.builder(
                  controller: _scrollController, 
                  itemCount: messages.length + (_hasMoreMessages ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == 0 && _hasMoreMessages) {
                      return _buildLoadingIndicator();
                    }
                    
                    final messageIndex = _hasMoreMessages ? index - 1 : index;
                    if (messageIndex >= messages.length) return null;
                    
                    final message = messages[messageIndex];
                    // Update to use _id instead of id for consistency
                    final messageId = message['_id'] ?? message['id'];
                    return Row(
                      mainAxisAlignment: message['senderId'] == widget.userId
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        if (message['senderId'] != widget.userId)
                          _buildMemberAvatar(message['senderId'], false),
                        Flexible(
                          child: GestureDetector(
                            onLongPress: message['senderId'] == widget.userId && !message['isRecalled']
                                ? () => _showRecallDialog(messageId)
                                : null,
                            child: _buildMessageContent(message),
                          ),
                        ),
                        if (message['senderId'] == widget.userId)
                          _buildMemberAvatar(message['senderId'], true),
                      ],
                    );
                  },
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
                  child: TextField(
                    controller: _controller,
                    maxLength: 1000, // Add character limit
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => Container(), // Hide counter
                    decoration: InputDecoration(hintText: 'Enter a message'),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: _isLoadingMore
            ? CircularProgressIndicator()
            : TextButton(
                onPressed: _loadMoreMessages,
                child: Text('Load more messages'),
              ),
      ),
    );
  }
}
