import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/config.dart';

class FriendRequestsScreen extends StatefulWidget {
  final String userId;
  final String baseUrl = Config.apiBaseUrl;

  const FriendRequestsScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _FriendRequestsScreenState createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  List<Map<String, dynamic>> friendRequests = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFriendRequests();
  }

  Future<void> _loadFriendRequests() async {
    try {
      final url = Uri.parse('${widget.baseUrl}/api/friends/friend-requests/${widget.userId}');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          friendRequests = data.map((request) {
            return {
              'id': request['_id'], // ID của lời mời kết bạn
              'requesterId': request['requester']['_id'], // ID của người gửi
              'username': request['requester']['username'], // Tên người gửi
            };
          }).toList();
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load friend requests');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error loading friend requests: $e');
    }
  }

  Future<void> _acceptRequest(String requestId) async {
    try {
      final url = Uri.parse('${widget.baseUrl}/api/friends/accept-friend');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'friendshipId': requestId}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Friend request accepted!')),
        );
        setState(() {
          friendRequests.removeWhere((req) => req['id'] == requestId);
        });
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Failed to accept friend request';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting friend request: $e')),
      );
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    try {
      final url = Uri.parse('${widget.baseUrl}/api/friends/reject-friend');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'friendshipId': requestId}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request rejected')),
        );
        setState(() {
          friendRequests.removeWhere((req) => req['id'] == requestId);
        });
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Failed to reject friend request';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting friend request: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friend Requests'),
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
      
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : friendRequests.isEmpty
              ? Center(child: Text('No friend requests'))
              : ListView.builder(
                  itemCount: friendRequests.length,
                  itemBuilder: (context, index) {
                    final request = friendRequests[index];
                    return ListTile(
                      title: Text(request['username']),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed: () => _acceptRequest(request['id']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: const Text('Accept'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _rejectRequest(request['id']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('Reject'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
