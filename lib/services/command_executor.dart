import 'dart:io';

class CommandExecutor {
  /// Prüft, ob bereits ein Terminal-Prozess läuft.
  static Future<bool> isTerminalRunning() async {
    if (Platform.isMacOS) {
      // macOS ⇒ Terminal.app
      final res = await Process.run('pgrep', ['-x', 'Terminal']);
      return res.exitCode == 0;
    } else if (Platform.isLinux) {
      // Linux ⇒ Liste gängiger Emulatoren
      const terminals = [
        'gnome-terminal-server',
        'gnome-terminal',
        'konsole',
        'xfce4-terminal',
        'tilix',
        'xterm',
        'terminator',
      ];
      for (final term in terminals) {
        final res = await Process.run('pgrep', ['-x', term]);
        if (res.exitCode == 0) return true;
      }
      return false;
    } else if (Platform.isWindows) {
      // Windows ⇒ cmd oder PowerShell
      final cmdRes =
          await Process.run('tasklist', ['/FI', 'IMAGENAME eq cmd.exe', '/NH']);
      final psRes = await Process.run(
          'tasklist', ['/FI', 'IMAGENAME eq powershell.exe', '/NH']);
      return cmdRes.stdout.toString().trim().isNotEmpty ||
          psRes.stdout.toString().trim().isNotEmpty;
    } else {
      throw UnsupportedError(
          'Terminal-Erkennung nicht unterstützt auf dieser Plattform');
    }
  }

  /// Öffnet ein Terminal und führt den Befehl aus.
  /// Läuft bereits ein Terminal und [alwaysOpenNew] ist *false*,
  /// wird (nur auf macOS) das vorhandene Fenster verwendet.
  static Future<void> executeInTerminal(
      String command, bool alwaysOpenNew) async {
    if (Platform.isMacOS) {
      final terminalRunning = await isTerminalRunning();
      final script = (!alwaysOpenNew && terminalRunning)
          ? 'tell application "Terminal" to do script "$command" in front window'
          : 'tell application "Terminal" to do script "$command"';
      await Process.run('osascript', ['-e', script]);
    } else if (Platform.isLinux) {
      // Linux ⇒ nimm den ersten verfügbaren Emulator
      final candidates = <MapEntry<String, List<String>>>[
        MapEntry('gnome-terminal', ['--', 'bash', '-lc', command]),
        MapEntry('konsole', ['-e', 'bash', '-lc', command]),
        MapEntry('xfce4-terminal', ['-e', 'bash', '-lc', command]),
        MapEntry('tilix', ['-e', 'bash', '-lc', command]),
        MapEntry('xterm', ['-e', 'bash', '-lc', command]),
        MapEntry('terminator', ['-e', 'bash', '-lc', command]),
      ];

      for (final entry in candidates) {
        final exists = Process.runSync('which', [entry.key]).exitCode == 0;
        if (exists) {
          await Process.start(entry.key, entry.value);
          return;
        }
      }

      // Nichts gefunden ⇒ klarer Fehler-Hinweis
      throw UnsupportedError(
        'Kein unterstützter Terminal-Emulator gefunden.\n'
        'Installiere z. B. gnome-terminal, konsole oder xterm.',
      );
    } else if (Platform.isWindows) {
      // Windows ⇒ neues CMD-Fenster
      await Process.start('cmd.exe', ['/C', 'start', 'cmd.exe', '/K', command]);
    } else {
      throw UnsupportedError(
          'Terminal execution not supported on this platform');
    }
  }
}
