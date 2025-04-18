import 'package:flutter/material.dart';

ThemeData buildDarkTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.black,
    canvasColor: Colors.black,
    fontFamily: 'Courier',
    iconTheme: const IconThemeData(color: Colors.green),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.green,
        fontFamily: 'Courier',
        fontSize: 20,
      ),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Colors.green, fontFamily: 'Courier'),
      bodySmall: TextStyle(color: Colors.green, fontFamily: 'Courier'),
      bodyLarge: TextStyle(color: Colors.green, fontFamily: 'Courier'),
      titleMedium: TextStyle(color: Colors.green, fontFamily: 'Courier'),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      fillColor: Colors.black,
      filled: true,
      hintStyle: TextStyle(color: Colors.green),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.green),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.green, width: 2),
      ),
    ),
    colorScheme: const ColorScheme.dark(
      primary: Colors.green,
      secondary: Colors.green,
      surface: Colors.black,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: Colors.green,
    ),
  );
}
