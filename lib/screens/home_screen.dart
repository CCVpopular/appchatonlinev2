import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
        page = SettingsScreen(username: "text", userId: widget.userId);
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
            return Column(
              children: [
                Expanded(child: mainArea),
                SafeArea(
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Color.fromARGB(
                                  72, 184, 142, 233) // Màu nền tối: tăng độ rõ
                              : Color.fromARGB(100, 194, 164,
                                  204), // Màu nền sáng: tăng độ sáng và rõ hơn
                          // Màu nền sáng
                          border: Border.all(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white // Viền trắng khi chế độ tối
                                    : Colors.black, // Viền đen khi chế độ sáng
                            width: 2, // Độ dày viền
                          ),
                          borderRadius:
                              BorderRadius.circular(30), // Bo góc nhẹ hơn
                        ),
                        padding: EdgeInsets.symmetric(
                            vertical: 10, horizontal: 10), // Padding trên dưới
                        margin: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10), // Margin bên ngoài
                        child: Material(
                          elevation:
                              0, // Tạo hiệu ứng nổi cho toàn bộ BottomNavigationBar
                          color: Colors.transparent, // Đảm bảo nền trong suốt
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                                30), // Bo góc cho cả BottomNavigationBar
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
                              selectedItemColor: colorScheme
                                  .primary, // Màu của icon khi được chọn
                              unselectedItemColor:
                                  colorScheme.onSurface.withOpacity(0.6),
                              backgroundColor: null, // Bỏ nền mặc định
                              showSelectedLabels:
                                  true, // Hiển thị nhãn khi chọn
                              showUnselectedLabels:
                                  false, // Ẩn nhãn khi không chọn
                              onTap: (value) {
                                setState(() {
                                  selectedIndex = value;
                                });
                              },
                              selectedLabelStyle: TextStyle(
                                fontWeight:
                                    FontWeight.bold, // Làm đậm label khi chọn
                              ),
                              unselectedLabelStyle: TextStyle(
                                fontWeight: FontWeight
                                    .normal, // Làm mờ label khi không chọn
                              ),
                              iconSize: 30, // Chỉnh kích thước icon
                              selectedFontSize:
                                  14, // Chỉnh kích thước font khi chọn
                              unselectedFontSize:
                                  12, // Chỉnh kích thước font khi không chọn
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          } else {
            return Row(
              children: [
                SafeArea(
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
                      color: colorScheme.primary, // Màu của icon khi được chọn
                      size: 30, // Kích thước lớn hơn khi chọn
                    ),
                    unselectedIconTheme: IconThemeData(
                      color: colorScheme.onSurface
                          .withOpacity(0.6), // Màu của icon khi không chọn
                      size: 28, // Kích thước nhỏ hơn khi không chọn
                    ),
                    backgroundColor: colorScheme.surface,
                    onDestinationSelected: (value) {
                      setState(() {
                        selectedIndex = value;
                      });
                    },
                    labelType:
                        NavigationRailLabelType.none, // Ẩn nhãn khi không chọn
                    selectedLabelTextStyle: TextStyle(
                      fontWeight: FontWeight.bold, // Làm đậm nhãn khi chọn
                    ),
                    unselectedLabelTextStyle: TextStyle(
                      fontWeight:
                          FontWeight.normal, // Làm mờ nhãn khi không chọn
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
