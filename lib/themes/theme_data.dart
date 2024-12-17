// Định nghĩa ThemeData (Light và Dark)
import 'package:flutter/material.dart';

ThemeData lightTheme = ThemeData(
  primarySwatch: Colors.blue,
  brightness: Brightness.light,
);

ThemeData darkTheme = ThemeData(
  primarySwatch: Colors.blue,
  brightness: Brightness.dark,
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.grey[900],
  ),
  scaffoldBackgroundColor: Color.fromARGB(255, 39, 39, 39), // Màu nền toàn bộ màn hình trong chế độ tối (không phải màu đen)
);