import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/config.dart';
import 'SocketManager.dart';

class AuthService {
  final String baseUrl = Config.apiBaseUrl;

  static AuthService? _instance;
  static SharedPreferences? _prefs;

  factory AuthService() {
    _instance ??= AuthService._();
    return _instance!;
  }

  AuthService._();

  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      // Set user status to online after successful login
      await updateUserStatus(responseData['userId'], 'online');
      return responseData;
    } else {
      throw Exception('Failed to login');
    }
  }

  Future<void> register(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to register: ${response.body}');
    }
  }

  // Lưu trạng thái đăng nhập
  Future<void> saveLoginState(
      String userId, String username, String role, bool rememberMe) async {
    final prefs = await SharedPreferences.getInstance();
    // Always save userId regardless of rememberMe
    await prefs.setString('userId', userId);

    if (rememberMe) {
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('username', username);
      await prefs.setString('role', role);
    }
  }

  // Kiểm tra trạng thái đăng nhập
  Future<Map<String, String>?> checkLoginState() async {
    await _initPrefs();
    final isLoggedIn = _prefs?.getBool('isLoggedIn') ?? false;
    if (isLoggedIn) {
      final userId = _prefs?.getString('userId') ?? '';
      final username = _prefs?.getString('username') ?? '';
      final role = _prefs?.getString('role') ?? 'user';
      return {'userId': userId, 'username': username, 'role': role};
    }
    return null;
  }

  // Đăng xuất
  Future<void> logout() async {
    try {
      await _initPrefs();
      final userId = _prefs?.getString('userId');
      print('=== Starting logout process ===');
      print('User ID: $userId');

      if (userId == null || userId.isEmpty) {
        print('No user ID found in preferences');
        await _prefs?.clear();
        return;
      }

      // Set status to offline
      print('Setting status to offline...');
      final statusResult = await updateUserStatus(userId, 'offline');
      if (!statusResult) {
        print('Warning: Failed to update status to offline');
      }

      // Close socket connections
      print('Closing socket connections...');
      await _closeConnections();

      // Clear preferences
      print('Clearing preferences...');
      await _prefs?.clear();

      print('=== Logout completed ===');
    } catch (e) {
      print('Error during logout: $e');
      // Ensure preferences are cleared even if there's an error
      await _prefs?.clear();
    }
  }

  Future<void> _emergencyLogout() async {
    try {
      print('Performing emergency logout cleanup');
      final userId = _prefs?.getString('userId');
      if (userId != null) {
        await updateUserStatus(userId, 'offline');
      }
      await _closeConnections();
      await _prefs?.clear();
      print('Emergency logout completed');
    } catch (e) {
      print('Emergency logout failed: $e');
    }
  }

  Future<void> _closeConnections() async {
    try {
      // Add any cleanup code for sockets or other connections
      final socketManager = SocketManager(Config.apiBaseUrl);
      await socketManager.disconnect();
    } catch (e) {
      print('Error closing connections: $e');
    }
  }

  Future<bool> updateUserStatus(String userId, String status) async {
    print('Starting status update for user $userId to $status');

    for (int i = 0; i < 3; i++) {
      try {
        print('Attempt ${i + 1}: Updating status');
        final response = await http.put(
          Uri.parse('$baseUrl/api/users/status/$userId'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'status': status,
            'timestamp': DateTime.now().toIso8601String(),
          }),
        );

        print('Response code: ${response.statusCode}');
        print('Response body: ${response.body}');

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          if (responseData['success'] == true) {
            print('✓ Status successfully updated to: $status');
            return true;
          }
        }

        // Parse error message if available
        String errorMessage = 'Unknown error';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? errorMessage;
        } catch (_) {}

        print('✗ Status update failed: $errorMessage');

        // Wait before retry
        if (i < 2) {
          await Future.delayed(Duration(milliseconds: 1000 * (i + 1)));
        }
      } catch (e) {
        print('✗ Network error in attempt ${i + 1}: $e');
        if (i < 2) {
          await Future.delayed(Duration(milliseconds: 1000 * (i + 1)));
        }
      }
    }

    print('All status update attempts failed');
    return false;
  }
}
