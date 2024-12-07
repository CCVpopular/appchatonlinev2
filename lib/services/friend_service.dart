import 'dart:async';
import 'dart:convert';
import 'package:appchatonline/services/SocketManager.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../config/config.dart';

class FriendService {
  final StreamController<List<dynamic>> _friendsController =
      StreamController<List<dynamic>>.broadcast();
  Stream<List<dynamic>> get friendsStream => _friendsController.stream;
  late IO.Socket socket;

  List<dynamic> _friends = [];
  final String baseUrl = Config.apiBaseUrl;
  FriendService() {
    SocketManager(Config.apiBaseUrl);
    socket = SocketManager(Config.apiBaseUrl).getSocket();
    _connectToSocket();
  }

  void _connectToSocket() {
    socket.on('friendshipUpdated', (data) {
      if (data['status'] == 'accepted') {
        _fetchFriends(data);
      }
    });
  }

  void dispose() {
    _friendsController.close();
  }

  Future<void> getFriends(String userId) async {
    try {
      final url = Uri.parse('$baseUrl/api/friends/friends/$userId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        _friends = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        _friendsController.add(_friends);
      } else {
        throw Exception('Failed to fetch friends');
      }
    } catch (e) {
      print('Error fetching friends: $e');
      _friendsController.addError(e);
    }
  }

  void _fetchFriends(Map<String, dynamic> data) {
    // Kiểm tra xem bạn bè này đã tồn tại trong danh sách chưa
    final index = _friends.indexWhere((friend) =>
        (friend['requester'] == data['requester'] &&
            friend['receiver'] == data['receiver']) ||
        (friend['requester'] == data['receiver'] &&
            friend['receiver'] == data['requester']));

    if (index != -1) {
      // Nếu tồn tại, cập nhật thông tin
      _friends[index] = data;
    } else {
      // Nếu không, thêm vào danh sách
      _friends.add(data);
    }
    print(_friends);

    // Thông báo cập nhật tới giao diện
    _friendsController.add(List.from(
        _friends)); // Tạo một danh sách mới để StreamBuilder nhận thay đổi
  }

  // void dispose() {
  //   _socket?.dispose();
  //   _friendsController.close();
  // }
}
