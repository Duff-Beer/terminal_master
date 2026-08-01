import 'package:flutter/material.dart';
import 'services/terminal_backend.dart';
import 'theme.dart';
import 'pages/main_page.dart';
import 'widgets/terminal_panel.dart';

class MyApp extends StatefulWidget {
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
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Terminal Master',
      theme: buildDarkTheme(),
      home: TerminalWorkspace(
        backendFactory: widget.terminalBackendFactory,
        navigatorKey: _navigatorKey,
        child: Navigator(
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (context) => MainPage(
              configDirectoryPath: widget.configDirectoryPath,
              displayPath: widget.displayPath,
            ),
          ),
        ),
      ),
    );
  }
}
