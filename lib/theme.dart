import 'package:flutter/material.dart';

abstract final class TerminalMasterColors {
  static const background = Color(0xff07111e);
  static const surface = Color(0xff0b1b2b);
  static const surfaceRaised = Color(0xff10263a);
  static const border = Color(0xff31506d);
  static const muted = Color(0xff52677d);
  static const foreground = Color(0xffdceaf4);
  static const green = Color(0xff54f1b5);
  static const yellow = Color(0xffffc857);
  static const cyan = Color(0xff62d6e8);
  static const blue = Color(0xff63a4ff);
  static const red = Color(0xffff6b6b);
}

ThemeData buildDarkTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: TerminalMasterColors.background,
    canvasColor: TerminalMasterColors.surface,
    fontFamily: 'Courier',
    dividerColor: TerminalMasterColors.border,
    iconTheme: const IconThemeData(color: TerminalMasterColors.green),
    appBarTheme: const AppBarTheme(
      backgroundColor: TerminalMasterColors.surfaceRaised,
      foregroundColor: TerminalMasterColors.foreground,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: TerminalMasterColors.yellow,
        fontFamily: 'Courier',
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: TerminalMasterColors.foreground),
      bodySmall: TextStyle(color: TerminalMasterColors.foreground),
      bodyLarge: TextStyle(color: TerminalMasterColors.foreground),
      titleLarge: TextStyle(
        color: TerminalMasterColors.yellow,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: TextStyle(
        color: TerminalMasterColors.yellow,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        color: TerminalMasterColors.yellow,
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      fillColor: TerminalMasterColors.surface,
      filled: true,
      hintStyle: TextStyle(color: TerminalMasterColors.muted),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: TerminalMasterColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: TerminalMasterColors.green, width: 2),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: TerminalMasterColors.green,
      textColor: TerminalMasterColors.foreground,
      titleTextStyle: TextStyle(
        color: TerminalMasterColors.yellow,
        fontFamily: 'Courier',
        fontWeight: FontWeight.w600,
      ),
      subtitleTextStyle: TextStyle(
        color: TerminalMasterColors.foreground,
        fontFamily: 'Courier',
      ),
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: TerminalMasterColors.green,
      collapsedIconColor: TerminalMasterColors.green,
      textColor: TerminalMasterColors.yellow,
      collapsedTextColor: TerminalMasterColors.yellow,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: TerminalMasterColors.green,
      selectionColor: Color(0x663b82f6),
      selectionHandleColor: TerminalMasterColors.green,
    ),
    colorScheme: const ColorScheme.dark(
      primary: TerminalMasterColors.green,
      secondary: TerminalMasterColors.cyan,
      tertiary: TerminalMasterColors.yellow,
      surface: TerminalMasterColors.surface,
      error: TerminalMasterColors.red,
      onPrimary: TerminalMasterColors.background,
      onSecondary: TerminalMasterColors.background,
      onTertiary: TerminalMasterColors.background,
      onSurface: TerminalMasterColors.foreground,
      onError: TerminalMasterColors.background,
      outline: TerminalMasterColors.border,
    ),
  );
}
