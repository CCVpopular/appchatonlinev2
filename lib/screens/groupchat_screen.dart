import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/groupchat_service.dart';
import 'invitemember_screen.dart';

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
  List<Map<String, dynamic>> _currentMessages = [];

  @override
  void initState() {
    super.initState();
    groupChatService = GroupChatService(widget.groupId);

    // Add recall listener
    groupChatService.recallStream.listen((messageId) {
      setState(() {
        final index = _currentMessages.indexWhere((msg) => msg['id'] == messageId);
        if (index != -1) {
          _currentMessages[index]['isRecalled'] = true;
        }
      });
    });
  }

  @override
  void dispose() {
    groupChatService.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      groupChatService.sendMessage(widget.userId, _controller.text);
      _controller.clear();
    }
  }

  Future<void> _pickAndSendImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      File imageFile = File(image.path);
      groupChatService.sendImage(widget.userId, imageFile);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Group Chat'),
        actions: [
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
                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return Row(
                      mainAxisAlignment: message['senderId'] == widget.userId
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        if (message['senderId'] != widget.userId)
                          const CircleAvatar(
                            backgroundColor: Colors.grey,
                            radius: 20,
                            child: Icon(Icons.person, color: Colors.white, size: 20),
                          ),
                        Flexible(child: _buildMessageContent(message)),
                        if (message['senderId'] == widget.userId)
                          const CircleAvatar(
                            backgroundColor: Color.fromARGB(255, 3, 62, 72),
                            radius: 20,
                            child: Icon(Icons.person, color: Colors.white, size: 20),
                          ),
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
                Expanded(
                  child: TextField(
                    controller: _controller,
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
}
