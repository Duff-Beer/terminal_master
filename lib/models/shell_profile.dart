import 'dart:io';

enum ShellDialect { posix, windowsCmd }

class ShellProfile {
  final String id;
  final String name;
  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final Map<String, String> environment;
  final ShellDialect dialect;

  const ShellProfile({
    required this.id,
    required this.name,
    required this.executable,
    this.arguments = const [],
    this.workingDirectory,
    this.environment = const {},
    required this.dialect,
  });

  static List<ShellProfile> platformDefaults() {
    if (Platform.isWindows) {
      return [
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
    final candidates = <(String, String)>[
      ('Login Shell', configuredShell),
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
    if (profiles.isNotEmpty) return profiles;
    return [
      ShellProfile(
        id: 'login-shell',
        name: 'Login Shell',
        executable: configuredShell,
        arguments: const ['-l'],
        workingDirectory: home,
        dialect: ShellDialect.posix,
      ),
    ];
  }
}
