import 'dart:io';

import 'package:flutter/material.dart';
import 'app.dart';
import 'services/flutter_pty_backend.dart';
import 'services/ssh_connection_profile_store.dart';
import 'services/ssh_credential_store.dart';
import 'utils/app_initializer.dart';
import 'utils/settings_loader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final initData = await initializeApp();

  runApp(
    MyApp(
      configDirectoryPath: initData.configPath,
      displayPath: initData.displayPath,
      terminalBackendFactory: FlutterPtyBackend.start,
      shellProfiles: SettingsLoader.integratedTerminalProfiles,
      sshProfileStore: FileSshConnectionProfileStore(
        Directory(initData.configPath),
      ),
      sshCredentialStore: const SecureSshCredentialStore(),
    ),
  );
}
