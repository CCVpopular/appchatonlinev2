import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/config.dart';
import '../screens/chatbot_screen.dart';
import '../screens/settings_screen.dart';
import 'friends_screen.dart';
import 'groups_screen.dart';

class MyHomePage extends StatefulWidget {
  final String userId;

  const MyHomePage({Key? key, required this.userId}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;
  String username = '';

  @override
  void initState() {
    super.initState();
    _fetchUsername();
  }

  Future<void> _fetchUsername() async {
    try {
      final response = await http.get(
        Uri.parse('${Config.apiBaseUrl}/api/users/profile/${widget.userId}'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          username = data['username'];
        });
      }
    } catch (e) {
      print('Error fetching username: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    var colorScheme = Theme.of(context).colorScheme;

    Widget page;
    switch (selectedIndex) {
      case 0:
        page = FriendsScreen(userId: widget.userId);
        break;
      case 1:
        page = GroupsScreen(userId: widget.userId);
        break;
      case 2:
        page = ChatBotScreen();
        break;
      case 3:
        page = SettingsScreen(username: username, userId: widget.userId);
        break;
      default:
        throw UnimplementedError('No widget for $selectedIndex');
    }

    var mainArea = ColoredBox(
      color: colorScheme.background, // Sử dụng màu nền từ theme
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 200),
        child: page,
      ),
    );

    return Scaffold(
  body: LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 450) {
        // Cho phép điều chỉnh ở màn hình nhỏ hơn
        return Column(
          children: [
            Expanded(child: mainArea),
            Padding(
              padding: const EdgeInsets.all(0),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Color.fromARGB(72, 184, 142, 233) // Màu nền tối
                      : Color.fromARGB(100, 194, 164, 204), // Màu nền sáng
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black, // Viền trắng khi chế độ tối
                    width: 2, // Độ dày viền
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                margin: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Material(
                  elevation: 0, // Không có hiệu ứng nổi
                  color: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BottomNavigationBar(
                      items: [
                        BottomNavigationBarItem(
                          icon: _buildIcon(Icons.home, 0),
                          label: 'Friend',
                        ),
                        BottomNavigationBarItem(
                          icon: _buildIcon(Icons.group, 1),
                          label: 'Group',
                        ),
                        BottomNavigationBarItem(
                          icon: _buildIcon(Icons.chat, 2),
                          label: 'Chat Bot',
                        ),
                        BottomNavigationBarItem(
                          icon: _buildIcon(Icons.settings, 3),
                          label: 'Setting',
                        ),
                      ],
                      currentIndex: selectedIndex,
                      selectedItemColor: colorScheme.primary,
                      unselectedItemColor: colorScheme.onSurface.withOpacity(0.6),
                      backgroundColor: null,
                      showSelectedLabels: true,
                      showUnselectedLabels: false,
                      onTap: (value) {
                        setState(() {
                          selectedIndex = value;
                        });
                      },
                      selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
                      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal),
                      iconSize: 30,
                      selectedFontSize: 14,
                      unselectedFontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      } else {
        return Row(
          children: [
            Expanded(
              child: SafeArea(
                child: NavigationRail(
                  extended: constraints.maxWidth >= 600,
                  destinations: [
                    NavigationRailDestination(
                      icon: _buildIcon(Icons.home, 0),
                      label: Text('Friend'),
                    ),
                    NavigationRailDestination(
                      icon: _buildIcon(Icons.group, 1),
                      label: Text('Group'),
                    ),
                    NavigationRailDestination(
                      icon: _buildIcon(Icons.chat, 2),
                      label: Text('Chat Bot'),
                    ),
                    NavigationRailDestination(
                      icon: _buildIcon(Icons.settings, 3),
                      label: Text('Setting'),
                    ),
                  ],
                  selectedIndex: selectedIndex,
                  selectedIconTheme: IconThemeData(
                    color: colorScheme.primary,
                    size: 30,
                  ),
                  unselectedIconTheme: IconThemeData(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    size: 28,
                  ),
                  backgroundColor: colorScheme.surface,
                  onDestinationSelected: (value) {
                    setState(() {
                      selectedIndex = value;
                    });
                  },
                  labelType: NavigationRailLabelType.none,
                  selectedLabelTextStyle: TextStyle(fontWeight: FontWeight.bold),
                  unselectedLabelTextStyle: TextStyle(fontWeight: FontWeight.normal),
                ),
              ),
            ),
            Expanded(child: mainArea),
          ],
        );
      }
    },
  ),
);

  }

  // Hàm tạo icon với hiệu ứng bóng, không có chữ trong vòng tròn
  Widget _buildIcon(IconData icon, int index) {
    var isSelected = selectedIndex == index;
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      transform: isSelected
          ? Matrix4.translationValues(0, -5, 0)
          : Matrix4.identity(), // Lệch lên khi chọn
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent, // Nền tròn trong suốt
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white // Viền trắng khi chế độ tối
              : Colors.black, // Viền đen khi chế độ sáng
          width: 2, // Độ dày viền
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color:
                      const Color.fromARGB(255, 209, 182, 221).withOpacity(0.4),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                )
              ]
            : [],
      ),
      padding: EdgeInsets.all(
          isSelected ? 12 : 10), // Thêm khoảng cách cho viền khi chọn
      child: ClipOval(
        child: Container(
          color: isSelected
              ? Theme.of(context)
                  .colorScheme
                  .primary
                  .withOpacity(0.1) // Tạo nền mờ khi chọn
              : Colors.transparent, // Không có nền khi không chọn
          child: Icon(
            icon,
            size: isSelected
                ? 30
                : 24, // Kích thước của icon khi chọn và không chọn
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ),
    );
  }
}
