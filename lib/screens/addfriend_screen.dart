import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/config.dart';

class AddFriendScreen extends StatefulWidget {
  final String userId;
  final String baseUrl = Config.apiBaseUrl;

  const AddFriendScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _AddFriendScreenState createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];
  bool isLoading = false;

  // Hàm tìm kiếm bạn bè
  Future<void> _searchUsers(String username) async {
    if (username.isEmpty) return;
    setState(() {
      isLoading = true;
    });

    try {
      final url = Uri.parse('${widget.baseUrl}/api/users/search/$username');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          searchResults = data
              .map((user) => {
                    'id': user['_id'],
                    'username': user['username'],
                  })
              .toList();
          isLoading = false;
        });
      } else {
        throw Exception('Failed to search users');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error searching users: $e');
    }
  }

  // Hàm gửi yêu cầu kết bạn
  Future<void> _sendFriendRequest(String receiverId) async {
    try {
      final url = Uri.parse('${widget.baseUrl}/api/friends/add-friend');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requesterId': widget.userId,
          'receiverId': receiverId,
        }),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Friend request sent!')),
        );
      } else {
        final error = jsonDecode(response.body)['error'] ??
            'Failed to send friend request';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending friend request: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70), // Điều chỉnh chiều cao của AppBar
        child: Container(
          margin: EdgeInsets.only(top: 0, left: 10, right: 10, bottom: 10),
          child: AppBar(
            title: Padding(
              padding: EdgeInsets.only(left: 0, bottom: 0), // Vị trí tiêu đề
              child: const Text(
                'Add Friend',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            backgroundColor: Colors.transparent, // Nền trong suốt
            elevation: 0, // Xóa bóng đổ mặc định của AppBar
            flexibleSpace: Stack(
              children: [
                // Nền gradient
                Positioned(
                  top: 20,
                  left: 20,
                  right: 0,
                  bottom: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Color.fromARGB(255, 57, 51, 66)
                          : Color.fromARGB(77, 83, 32, 120),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                // Lớp nền trắng hoặc tối chồng lên
                Positioned(
                  top: 5,
                  left: 5,
                  right: 8,
                  bottom: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Color.fromARGB(255, 77, 68, 89)
                          : Color.fromARGB(255, 255, 255, 255),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Color.fromARGB(255, 33, 33, 33) // Nền tối
                    : Color.fromARGB(255, 255, 255, 255), // Nền sáng
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
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search by username',
                            border: InputBorder.none, // Xóa viền của TextField
                          ),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Color.fromARGB(107, 128, 83, 180)
                            : Color.fromARGB(255, 255, 255, 255),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                          width: 2,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.search),
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color.fromARGB(255, 255, 255, 255)
                            : const Color.fromARGB(255, 103, 48, 129),
                        onPressed: () => _searchUsers(_searchController.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          isLoading
              ? Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              : Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(
                        10), // Padding cho viền bao quanh toàn bộ ListView
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Color.fromARGB(255, 33, 33, 33) // Nền tối
                            : Color.fromARGB(255, 255, 255, 255), // Nền sáng
                        borderRadius: BorderRadius.circular(25), // Viền bo tròn
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white // Viền trắng khi chế độ tối
                              : Colors.black, // Viền đen khi chế độ sáng
                          width: 2, // Độ dày viền
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.black.withOpacity(
                                        0.4) // Bóng mờ tối khi chế độ tối
                                    : Colors.grey.withOpacity(
                                        0.2), // Bóng mờ sáng khi chế độ sáng
                            blurRadius: 8, // Độ mờ của bóng
                            spreadRadius: 3, // Phạm vi bóng
                            offset: Offset(0, 4), // Định vị bóng
                          ),
                        ],
                      ),
                      child: ListView.builder(
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final user = searchResults[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10.0,
                                horizontal: 10), // Padding cho từng phần tử
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Color.fromARGB(255, 33, 33, 33) // Nền tối
                                    : Color.fromARGB(
                                        255, 255, 255, 255), // Nền sáng
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors
                                          .white // Viền trắng khi chế độ tối
                                      : Colors
                                          .black, // Viền đen khi chế độ sáng
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Color.fromARGB(
                                            72, 184, 142, 233) // Bóng nền tối
                                        : Color.fromARGB(100, 194, 164,
                                            204), // Bóng nền sáng
                                    blurRadius: 5, // Độ mờ của bóng
                                    spreadRadius: 5, // Phạm vi bóng
                                    offset: Offset(0, 4), // Định vị bóng
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(left: 15),
                                        child: Text(
                                          user[
                                              'username'], // Hiển thị tên người dùng
                                          style: TextStyle(
                                            fontSize: 16,
                                            color:
                                                Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? Colors.white
                                                    : Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Color.fromARGB(107, 128, 83, 180)
                                            : Color.fromARGB(58, 211, 200, 219),
                                        border: Border.all(
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : Colors.black,
                                          width: 2,
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? Color.fromARGB(72,184,142,233) // Bóng nền tối
                                                    : Color.fromARGB(100,194,164,204), // Bóng nền sáng
                                            blurRadius: 8, // Độ mờ của bóng
                                            spreadRadius: 3, // Phạm vi bóng
                                            offset:
                                                Offset(0, 2), // Định vị bóng
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        icon: Icon(Icons.person_add),
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color.fromARGB(
                                                255, 255, 255, 255)
                                            : const Color.fromARGB(
                                                255, 103, 48, 129),
                                        onPressed: () =>
                                            _sendFriendRequest(user['id']),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
