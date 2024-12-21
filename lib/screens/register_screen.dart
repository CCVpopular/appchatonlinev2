import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatelessWidget {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

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
              bottom: 10), // Thêm margin xung quanh AppBar
          child: AppBar(
            title: Padding(
              padding: EdgeInsets.only(
                  left: 15, bottom: 15), // Thêm padding cho tiêu đề
              child: const Text(
                'Register',
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
      body: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(
              top: 10.0, left: 10.0, right: 10.0), // Đẩy lên trên
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[900] // Màu nền tối
                : Colors.white, // Màu nền sáng
            borderRadius: BorderRadius.circular(16.0), // Bo góc
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white // Viền trắng khi chế độ tối
                  : Colors.black, // Viền đen khi chế độ sáng
              width: 2, // Độ dày viền
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // TextField cho Username
              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black, // Viền theo sáng/tối
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color.fromARGB(255, 148, 92, 208)
                          : const Color.fromARGB(
                              129, 114, 33, 243), // Viền xanh khi focus
                      width: 4.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // TextField cho Password
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black, // Viền theo sáng/tối
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color.fromARGB(255, 148, 92, 208)
                          : const Color.fromARGB(
                              129, 117, 33, 243), // Viền xanh khi focus
                      width: 4.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ElevatedButton cho Register
              ElevatedButton(
                onPressed: () async {
                  try {
                    final authService = AuthService();
                    await authService.register(
                      usernameController.text,
                      passwordController.text,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Registration successful!')),
                    );
                    Navigator.pop(context); // Quay lại màn hình đăng nhập
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Registration failed: $e')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? const Color.fromARGB(
                              255, 81, 17, 119) // Màu nền khi chế độ tối
                          : const Color.fromARGB(
                              69, 184, 152, 243), // Màu nền khi chế độ sáng
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), // Bo tròn góc
                    side: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white // Viền trắng khi chế độ tối
                          : Colors.black, // Viền đen khi chế độ sáng
                      width: 2, // Độ dày viền
                    ),
                  ),
                ),
                child: Text(
                  'Register',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white // Màu chữ trắng khi chế độ tối
                        : const Color.fromARGB(
                            154, 0, 0, 0), // Màu chữ đen khi chế độ sáng
                    fontWeight: FontWeight.bold, // Tạo chữ đậm
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
