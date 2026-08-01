import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/models/shell_profile.dart';
import 'package:terminal_master/utils/settings_loader.dart';

void main() {
  test('loads and orders configured integrated terminal profiles', () {
    final directory = Directory.systemTemp.createTempSync(
      'terminal-master-settings-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    File('${directory.path}/settings.yaml').writeAsStringSync('''
terminal: Example Terminal
file_manager: example-manager
integrated_terminal:
  default_profile: ssh
  profiles:
    - id: local
      name: Local Bash
      executable: /bin/bash
      arguments: [-l]
      dialect: posix
    - id: ssh
      name: Production SSH
      executable: /usr/bin/ssh
      arguments: [example.com]
      working_directory: ~/projects
      environment:
        LANG: en_US.UTF-8
      dialect: posix
    - id: powershell
      name: PowerShell 7
      executable: /usr/bin/pwsh
      arguments: [-NoLogo]
      dialect: powershell
''');

    SettingsLoader.initialize(directory.path);

    expect(SettingsLoader.terminalCommand, 'Example Terminal');
    expect(SettingsLoader.fileManagerCommand, 'example-manager');
    expect(
      SettingsLoader.integratedTerminalProfiles.map((profile) => profile.id),
      ['ssh', 'local', 'powershell'],
    );
    final profile = SettingsLoader.integratedTerminalProfiles.first;
    expect(profile.name, 'Production SSH');
    expect(profile.arguments, ['example.com']);
    expect(profile.environment, {'LANG': 'en_US.UTF-8'});
    expect(profile.dialect, ShellDialect.posix);
    expect(profile.workingDirectory, endsWith('/projects'));
    final powerShell = SettingsLoader.integratedTerminalProfiles.last;
    expect(powerShell.arguments, ['-NoLogo']);
    expect(powerShell.dialect, ShellDialect.powerShell);
  });

  test('rejects duplicate integrated terminal profile ids', () {
    final directory = Directory.systemTemp.createTempSync(
      'terminal-master-settings-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    File('${directory.path}/settings.yaml').writeAsStringSync('''
integrated_terminal:
  profiles:
    - id: duplicate
      executable: /bin/sh
    - id: duplicate
      executable: /bin/bash
''');

    expect(
      () => SettingsLoader.initialize(directory.path),
      throwsFormatException,
    );
  });
}
