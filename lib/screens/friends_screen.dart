import 'package:flutter/material.dart';
import '../services/friend_service.dart';
import 'addfriend_screen.dart';
import 'chat_screen.dart';
import 'friendrequests_screen.dart';
import 'dart:async';

class FriendsScreen extends StatefulWidget {
  final String userId;

  const FriendsScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _FriendsScreenState createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  late FriendService friendService;

  @override
  void initState() {
    super.initState();
    friendService = FriendService();
    // Initial load and periodic refresh
    friendService.getFriends(widget.userId);
    // Refresh friend list every 30 seconds to ensure status is up to date
    Timer.periodic(Duration(seconds: 30), (_) {
      if (mounted) {
        friendService.getFriends(widget.userId);
      }
    });
  }

  // Add this method to build status indicator
  Widget _buildStatusIndicator(String? status) {
    // Ensure status is not null and properly handled
    final isOnline = status?.toLowerCase() == 'online';
    return Container(
      width: 12,
      height: 12,
      margin: EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline 
            ? Color(0xFF4CAF50)  // Material Design Green
            : Color(0xFF9E9E9E),  // Material Design Grey
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
                        backgroundImage: friendData['avatar'] != null && friendData['avatar'].isNotEmpty
                            ? NetworkImage(friendData['avatar'])
                            : null,
                        child: friendData['avatar'] == null || friendData['avatar'].isEmpty
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
                  subtitle: Text(
                    friendData['status'] == 'online' ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: friendData['status'] == 'online' 
                          ? Color(0xFF4CAF50)  // Material Design Green
                          : Color(0xFF9E9E9E), // Material Design Grey
                      fontWeight: FontWeight.w500,
                    ),
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
              );
            },
          );
        },
      ),
    );
  }
}
