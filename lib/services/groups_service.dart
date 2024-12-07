  import 'dart:async';
  import 'dart:convert';
  import 'package:http/http.dart' as http;
  import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../config/config.dart';
import 'SocketManager.dart';

  class GroupsService {
    final String userId;
    late IO.Socket socket;
    final _groupsStreamController = StreamController<List<Map<String, dynamic>>>.broadcast();
    final String baseUrl = Config.apiBaseUrl;

    GroupsService(this.userId) {
      _connectSocket();
      _loadGroups();
    }

    // Kết nối socket và lắng nghe sự kiện
    void _connectSocket() {
      socket = SocketManager(baseUrl).getSocket();

        print('Connected User to server');
        socket.emit('joinUser', userId); // Tham gia phòng của người dùng

      // Lắng nghe sự kiện cập nhật danh sách nhóm
      socket.on('updateGroups', (_) {
        _loadGroups(); // Tải lại danh sách nhóm
      });
    }

    // Tải danh sách nhóm từ server
    Future<void> _loadGroups() async {
      final url = Uri.parse('$baseUrl/api/groups/user-groups/$userId');
      try {
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final groups = data.map((group) {
            return {
              'id': group['_id'],
              'name': group['name'],
              'owner': group['owner'],
              'members': group['members'],
            };
          }).toList();

          _groupsStreamController.add(groups);
        } else {
          throw Exception('Failed to load groups');
        }
      } catch (e) {
        print('Error loading groups: $e');
      }
    }

  void refreshGroups() {
    // Tải lại danh sách nhóm từ API và cập nhật stream
    _loadGroups();
  }


    // Stream để lắng nghe danh sách nhóm
    Stream<List<Map<String, dynamic>>> get groupsStream => _groupsStreamController.stream;

    // Đóng socket và Stream
    void dispose() {
      socket.disconnect();
      _groupsStreamController.close();
    }
  }
