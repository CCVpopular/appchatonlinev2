import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../config/config.dart';
import 'package:appchatonline/utils/preferences.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String username;
  final String userId;

  const SettingsScreen({Key? key, required this.username, required this.userId}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.apiBaseUrl}/api/users/profile/${widget.userId}'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          avatarUrl = data['avatar'];
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
    }
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Config.apiBaseUrl}/api/users/upload-avatar'),
      );

      request.fields['userId'] = widget.userId;
      request.files.add(await http.MultipartFile.fromPath(
        'avatar',
        image.path,
      ));

      try {
        final response = await request.send();
        final responseData = await response.stream.bytesToString();
        final jsonData = jsonDecode(responseData);

        if (response.statusCode == 200) {
          setState(() {
            avatarUrl = jsonData['avatarUrl'];
          });
        }
      } catch (e) {
        print('Error uploading avatar: $e');
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    final authService = AuthService();
    await authService.logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ValueNotifier<ThemeMode>>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _pickAndUploadImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                child: avatarUrl == null ? Icon(Icons.person, size: 50) : null,
              ),
            ),
            TextButton(
              onPressed: _pickAndUploadImage,
              child: Text('Change Avatar'),
            ),
            Text(
              'User Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text('Username: ${widget.username}'),
            Text('User ID: ${widget.userId}'),
            SizedBox(height: 20),
            Divider(),
            ListTile(
              leading: Icon(Icons.brightness_6),
              title: Text('Theme'),
              subtitle: Text('Select light or dark theme'),
              trailing: DropdownButton<ThemeMode>(
                value: themeNotifier.value,
                items: [
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Light'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text('Dark'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('System'),
                  ),
                ],
                onChanged: (mode) {
                  if (mode != null) {
                    themeNotifier.value = mode;
                    Preferences.saveThemeMode(mode);
                  }
                },
              ),
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
    );
  }
}
