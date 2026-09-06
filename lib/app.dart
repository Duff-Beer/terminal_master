import 'dart:io';

import 'package:flutter/material.dart';
import 'models/shell_profile.dart';
import 'services/routing_terminal_backend_factory.dart';
import 'services/saved_terminal_tab_store.dart';
import 'services/ssh_connection_profile_store.dart';
import 'services/ssh_credential_store.dart';
import 'services/ssh_host_key_verifier.dart';
import 'services/terminal_backend.dart';
import 'theme.dart';
import 'pages/main_page.dart';
import 'widgets/terminal_panel.dart';

class MyApp extends StatefulWidget {
  final String configDirectoryPath;
  final String displayPath;
  final TerminalBackendFactory terminalBackendFactory;
  final List<ShellProfile>? shellProfiles;
  final SshConnectionProfileStore? sshProfileStore;
  final SshCredentialStore? sshCredentialStore;

  const MyApp({
    super.key,
    required this.configDirectoryPath,
    required this.displayPath,
    this.terminalBackendFactory = unavailableTerminalBackendFactory,
    this.shellProfiles,
    this.sshProfileStore,
    this.sshCredentialStore,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final SshConnectionProfileStore _sshProfileStore;
  late final SshCredentialStore _sshCredentialStore;
  late final SshHostKeyVerifier _sshHostKeyVerifier;
  late final RoutingTerminalBackendFactory _backendRouter;

  @override
  void initState() {
    super.initState();
    _sshProfileStore =
        widget.sshProfileStore ?? MemorySshConnectionProfileStore();
    _sshCredentialStore =
        widget.sshCredentialStore ?? MemorySshCredentialStore();
    _sshHostKeyVerifier = DialogSshHostKeyVerifier(
      navigatorKey: _navigatorKey,
      profileStore: _sshProfileStore,
    );
    _backendRouter = RoutingTerminalBackendFactory(
      localFactory: widget.terminalBackendFactory,
      profileStore: _sshProfileStore,
      credentialStore: _sshCredentialStore,
      hostKeyVerifier: _sshHostKeyVerifier,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Terminal Master',
      theme: buildDarkTheme(),
      home: TerminalWorkspace(
        backendFactory: _backendRouter.create,
        navigatorKey: _navigatorKey,
        profiles: widget.shellProfiles,
        savedTabStore: FileSavedTerminalTabStore(
          Directory(widget.configDirectoryPath),
        ),
        child: Navigator(
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (context) => MainPage(
              configDirectoryPath: widget.configDirectoryPath,
              displayPath: widget.displayPath,
              sshProfileStore: _sshProfileStore,
              sshCredentialStore: _sshCredentialStore,
              sshHostKeyVerifier: _sshHostKeyVerifier,
            ),
          ),
        ),
      ),
    );
  }
}
