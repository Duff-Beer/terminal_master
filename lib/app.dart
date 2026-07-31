import 'package:flutter/material.dart';
import 'services/terminal_backend.dart';
import 'theme.dart';
import 'pages/main_page.dart';

class MyApp extends StatelessWidget {
  final String configDirectoryPath;
  final String displayPath;
  final TerminalBackendFactory terminalBackendFactory;

  const MyApp({
    super.key,
    required this.configDirectoryPath,
    required this.displayPath,
    this.terminalBackendFactory = unavailableTerminalBackendFactory,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Terminal Master',
      theme: buildDarkTheme(),
      home: MainPage(
        configDirectoryPath: configDirectoryPath,
        displayPath: displayPath,
        terminalBackendFactory: terminalBackendFactory,
      ),
    );
  }
}
