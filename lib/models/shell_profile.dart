import 'dart:io';

enum ShellDialect { posix, windowsCmd, powerShell }

class ShellProfile {
  final String id;
  final String name;
  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final Map<String, String> environment;
  final ShellDialect dialect;
  final String? sshConnectionProfileId;

  const ShellProfile({
    required this.id,
    required this.name,
    required this.executable,
    this.arguments = const [],
    this.workingDirectory,
    this.environment = const {},
    required this.dialect,
    this.sshConnectionProfileId,
  });

  bool get isSsh => sshConnectionProfileId != null;

  static List<ShellProfile> platformDefaults() {
    if (Platform.isWindows) {
      return [
        if (_windowsExecutableExists('pwsh.exe'))
          ShellProfile(
            id: 'powershell',
            name: 'PowerShell 7',
            executable: 'pwsh.exe',
            arguments: const ['-NoLogo'],
            workingDirectory: Platform.environment['USERPROFILE'],
            dialect: ShellDialect.powerShell,
          ),
        ShellProfile(
          id: 'windows-powershell',
          name: 'Windows PowerShell',
          executable: 'powershell.exe',
          arguments: const ['-NoLogo'],
          workingDirectory: Platform.environment['USERPROFILE'],
          dialect: ShellDialect.powerShell,
        ),
        ShellProfile(
          id: 'command-prompt',
          name: 'Command Prompt',
          executable: 'cmd.exe',
          workingDirectory: Platform.environment['USERPROFILE'],
          dialect: ShellDialect.windowsCmd,
        ),
      ];
    }

    final home = Platform.environment['HOME'];
    final configuredShell = Platform.environment['SHELL'] ?? '/bin/bash';
    final configuredShellName = configuredShell.split('/').last;
    final candidates = <(String, String)>[
      (configuredShellName, configuredShell),
      ('Zsh', '/bin/zsh'),
      ('Bash', '/bin/bash'),
      ('Fish', '/usr/bin/fish'),
      ('Fish', '/usr/local/bin/fish'),
      ('Fish', '/opt/homebrew/bin/fish'),
    ];
    final profiles = <ShellProfile>[];
    final executables = <String>{};
    for (final (name, executable) in candidates) {
      if (!executables.add(executable) || !File(executable).existsSync()) {
        continue;
      }
      final executableName = executable.substring(
        executable.lastIndexOf('/') + 1,
      );
      final baseId = profiles.isEmpty ? 'login-shell' : executableName;
      final id = profiles.any((profile) => profile.id == baseId)
          ? '$baseId-${profiles.length + 1}'
          : baseId;
      profiles.add(
        ShellProfile(
          id: id,
          name: profiles.isEmpty ? name : executableName,
          executable: executable,
          arguments: const ['-l'],
          workingDirectory: home,
          dialect: ShellDialect.posix,
        ),
      );
    }
    for (final executable in const [
      '/usr/bin/pwsh',
      '/usr/local/bin/pwsh',
      '/opt/homebrew/bin/pwsh',
      '/snap/bin/pwsh',
    ]) {
      if (!executables.add(executable) || !File(executable).existsSync()) {
        continue;
      }
      profiles.add(
        ShellProfile(
          id: profiles.any((profile) => profile.id == 'powershell')
              ? 'powershell-${profiles.length + 1}'
              : 'powershell',
          name: 'PowerShell',
          executable: executable,
          arguments: const ['-NoLogo'],
          workingDirectory: home,
          dialect: ShellDialect.powerShell,
        ),
      );
    }
    if (profiles.isNotEmpty) return profiles;
    return [
      ShellProfile(
        id: 'login-shell',
        name: configuredShellName,
        executable: configuredShell,
        arguments: const ['-l'],
        workingDirectory: home,
        dialect: ShellDialect.posix,
      ),
    ];
  }

  static bool _windowsExecutableExists(String executable) {
    final path =
        Platform.environment['PATH'] ??
        Platform.environment['Path'] ??
        Platform.environment['path'];
    if (path == null) return false;
    return path.split(';').any((directory) {
      final normalized = directory.trim().replaceAll('"', '');
      if (normalized.isEmpty) return false;
      final separator = normalized.endsWith('\\') ? '' : '\\';
      return File('$normalized$separator$executable').existsSync();
    });
  }
}
