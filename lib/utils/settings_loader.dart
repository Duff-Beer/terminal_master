import 'dart:io';
import 'package:yaml/yaml.dart';

class SettingsLoader {
  static late String terminalCommand;
  static late String fileManagerCommand;

  static void initialize(String dirPath) {
    final file = File('$dirPath/settings.yaml');
    final defaults = _defaultValues();

    if (!file.existsSync()) {
      file.writeAsStringSync(
        'terminal: ${defaults['terminal']}\nfile_manager: ${defaults['file_manager']}\n',
      );
      terminalCommand = defaults['terminal']!;
      fileManagerCommand = defaults['file_manager']!;
      return;
    }

    final doc = loadYaml(file.readAsStringSync());
    terminalCommand = doc['terminal']?.toString() ?? defaults['terminal']!;
    fileManagerCommand = doc['file_manager']?.toString() ?? defaults['file_manager']!;
  }

  static Map<String, String> _defaultValues() {
    if (Platform.isWindows) {
      return {'terminal': 'cmd.exe', 'file_manager': 'explorer'};
    } else if (Platform.isMacOS) {
      return {'terminal': 'Terminal', 'file_manager': 'open'};
    } else {
      final res = Process.runSync('which', ['terminator']);
      final term = res.exitCode == 0 ? 'terminator' : 'gnome-terminal';
      return {'terminal': term, 'file_manager': 'xdg-open'};
    }
  }
}
