import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../config/config.dart';
import '../services/SocketManager.dart';

class InviteMemberScreen extends StatefulWidget {
  final String groupId;
  final String userId;
  final String baseUrl = Config.apiBaseUrl;

  const InviteMemberScreen(
      {Key? key, required this.groupId, required this.userId})
      : super(key: key);

  @override
  _InviteMemberScreenState createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends State<InviteMemberScreen> {
  List<Map<String, dynamic>> friends = [];
  List<Map<String, dynamic>> filteredFriends = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  late IO.Socket socket;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _searchController.addListener(_filterFriends);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    final url = Uri.parse(
        '${widget.baseUrl}/api/friends/invitefriends/${widget.userId}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          friends = data.map((friend) {
            return {
              'id': friend['id'],
              'username': friend['username'],
            };
          }).toList();
          filteredFriends = friends;
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load friends');
      }
    } catch (e) {
      print('Error loading friends: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _filterFriends() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredFriends = friends
          .where((friend) => friend['username'].toLowerCase().contains(query))
          .toList();
    });
  }

  Future<void> _addToGroup(String friendId) async {
    final url = Uri.parse('${widget.baseUrl}/api/groups/add-member');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'groupId': widget.groupId,
          'userId': friendId,
        }),
      );

      if (response.statusCode == 200) {
        socket = SocketManager(Config.apiBaseUrl).getSocket();
        socket.emit('groupUpdated', {'userId': friendId});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${friendId} to group')),
        );
      } else {
        final error =
            jsonDecode(response.body)['error'] ?? 'Failed to add member';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    } catch (e) {
      print('Error adding member to group: $e');
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
            bottom: 10,
          ), // Thêm margin xung quanh AppBar
          child: AppBar(
            title: Row(
              children: [
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Invite Members',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.transparent, // Nền trong suốt
            elevation: 0, // Xóa bóng đổ mặc định của AppBar
            flexibleSpace: Stack(
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
          ),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search Friends',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredFriends.length,
                    itemBuilder: (context, index) {
                      final friend = filteredFriends[index];
                      return ListTile(
                        title: Text(friend['username']),
                        trailing: ElevatedButton(
                          onPressed: () => _addToGroup(friend['id']),
                          child: Text('Add to Group'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
