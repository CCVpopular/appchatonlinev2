import 'package:flutter/material.dart';
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
                  child: BottomNavigationBar(
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.home),
                        label: 'Friend',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.group),
                        label: 'Group',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.chat),
                        label: 'Chat Bot',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.settings),
                        label: 'Setting',
                      ),
                    ],
                    currentIndex: selectedIndex,
                    selectedItemColor: colorScheme.primary, // Áp dụng màu từ theme
                    unselectedItemColor: colorScheme.onSurface.withOpacity(0.6),
                    backgroundColor: colorScheme.surface, // Màu nền từ theme
                    onTap: (value) {
                      setState(() {
                        selectedIndex = value;
                      });
                    },
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
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.home),
                        label: Text('Friend'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.group),
                        label: Text('Group'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.chat),
                        label: Text('Chat Bot'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.settings),
                        label: Text('Setting'),
                      ),
                    ],
                    selectedIndex: selectedIndex,
                    selectedIconTheme: IconThemeData(color: colorScheme.primary),
                    unselectedIconTheme: IconThemeData(color: colorScheme.onSurface.withOpacity(0.6)),
                    backgroundColor: colorScheme.surface,
                    onDestinationSelected: (value) {
                      setState(() {
                        selectedIndex = value;
                      });
                    },
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
}
