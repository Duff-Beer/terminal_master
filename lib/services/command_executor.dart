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
        'gnome-terminal',
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
      final terminalRunning = await isTerminalRunning();
      // Argument für neues Fenster oder neuen Tab
      final modeFlag =
          (!alwaysOpenNew && terminalRunning) ? '--tab' : '--window';
      // Aufbau: gnome-terminal --window|--tab -- bash -c "meinBefehl; exec bash"
      final args = [modeFlag, '--', 'bash', '-c', '$command; exec bash'];
      await Process.start('gnome-terminal', args);
    } else if (Platform.isWindows) {
      // Windows ⇒ neues CMD-Fenster
      await Process.start('cmd.exe', ['/C', 'start', 'cmd.exe', '/K', command]);
    } else {
      throw UnsupportedError(
          'Terminal execution not supported on this platform');
    }
  }
}
