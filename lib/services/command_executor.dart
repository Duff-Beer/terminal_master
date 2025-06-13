import 'dart:io';
import '../utils/settings_loader.dart';

class CommandExecutor {
  /// Prüft, ob ein Terminal-Prozess auf dem System läuft.
  static Future<bool> isTerminalRunning() async {
    if (Platform.isMacOS) {
      // Auf macOS prüfen wir nach dem konfigurierten Terminal
      final res = await Process.run('pgrep', ['-x', SettingsLoader.terminalCommand]);
      return res.exitCode == 0;
    } else if (Platform.isLinux) {
      // Unter Linux prüfen wir nach dem konfigurierten Terminal
      final res = await Process.run('pgrep', ['-x', SettingsLoader.terminalCommand]);
      return res.exitCode == 0;
    } else if (Platform.isWindows) {
      // Unter Windows prüfen wir nach dem konfigurierten Terminal
      final res = await Process.run(
          'tasklist', ['/FI', "IMAGENAME eq ${SettingsLoader.terminalCommand}", '/NH']);
      return res.stdout.toString().trim().isNotEmpty;
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
      final app = SettingsLoader.terminalCommand;
      final appleScript = (!alwaysOpenNew && terminalRunning)
          ? 'tell application "$app" to do script "$command" in front window'
          : 'tell application "$app" to do script "$command"';
      await Process.run('osascript', ['-e', appleScript]);
    } else if (Platform.isLinux) {
      // Unter Linux verwenden wir das konfigurierte Terminal
      await Process.start(
          SettingsLoader.terminalCommand, ['--', 'bash', '-lc', command]);
    } else if (Platform.isWindows) {
      // Unter Windows immer neues Terminal-Fenster öffnen
      await Process.start('cmd.exe', [
        '/C',
        'start',
        SettingsLoader.terminalCommand,
        '/K',
        command
      ]);
    } else {
      throw UnsupportedError(
          'Terminal execution not supported on this platform');
    }
  }
}
