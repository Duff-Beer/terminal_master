import 'dart:io';
import 'package:yaml/yaml.dart';

import '../models/shell_profile.dart';

class SettingsLoader {
  static late String terminalCommand;
  static late String fileManagerCommand;
  static late List<ShellProfile> integratedTerminalProfiles;

  static void initialize(String dirPath) {
    final file = File('$dirPath/settings.yaml');
    final defaults = _defaultValues();
    final defaultProfiles = ShellProfile.platformDefaults();

    if (!file.existsSync()) {
      file.writeAsStringSync(
        'terminal: ${defaults['terminal']}\nfile_manager: ${defaults['file_manager']}\n',
      );
      terminalCommand = defaults['terminal']!;
      fileManagerCommand = defaults['file_manager']!;
      integratedTerminalProfiles = defaultProfiles;
      return;
    }

    final doc = loadYaml(file.readAsStringSync());
    terminalCommand = doc['terminal']?.toString() ?? defaults['terminal']!;
    fileManagerCommand =
        doc['file_manager']?.toString() ?? defaults['file_manager']!;
    integratedTerminalProfiles = _loadProfiles(
      doc['integrated_terminal'],
      defaultProfiles,
    );
  }

  static List<ShellProfile> _loadProfiles(
    Object? configuration,
    List<ShellProfile> defaults,
  ) {
    if (configuration == null) return defaults;
    if (configuration is! YamlMap) {
      throw const FormatException('integrated_terminal muss eine Map sein.');
    }
    final entries = configuration['profiles'];
    if (entries == null) return defaults;
    if (entries is! YamlList || entries.isEmpty) {
      throw const FormatException(
        'integrated_terminal.profiles muss eine nicht leere Liste sein.',
      );
    }

    final profiles = <ShellProfile>[];
    final ids = <String>{};
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      if (entry is! YamlMap) {
        throw FormatException(
          'Terminal-Profil ${index + 1} muss eine Map sein.',
        );
      }
      final id = _requiredString(entry, 'id', index);
      final name = entry['name']?.toString().trim();
      final executable = _requiredString(entry, 'executable', index);
      if (!ids.add(id)) {
        throw FormatException('Doppelte Terminal-Profil-ID: $id');
      }
      final argumentsNode = entry['arguments'];
      if (argumentsNode != null && argumentsNode is! YamlList) {
        throw FormatException('$id.arguments muss eine Liste sein.');
      }
      final environmentNode = entry['environment'];
      if (environmentNode != null && environmentNode is! YamlMap) {
        throw FormatException('$id.environment muss eine Map sein.');
      }
      final dialect = switch (entry['dialect']?.toString() ?? 'posix') {
        'posix' => ShellDialect.posix,
        'windows_cmd' => ShellDialect.windowsCmd,
        final value => throw FormatException(
          'Unbekannter Shell-Dialekt für $id: $value',
        ),
      };
      profiles.add(
        ShellProfile(
          id: id,
          name: name == null || name.isEmpty ? id : name,
          executable: _expandHome(executable),
          arguments: argumentsNode == null
              ? const []
              : argumentsNode.map<String>((value) => value.toString()).toList(),
          workingDirectory: entry['working_directory'] == null
              ? null
              : _expandHome(entry['working_directory'].toString()),
          environment: environmentNode == null
              ? const {}
              : {
                  for (final key in environmentNode.keys)
                    key.toString(): environmentNode[key].toString(),
                },
          dialect: dialect,
        ),
      );
    }

    final defaultId = configuration['default_profile']?.toString();
    if (defaultId == null) return profiles;
    final defaultIndex = profiles.indexWhere(
      (profile) => profile.id == defaultId,
    );
    if (defaultIndex < 0) {
      throw FormatException('Unbekanntes Standardprofil: $defaultId');
    }
    return [
      profiles[defaultIndex],
      ...profiles.where((p) => p.id != defaultId),
    ];
  }

  static String _requiredString(YamlMap entry, String key, int index) {
    final value = entry[key]?.toString().trim();
    if (value == null || value.isEmpty) {
      throw FormatException('Terminal-Profil ${index + 1} benötigt "$key".');
    }
    return value;
  }

  static String _expandHome(String value) {
    if (value == '~' || value.startsWith('~/') || value.startsWith('~\\')) {
      final home =
          Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
      if (home != null) return '$home${value.substring(1)}';
    }
    return value;
  }

  static Map<String, String> _defaultValues() {
    if (Platform.isWindows) {
      return {'terminal': 'cmd.exe', 'file_manager': 'explorer'};
    } else if (Platform.isMacOS) {
      return {'terminal': 'Terminal', 'file_manager': 'open'};
    } else {
      return {'terminal': 'gnome-terminal', 'file_manager': 'xdg-open'};
    }
  }
}
