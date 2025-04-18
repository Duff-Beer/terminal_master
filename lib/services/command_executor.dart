import 'dart:io';

class CommandExecutor {
  /// Prüft, ob ein Terminal-Prozess auf dem System läuft.
  static Future<bool> isTerminalRunning() async {
    if (Platform.isMacOS) {
      // Auf macOS prüfen wir nach "Terminal"
      final res = await Process.run('pgrep', ['-x', 'Terminal']);
      return res.exitCode == 0;
    } else if (Platform.isLinux) {
      // Unter Linux prüfen wir eine Liste gängiger Terminal-Emulatoren
      const terminals = [
        'gnome-terminal-server', // neuere GNOME
        'gnome-terminal', // ältere GNOME
        'konsole', // KDE
        'xfce4-terminal',
        'xterm',
        'terminator',
      ];
      for (var term in terminals) {
        final res = await Process.run('pgrep', ['-x', term]);
        if (res.exitCode == 0) return true;
      }
      return false;
    } else if (Platform.isWindows) {
      // Unter Windows prüfen wir nach "cmd.exe" und "powershell.exe"
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
  /// Wenn alwaysOpenNew false und bereits ein Terminal läuft,
  /// wird der Befehl in das existierende Fenster geschickt.
  static Future<void> executeInTerminal(
      String command, bool alwaysOpenNew) async {
    if (Platform.isMacOS) {
      final terminalRunning = await isTerminalRunning();
      final appleScript = (!alwaysOpenNew && terminalRunning)
          ? 'tell application "Terminal" to do script "$command" in front window'
          : 'tell application "Terminal" to do script "$command"';
      await Process.run('osascript', ['-e', appleScript]);
    } else if (Platform.isLinux) {
      // Unter Linux: wenn Terminal offen & alwaysOpenNew==false,
      // könntest du hier weitere Logik ergänzen (z.B. wmctrl),
      // wir öffnen aber standardmäßig immer neu:
      await Process.start('gnome-terminal', ['--', 'bash', '-lc', command]);
    } else if (Platform.isWindows) {
      // Unter Windows immer neues CMD-Fenster öffnen
      await Process.start('cmd.exe', ['/C', 'start', 'cmd.exe', '/K', command]);
    } else {
      throw UnsupportedError(
          'Terminal execution not supported on this platform');
    }
  }
}
