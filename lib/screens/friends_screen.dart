import 'package:flutter/material.dart';
import '../config/config.dart';
import '../services/friend_service.dart';
import 'addfriend_screen.dart';
import 'chat_screen.dart';
import 'friendrequests_screen.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class FriendsScreen extends StatefulWidget {
  final String userId;

  const FriendsScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _FriendsScreenState createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  late FriendService friendService;
  Map<String, Map<String, dynamic>> latestMessages = {};
  final String baseUrl = Config.apiBaseUrl;

  @override
  void initState() {
    super.initState();
    friendService = FriendService();
    friendService.getFriends(widget.userId);
    _loadLatestMessages();

    // Refresh both friends and messages periodically
    Timer.periodic(Duration(seconds: 30), (_) {
      if (mounted) {
        friendService.getFriends(widget.userId);
        _loadLatestMessages();
      }
    });
  }

  Future<void> _loadLatestMessages() async {
    try {
      // Update the URL to match the backend route
      final response = await http.get(
        Uri.parse('$baseUrl/api/messages/latest-messages/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> messages = json.decode(response.body);
        print('Received messages: $messages');

        setState(() {
          latestMessages.clear();
          for (var message in messages) {
            if (message['friendId'] != null) {
              latestMessages[message['friendId']] = {
                'message': message['message'] ?? '',
                'type': message['type'] ?? 'text',
                'isRecalled': message['isRecalled'] ?? false,
                'timestamp': DateTime.parse(message['timestamp']),
              };
            }
          }
        });
        print('Updated latest messages: $latestMessages');
      } else {
        print('Error status code: ${response.statusCode}');
        print('Error body: ${response.body}');
      }
    } catch (e) {
      print('Error loading latest messages: $e');
    }
  }

  Widget _buildStatusIndicator(String? status) {
    final isOnline = status?.toLowerCase() == 'online';
    return Container(
      width: 12,
      height: 12,
      margin: EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline
            ? Color(0xFF4CAF50) // Material Design Green
            : Color(0xFF9E9E9E), // Material Design Grey
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestMessage(String friendId) {
    final messageData = latestMessages[friendId];
    if (messageData == null) return const SizedBox.shrink();

    String messageText;
    if (messageData['isRecalled'] == true) {
      messageText = 'Message recalled';
    } else {
      switch (messageData['type']) {
        case 'image':
          messageText = '🖼️ Image';
          break;
        case 'file':
          messageText = '📎 File';
          break;
        default:
          messageText = messageData['message'] ?? '';
      }
    }

    return Text(
      messageText,
      style: const TextStyle(
        color: Colors.black54,
        fontSize: 13,
        height: 1.5,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildChatTile(Map<String, dynamic> friendData, String friendId) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(207, 70, 131, 180),
            Color.fromARGB(129, 130, 190, 197),
          ],
        ),
      ),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundImage: friendData['avatar'] != null &&
                      friendData['avatar'].isNotEmpty
                  ? NetworkImage(friendData['avatar'])
                  : null,
              child:
                  friendData['avatar'] == null || friendData['avatar'].isEmpty
                      ? Icon(Icons.person)
                      : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: _buildStatusIndicator(friendData['status'] ?? 'offline'),
            ),
          ],
        ),
        title: Text(
          friendData['username'] ?? 'Unknown',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (latestMessages.containsKey(friendId))
              _buildLatestMessage(friendId)
            else
              Text(
                'No messages yet',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              friendData['status'] == 'online' ? 'Online' : 'Offline',
              style: TextStyle(
                color: friendData['status'] == 'online'
                    ? Color(0xFF4CAF50)
                    : Color(0xFF9E9E9E),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                userId: widget.userId,
                friendId: friendId,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
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
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              friendService.getFriends(widget.userId);
            },
          ),
          IconButton(
            icon: Icon(Icons.person_add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddFriendScreen(userId: widget.userId),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.group),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      FriendRequestsScreen(userId: widget.userId),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<dynamic>>(
        stream: friendService.friendsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Failed to load friends'));
          }

          final friends = snapshot.data ?? [];

          if (friends.isEmpty) {
            return Center(child: Text('No friends yet'));
          }
          return ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              final friendData = friend['requester']['_id'] == widget.userId
                  ? friend['receiver']
                  : friend['requester'];

              // Print debug information
              print('Friend ID: ${friendData['_id']}');
              print('Latest message for this friend: ${latestMessages[friendData['_id']]}');

              return Container(
                margin:
                    const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
                child: Stack(
                  children: [
                    // Hình nền thứ nhất chéo
                    Positioned(
                      top: 11,
                      left: 11,
                      child: Container(
                        width: 380,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Color.fromARGB(77, 228, 227, 227), // Màu nền cho hình đầu tiên
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.black, // Viền đen
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withOpacity(0.2), // Màu bóng đổ đen
                              blurRadius: 10,
                              spreadRadius: 2,
                              offset: Offset(2, 2), // Định vị bóng đổ
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Hình nền thứ hai chéo
                    Positioned(
                      top: 5,
                      left: -0.5,
                      child: Container(
                        width: 385,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Color.fromARGB(255, 255, 255, 255), // Màu nền cho hình thứ hai
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.black, // Viền đen
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withOpacity(0.2), // Màu bóng đổ đen
                              blurRadius: 10,
                              spreadRadius: 2,
                              offset: Offset(2, 2), // Định vị bóng đổ
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Nội dung thẻ
                    Positioned(
                      child: ListTile(
                        leading: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(
                                  2), // Khoảng cách giữa viền và avatar
                              decoration: BoxDecoration(
                                shape: BoxShape
                                    .circle, // Đảm bảo avatar là hình tròn
                                border: Border.all(
                                  color: Colors.black, // Viền đen cho avatar
                                  width: 2, // Độ dày viền
                                ),
                              ),
                              child: CircleAvatar(
                                backgroundImage: friendData['avatar'] != null &&
                                        friendData['avatar'].isNotEmpty
                                    ? NetworkImage(friendData['avatar'])
                                    : null,
                                child: friendData['avatar'] == null ||
                                        friendData['avatar'].isEmpty
                                    ? Icon(Icons.person)
                                    : null,
                                radius: 20, // Bán kính avatar
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: _buildStatusIndicator(
                                  friendData['status'] ?? 'offline'),
                            ),
                          ],
                        ),
                        title: Text(
                          friendData['username'] ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (latestMessages.containsKey(friendData['_id']))
                              _buildLatestMessage(friendData['_id'])
                            else
                              Text(
                                'No messages yet',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              friendData['status'] == 'online'
                                  ? 'Online'
                                  : 'Offline',
                              style: TextStyle(
                                color: friendData['status'] == 'online'
                                    ? Color(0xFF4CAF50)
                                    : Color(0xFF9E9E9E),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                userId: widget.userId,
                                friendId: friendData['_id'],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
