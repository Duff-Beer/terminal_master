import 'dart:io';
import '../utils/settings_loader.dart';
import 'service_exception.dart';

class CommandExecutor {
  /// Prüft, ob bereits ein Terminal-Prozess läuft.
  static Future<bool> isTerminalRunning() async {
    if (Platform.isMacOS) {
      // Auf macOS prüfen wir nach dem konfigurierten Terminal
      final res = await Process.run('pgrep', [
        '-x',
        SettingsLoader.terminalCommand,
      ]);
      if (res.exitCode > 1) {
        throw ProcessException(
          'pgrep',
          ['-x', SettingsLoader.terminalCommand],
          res.stderr.toString().trim(),
          res.exitCode,
        );
      }
      return res.exitCode == 0;
    } else if (Platform.isLinux) {
      // Unter Linux prüfen wir nach dem konfigurierten Terminal
      final res = await Process.run('pgrep', [
        '-x',
        SettingsLoader.terminalCommand,
      ]);
      if (res.exitCode > 1) {
        throw ProcessException(
          'pgrep',
          ['-x', SettingsLoader.terminalCommand],
          res.stderr.toString().trim(),
          res.exitCode,
        );
      }
      return res.exitCode == 0;
    } else if (Platform.isWindows) {
      // Unter Windows prüfen wir nach dem konfigurierten Terminal
      final res = await Process.run('tasklist', [
        '/FI',
        "IMAGENAME eq ${SettingsLoader.terminalCommand}",
        '/NH',
      ]);
      return res.stdout.toString().trim().isNotEmpty;
    } else {
      throw const ServiceException(ServiceFailure.terminalDetectionUnsupported);
    }
  }

  /// Öffnet ein Terminal und führt den Befehl aus.
  /// Läuft bereits ein Terminal und [alwaysOpenNew] ist *false*,
  /// wird (nur auf macOS) das vorhandene Fenster verwendet.
  static Future<void> executeInTerminal(
    String command,
    bool alwaysOpenNew,
  ) async {
    if (Platform.isMacOS) {
      final terminalRunning = await isTerminalRunning();
      final app = SettingsLoader.terminalCommand;
      final escapedApp = app.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
      final escaped = command.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
      final appleScript = (!alwaysOpenNew && terminalRunning)
          ? 'tell application "$escapedApp" to do script "$escaped" in front window'
          : 'tell application "$escapedApp" to do script "$escaped"';
      final result = await Process.run('osascript', ['-e', appleScript]);
      if (result.exitCode != 0) {
        throw ProcessException(
          'osascript',
          ['-e', appleScript],
          result.stderr.toString().trim(),
          result.exitCode,
        );
      }
    } else if (Platform.isLinux) {
      // Unter Linux verwenden wir das konfigurierte Terminal
      await Process.start(SettingsLoader.terminalCommand, [
        '--',
        'bash',
        '-lc',
        command,
      ]);
    } else if (Platform.isWindows) {
      // Unter Windows immer neues Terminal-Fenster öffnen
      await Process.start('cmd.exe', [
        '/C',
        'start',
        '',
        SettingsLoader.terminalCommand,
        '/K',
        command,
      ]);
    } else {
      throw UnsupportedError(
        'Terminal execution not supported on this platform',
      );
    }
  }
}
