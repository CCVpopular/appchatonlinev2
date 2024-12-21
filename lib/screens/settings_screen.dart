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

  const SettingsScreen({Key? key, required this.username, required this.userId})
      : super(key: key);

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
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70), // Điều chỉnh chiều cao của AppBar
        child: Container(
          margin: EdgeInsets.only(
              top: 0,
              left: 10,
              right: 10,
              bottom: 10), // Thêm margin xung quanh AppBar
          child: AppBar(
            title: Padding(
              padding: EdgeInsets.only(
                  left: 15, bottom: 15), // Thêm padding cho tiêu đề
              child: const Text(
                'Settings',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            backgroundColor: Colors.transparent, // Nền trong suốt
            elevation: 0, // Xóa bóng đổ mặc định của AppBar
            flexibleSpace: Stack(
              // Sử dụng Stack để chồng các phần nền
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
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Stack(
          children: [
            // Nền thứ nhất thong tin nguoi dung (ở dưới cùng)
            Positioned(
              top: 30,
              left: 30,
              right: 0,
              bottom: 280,
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
              top: 10, // Điều chỉnh vị trí của nền thứ hai
              left: 10,
              right: 10,
              bottom: 290,
              child: Container(
                height: 200, // Đặt chiều cao cho nền thứ hai
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Color.fromARGB(
                          255, 77, 68, 89) // Nền xám nhẹ khi chế độ tối
                      : Color.fromARGB(
                          255, 255, 255, 255), // Nền trắng khi chế độ sáng
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
            //nen thu ba chua setting chon dark light mode
            Positioned(
              top: 370,
              left: 30,
              right: 0,
              bottom: 90,
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
            //nen thu tu setting chon dark light mode
            Positioned(
              top: 350, // Điều chỉnh vị trí của nền thứ hai
              left: 10,
              right: 10,
              bottom: 100,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Color.fromARGB(
                          255, 77, 68, 89) // Nền xám nhẹ khi chế độ tối
                      : Color.fromARGB(
                          255, 255, 255, 255), // Nền trắng khi chế độ sáng
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
            // Các phần tử trong body (avatar và thông tin người dùng)
            Positioned(
              top: 60, // Điều chỉnh vị trí phần nội dung bên trong
              left: 0,
              right: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _pickAndUploadImage,
                    child: Builder(
                      builder: (context) {
                        // Kiểm tra chế độ nền
                        bool isDarkMode =
                            Theme.of(context).brightness == Brightness.dark;

                        return Container(
                          padding: EdgeInsets.all(2), // Điều chỉnh độ dày viền
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDarkMode
                                ? Colors.white
                                : Colors.black, // Màu viền thay đổi theo nền
                          ),
                          child: CircleAvatar(
                            radius: 50, // Giảm kích thước để thêm padding
                            backgroundImage: avatarUrl != null
                                ? NetworkImage(avatarUrl!)
                                : null,
                            child: avatarUrl == null
                                ? Icon(Icons.person,
                                    size:
                                        48) // Kích thước icon phù hợp với avatar nhỏ hơn
                                : null,
                          ),
                        );
                      },
                    ),
                  ),

                  TextButton(
                    onPressed: _pickAndUploadImage,
                    child: Text('Change Avatar'),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'User Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text('Username: ${widget.username}'),
                  Text('User ID: ${widget.userId}'),
                  SizedBox(height: 60),
                  // Divider(),
                  ListTile(
                    leading: Padding(
                      padding:
                          EdgeInsets.only(left: 20), // Dời biểu tượng sang trái
                      child: Icon(Icons.brightness_6),
                    ),
                    title: Padding(
                      padding:
                          EdgeInsets.only(left: 0), // Dời tiêu đề sang trái
                      child: Text('Theme'),
                    ),
                    subtitle: Padding(
                      padding:
                          EdgeInsets.only(left: 0), // Dời subtitle sang trái
                      child: Text('Select light or dark theme'),
                    ),
                    trailing: Padding(
                      padding: EdgeInsets.only(left: 10), // Dời phần dropdown sang trái
                      child: DropdownButton<ThemeMode>(
                        value: themeNotifier.value,
                        items: [
                          DropdownMenuItem(
                            value: ThemeMode.light,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                    10), // Bo tròn góc của mục
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color.fromARGB(
                                        255, 0, 0, 0) // Màu nền khi chế độ tối
                                    : Colors.white, // Màu nền khi chế độ sáng
                                border: Border.all(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors
                                          .white // Màu viền trắng khi chế độ tối
                                      : Colors
                                          .black, // Màu viền đen khi chế độ sáng
                                  width: 2, // Độ dày viền
                                ),
                              ),
                              padding: EdgeInsets.all(8.0), // Padding cho mục
                              child: Text(
                                'Light',
                                style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white // Màu chữ khi chế độ tối
                                      : Colors.black, // Màu chữ khi chế độ sáng
                                ),
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.dark,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                    10), // Bo tròn góc của mục
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.black // Màu nền khi chế độ tối
                                    : Colors.white, // Màu nền khi chế độ sáng
                                border: Border.all(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors
                                          .white // Màu viền trắng khi chế độ tối
                                      : Colors
                                          .black, // Màu viền đen khi chế độ sáng
                                  width: 2, // Độ dày viền
                                ),
                              ),
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Dark',
                                style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.system,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                    10), // Bo tròn góc của mục
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.black
                                    : Colors.white,
                                border: Border.all(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                  width: 2, // Độ dày viền
                                ),
                              ),
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'System',
                                style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (mode) {
                          if (mode != null) {
                            themeNotifier.value = mode;
                            Preferences.saveThemeMode(mode);
                          }
                        },
                        dropdownColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.black
                                : Colors.white, // Màu nền của bảng xổ
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black, // Màu văn bản trong dropdown
                        ),
                        underline: Container(), // Ẩn viền dưới
                        icon: null, // Kích thước biểu tượng mũi tên xổ xuống
                        iconSize: 0,
                      ),
                    ),
                  ),

                  // Divider(),
                  SizedBox(height: 10),
                  ListTile(
                    leading: Padding(
                      padding:
                          EdgeInsets.only(left: 20.0), // Padding riêng cho icon
                      child: Icon(
                        Icons.logout,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Color.fromARGB(
                                255, 255, 124, 115) // Màu icon khi chế độ tối
                            : Color.fromARGB(
                                255, 166, 39, 0), // Màu icon khi chế độ sáng
                      ),
                    ),
                    title: Padding(
                      padding:
                          EdgeInsets.only(left: 8.0), // Padding riêng cho text
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.start, // Căn chỉnh chữ bên trái
                        children: [
                          Text(
                            'Logout',
                            style: TextStyle(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Color.fromARGB(255, 255, 124,
                                      115) // Màu chữ khi chế độ tối
                                  : Color.fromARGB(255, 166, 39,
                                      0), // Màu chữ khi chế độ sáng
                              fontWeight: FontWeight.bold, // Chữ đậm
                            ),
                          ),
                        ],
                      ),
                    ),
                    onTap: () => _logout(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
