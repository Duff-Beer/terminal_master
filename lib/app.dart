import 'package:flutter/material.dart';
import 'theme.dart';
import 'pages/main_page.dart';

class MyApp extends StatelessWidget {
  final String configDirectoryPath;
  final String displayPath;

  const MyApp(
      {super.key,
      required this.configDirectoryPath,
      required this.displayPath});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Terminal Master',
      theme: buildDarkTheme(),
      home: MainPage(
        configDirectoryPath: configDirectoryPath,
        displayPath: displayPath,
      ),
    );
  }
}
