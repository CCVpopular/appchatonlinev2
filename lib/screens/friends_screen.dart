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

  Future<void> _updateUserStatus(String status) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/users/status/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': status}),
      );
      if (response.statusCode != 200) {
        print('Failed to update status: ${response.body}');
      }
    } catch (e) {
      print('Error updating status: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _updateUserStatus('online'); // Set status to online when screen opens
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

  @override
  void dispose() {
    _updateUserStatus('offline'); // Set status to offline when leaving screen
    super.dispose();
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
        //color: Colors.black54,
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
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70), // Điều chỉnh chiều cao của AppBar
        child: Container(
          margin: EdgeInsets.only(
              top: 0, left: 10, right: 10, bottom: 10), // Thêm margin xung quanh AppBar
          child: AppBar(
            title: Padding(
              padding: EdgeInsets.only(left: 15,bottom: 15), // Thêm padding cho tiêu đề
              child: const Text(
                'Friends',
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
                          ? Color.fromARGB(255, 57, 51, 66)  // Nền tối
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
                  icon: Icon(Icons.refresh),
                  onPressed: () {
                    friendService.getFriends(widget.userId);
                  },
                ),
              ),
              Padding(
                padding:
                    EdgeInsets.only(right: 10), // Thêm padding cho các icon
                child: IconButton(
                  icon: Icon(Icons.person_add),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AddFriendScreen(userId: widget.userId),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding:
                    EdgeInsets.only(right: 10), // Thêm padding cho các icon
                child: IconButton(
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
              ),
            ],
          ),
        ),
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
              print(
                  'Latest message for this friend: ${latestMessages[friendData['_id']]}');

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
                          color: Color.fromARGB(
                              77, 175, 112, 221), // Màu nền cho hình đầu tiên
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Theme.of(context).brightness ==
                                    Brightness.dark
                                ? Colors.white // Viền trắng khi ở chế độ tối
                                : Colors.black, // Viền đen khi ở chế độ sáng
                            width: 2, // Độ dày viền
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
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Color.fromARGB(255, 77, 68,
                                  89) // Màu nền tối khi ở chế độ tối
                              : Color.fromARGB(255, 255, 255,
                                  255), // Màu nền sáng khi ở chế độ sáng // Màu nền cho hình thứ hai
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Theme.of(context).brightness ==
                                    Brightness.dark
                                ? const Color.fromARGB(255, 255, 255,
                                    255) // Viền trắng khi ở chế độ tối
                                : Colors.black, // Viền đen khi ở chế độ sáng
                            width: 2, // Độ dày viền
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
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color.fromARGB(255, 255, 255,
                                          255) // Viền trắng khi ở chế độ tối
                                      : Colors
                                          .black, // Viền đen khi ở chế độ sáng
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
                            //color: Colors.black87,
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
                                  //color: Colors.black54,
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
