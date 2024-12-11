import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../firebase_options.dart';
import '../screens/home_screen.dart';
import '../screens/loading_screen.dart';
import '../screens/login_screen.dart';

class StartupService {
  static SharedPreferences? _prefs;
  static bool _initialized = false;
  static late final Completer<void> _initializer = Completer<void>();

  static Future<Widget> initialize() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      
      unawaited(_initializeFirebase());
      
      _initialized = true;
    }

    final isLoggedIn = _prefs?.getBool('isLoggedIn') ?? false;
    final userId = _prefs?.getString('userId') ?? '';

    if (isLoggedIn && userId.isNotEmpty) {
      return _lazyLoadHome(userId);
    }
    return _lazyLoadLogin();
  }

  static Future<void> _initializeFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _initializer.complete();
    } catch (e) {
      _initializer.completeError(e);
    }
  }

  static Widget _lazyLoadHome(String userId) {
    return FutureBuilder(
      future: _initializer.future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return MyHomePage(userId: userId);
        }
        return const LoadingScreen();
      },
    );
  }

  static Widget _lazyLoadLogin() {
    return LoginScreen();
  }
}