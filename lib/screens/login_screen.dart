import 'dart:io';

import 'package:appchatonline/screens/home_screen.dart';
import 'package:appchatonline/screens/register_screen.dart';
import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool rememberMe = false; // Trạng thái "Ghi nhớ đăng nhập"
  bool isLoading = true; // Hiển thị trạng thái tải khi kiểm tra đăng nhập

  @override
  void initState() {
    super.initState();
    _checkLoginState(); // Kiểm tra trạng thái đăng nhập
  }

  Future<void> _checkLoginState() async {
    final authService = AuthService();
    final loginState = await authService.checkLoginState();
    if (loginState != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          // builder: (context) => FriendsScreen(userId: loginState['userId']!),
          builder: (context) => MyHomePage(userId: loginState['userId']!),
        ),
      );
    } else {
      setState(() {
        isLoading = false; // Ngừng hiển thị trạng thái tải
      });
    }
  }

  Future<void> _login() async {
    try {
      final authService = AuthService();
      final user = await authService.login(
        usernameController.text,
        passwordController.text,
      );

      // Lưu trạng thái đăng nhập nếu "Ghi nhớ đăng nhập" được chọn
      await authService.saveLoginState(
        user['userId'],
        usernameController.text,
        rememberMe,
      );
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        print(
            'FCM Token is not required for this platform'); // Không thực hiện lưu FCM Token
      } else {
        NotificationService notificationService = NotificationService();
        await notificationService.init(user['userId']);
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          // builder: (context) => FriendsScreen(userId: user['userId']),
          builder: (context) => MyHomePage(userId: user['userId']),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? Center(child: CircularProgressIndicator())
        : Scaffold(
            appBar: AppBar(title: Text('Login')),
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: usernameController,
                    decoration: InputDecoration(labelText: 'Username'),
                  ),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(labelText: 'Password'),
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: rememberMe,
                        onChanged: (value) {
                          setState(() {
                            rememberMe = value!;
                          });
                        },
                      ),
                      Text('Remember Me'),
                    ],
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _login,
                    child: Text('Login'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RegisterScreen(),
                        ),
                      );
                    },
                    child: Text('Don\'t have an account? Register'),
                  ),
                ],
              ),
            ),
          );
  }
}
