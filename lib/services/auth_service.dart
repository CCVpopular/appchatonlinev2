import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/config.dart';

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
      return jsonDecode(response.body);
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
  Future<void> saveLoginState(String userId, String username, bool rememberMe) async {
    await _initPrefs();
    if (rememberMe) {
      await _prefs?.setBool('isLoggedIn', true);
      await _prefs?.setString('userId', userId);
      await _prefs?.setString('username', username);
    }
  }

  // Kiểm tra trạng thái đăng nhập
  Future<Map<String, String>?> checkLoginState() async {
    await _initPrefs();
    final isLoggedIn = _prefs?.getBool('isLoggedIn') ?? false;
    if (isLoggedIn) {
      return {
        'userId': _prefs?.getString('userId') ?? '',
        'username': _prefs?.getString('username') ?? '',
      };
    }
    return null;
  }

  // Đăng xuất
  Future<void> logout() async {
    await _initPrefs();
    await _prefs?.clear();
  }
}
