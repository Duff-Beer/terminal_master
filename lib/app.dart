import 'dart:io';

import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'models/shell_profile.dart';
import 'services/routing_terminal_backend_factory.dart';
import 'services/saved_terminal_tab_store.dart';
import 'services/ssh_connection_profile_store.dart';
import 'services/ssh_credential_store.dart';
import 'services/ssh_host_key_verifier.dart';
import 'services/terminal_backend.dart';
import 'theme.dart';
import 'pages/main_page.dart';
import 'pages/ssh_connections_page.dart';
import 'pages/settings_page.dart';
import 'widgets/terminal_panel.dart';

class MyApp extends StatefulWidget {
  final String configDirectoryPath;
  final String? yamlDirectoryPath;
  final String displayPath;
  final TerminalBackendFactory terminalBackendFactory;
  final List<ShellProfile>? shellProfiles;
  final SshConnectionProfileStore? sshProfileStore;
  final SshCredentialStore? sshCredentialStore;
  final Future<void> Function(String profileId)? saveDefaultShellProfile;
  final Future<void> Function(String path)? saveYamlDirectoryPath;
  final Future<String?> Function()? selectYamlDirectory;

  /// Initial UI language. `null` follows the operating system locale.
  final String? languageCode;
  final Future<void> Function(String? code)? saveLanguage;
  final bool commandBarPinned;
  final Future<void> Function(bool pinned)? saveCommandBarPinned;

  const MyApp({
    super.key,
    required this.configDirectoryPath,
    this.yamlDirectoryPath,
    required this.displayPath,
    this.terminalBackendFactory = unavailableTerminalBackendFactory,
    this.shellProfiles,
    this.sshProfileStore,
    this.sshCredentialStore,
    this.saveDefaultShellProfile,
    this.saveYamlDirectoryPath,
    this.selectYamlDirectory,
    this.languageCode,
    this.saveLanguage,
    this.commandBarPinned = false,
    this.saveCommandBarPinned,
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
  late final ValueNotifier<String> _yamlDirectoryPath;
  String? _languageCode;

  @override
  void initState() {
    super.initState();
    _languageCode = widget.languageCode;
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
    _yamlDirectoryPath = ValueNotifier(
      widget.yamlDirectoryPath ?? widget.configDirectoryPath,
    );
  }

  @override
  void dispose() {
    _yamlDirectoryPath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Terminal Master',
      theme: buildDarkTheme(),
      locale: _languageCode == null ? null : Locale(_languageCode!),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TerminalWorkspace(
        backendFactory: _backendRouter.create,
        navigatorKey: _navigatorKey,
        profiles: widget.shellProfiles,
        savedTabStore: FileSavedTerminalTabStore(
          Directory(widget.configDirectoryPath),
        ),
        commandBarPinned: widget.commandBarPinned,
        saveCommandBarPinned: widget.saveCommandBarPinned,
        sshPanel: SshConnectionsPage(
          profileStore: _sshProfileStore,
          credentialStore: _sshCredentialStore,
          hostKeyVerifier: _sshHostKeyVerifier,
        ),
        settingsPanel: SettingsPage(
          configDirectoryPath: widget.configDirectoryPath,
          yamlDirectoryPath: _yamlDirectoryPath.value,
          saveDefaultProfile: widget.saveDefaultShellProfile,
          saveYamlDirectoryPath: widget.saveYamlDirectoryPath,
          selectYamlDirectory: widget.selectYamlDirectory,
          onYamlDirectoryChanged: (path) => _yamlDirectoryPath.value = path,
          languageCode: _languageCode,
          saveLanguage: widget.saveLanguage,
          onLanguageChanged: (code) => setState(() => _languageCode = code),
        ),
        child: Navigator(
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (context) => MainPage(
              configDirectoryPath: _yamlDirectoryPath.value,
              displayPath: widget.displayPath,
              yamlDirectoryPath: _yamlDirectoryPath,
            ),
          ),
        ),
      ),
    );
  }
}
