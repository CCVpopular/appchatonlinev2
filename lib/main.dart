import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/manage_users_screen.dart';
import 'package:flutter/services.dart';
import 'services/startup_service.dart';
import 'screens/loading_screen.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

Future<void> initNotifications() async {
  await AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: 'call_channel',
        channelName: 'Call Notifications',
        channelDescription: 'Notification channel for calls',
        defaultColor: Colors.purple,
        ledColor: Colors.white,
        importance: NotificationImportance.High,
        channelShowBadge: true,
        locked: true,
        defaultRingtoneType: DefaultRingtoneType.Ringtone,
      ),
    ],
    debug: true,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotifications();
  
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ),
  );

  // Load initial theme mode
  final prefs = await SharedPreferences.getInstance();
  final themeModeString = prefs.getString('theme_mode') ?? 'system';
  ThemeMode initialThemeMode;
  switch (themeModeString) {
    case 'light':
      initialThemeMode = ThemeMode.light;
      break;
    case 'dark':
      initialThemeMode = ThemeMode.dark;
      break;
    default:
      initialThemeMode = ThemeMode.system;
  }

  runApp(
    ChangeNotifierProvider<ValueNotifier<ThemeMode>>(
      create: (_) => ValueNotifier<ThemeMode>(initialThemeMode),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ValueNotifier<ThemeMode>>(context);

    return MaterialApp(
      title: 'Chat App',
      routes: {
        '/login': (context) => LoginScreen(),
        '/manage-users': (context) => ManageUsersScreen(),
      },
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        platform: TargetPlatform.android,
      ),
      darkTheme: ThemeData.dark(), // Define your dark theme here
      themeMode: themeNotifier.value,
      home: FutureBuilder(
        future: StartupService.initialize(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return snapshot.data ?? const LoadingScreen();
          }
          return const LoadingScreen();
        },
      ),
    );
  }
}
