import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/models/shell_profile.dart';
import 'package:terminal_master/utils/settings_loader.dart';

void main() {
  test(
    'loads, saves and orders configured integrated terminal profiles',
    () async {
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

      await SettingsLoader.saveDefaultIntegratedTerminalProfile(
        directory.path,
        'local',
      );
      SettingsLoader.initialize(directory.path);

      expect(
        SettingsLoader.integratedTerminalProfiles.map((profile) => profile.id),
        ['local', 'ssh', 'powershell'],
      );
      expect(
        File('${directory.path}/settings.yaml').readAsStringSync(),
        contains('default_profile: "local"'),
      );
    },
  );

  test('adds a default profile without replacing existing settings', () async {
    final directory = Directory.systemTemp.createTempSync(
      'terminal-master-settings-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/settings.yaml');
    file.writeAsStringSync('terminal: custom-terminal\n# keep this comment\n');

    await SettingsLoader.saveDefaultIntegratedTerminalProfile(
      directory.path,
      'login-shell',
    );

    final content = file.readAsStringSync();
    expect(content, contains('terminal: custom-terminal'));
    expect(content, contains('# keep this comment'));
    expect(content, contains('integrated_terminal:'));
    expect(content, contains('default_profile: "login-shell"'));
  });

  test(
    'saves and loads the YAML directory without replacing settings',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'terminal-master-settings-',
      );
      final yamlDirectory = Directory('${directory.path}/commands')
        ..createSync();
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/settings.yaml');
      file.writeAsStringSync(
        'terminal: custom-terminal\nfile_manager: custom-manager\n',
      );

      await SettingsLoader.saveYamlDirectoryPath(
        directory.path,
        yamlDirectory.path,
      );
      SettingsLoader.initialize(directory.path);

      expect(SettingsLoader.yamlDirectoryPath, yamlDirectory.path);
      final content = file.readAsStringSync();
      expect(content, contains('terminal: custom-terminal'));
      expect(content, contains('file_manager: custom-manager'));
      expect(content, contains('yaml_directory:'));
      expect(content, contains(jsonEncode(yamlDirectory.path)));
    },
  );

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

  test('round-trips the interface language through settings.yaml', () async {
    final directory = Directory.systemTemp.createTempSync(
      'terminal-master-settings-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/settings.yaml')
      ..writeAsStringSync('terminal: Example Terminal\n');

    // Absent means "follow the operating system".
    SettingsLoader.initialize(directory.path);
    expect(SettingsLoader.languageCode, isNull);

    await SettingsLoader.saveLanguage(directory.path, 'de');
    SettingsLoader.initialize(directory.path);
    expect(SettingsLoader.languageCode, 'de');
    // The rest of the file survives the write.
    expect(file.readAsStringSync(), contains('terminal: Example Terminal'));

    await SettingsLoader.saveLanguage(directory.path, null);
    SettingsLoader.initialize(directory.path);
    expect(SettingsLoader.languageCode, isNull);
    expect(file.readAsStringSync(), contains('language: "system"'));
  });

  test('persists the command bar pinned preference in settings.yaml', () async {
    final directory = Directory.systemTemp.createTempSync(
      'terminal-master-settings-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/settings.yaml')
      ..writeAsStringSync('terminal: Example Terminal\n');

    SettingsLoader.initialize(directory.path);
    expect(SettingsLoader.commandBarPinned, isFalse);

    await SettingsLoader.saveCommandBarPinned(directory.path, true);
    SettingsLoader.initialize(directory.path);
    expect(SettingsLoader.commandBarPinned, isTrue);
    expect(file.readAsStringSync(), contains('terminal: Example Terminal'));

    await SettingsLoader.saveCommandBarPinned(directory.path, false);
    SettingsLoader.initialize(directory.path);
    expect(SettingsLoader.commandBarPinned, isFalse);
  });

  test(
    'round-trips the terminal font family and ignores unknown values',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'terminal-master-settings-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/settings.yaml')
        ..writeAsStringSync('terminal: Example Terminal\n');

      SettingsLoader.initialize(directory.path);
      expect(SettingsLoader.terminalFontFamily, 'monospace');

      await SettingsLoader.saveTerminalFontFamily(
        directory.path,
        'Noto Sans Mono',
      );
      SettingsLoader.initialize(directory.path);
      expect(SettingsLoader.terminalFontFamily, 'Noto Sans Mono');
      expect(file.readAsStringSync(), contains('terminal_font_family:'));

      file.writeAsStringSync('terminal_font_family: Unavailable Font\n');
      SettingsLoader.initialize(directory.path);
      expect(SettingsLoader.terminalFontFamily, 'monospace');
    },
  );

  test('falls back to the system locale for an unsupported language', () {
    final directory = Directory.systemTemp.createTempSync(
      'terminal-master-settings-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    File('${directory.path}/settings.yaml').writeAsStringSync('language: xx\n');

    // A stale or hand-edited language code must not break startup.
    SettingsLoader.initialize(directory.path);
    expect(SettingsLoader.languageCode, isNull);
  });
}
