import 'dart:io';
import 'package:yaml/yaml.dart';
import '../models/config_item.dart';
import '../models/command_config.dart';

class ConfigLoader {
  static List<ConfigItem> loadConfigs(String dirPath) {
    final directory = Directory(dirPath);
    if (!directory.existsSync()) return [];

    final files = directory.listSync().where((f) {
      final path = f.path;
      return path.endsWith('.yaml') || path.endsWith('.yml');
    });

    final items = <ConfigItem>[];
    for (var f in files) {
      try {
        final name = f.uri.pathSegments.last;
        final isBatch = name.startsWith('-');
        final yamlString = File(f.path).readAsStringSync();
        final doc = loadYaml(yamlString);

        if (!isBatch) {
          if (doc == null || doc['command'] == null) continue;
          items.add(ConfigItem(
            command: doc['command'].toString(),
            description: doc['description']?.toString() ?? 'No description',
            filePath: f.path,
          ));
        } else {
          final commands = doc['commands'] as YamlList?;
          if (commands == null) continue;

          items.add(ConfigItem(
            command: 'Batch: ${name.replaceFirst('-', '')}',
            description: '${commands.length} Befehle in dieser Datei',
            filePath: f.path,
            isBatch: true,
          ));
        }
      } catch (_) {}
    }

    items.sort((a, b) => a.command.compareTo(b.command));
    return items;
  }

  static CommandConfig? loadConfig(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    final yamlString = file.readAsStringSync();
    final doc = loadYaml(yamlString);
    if (doc == null || doc['command'] == null) return null;

    final params = <CommandParameter>[];
    for (var p in doc['parameters'] ?? []) {
      params.add(CommandParameter(
        name: p['name'],
        description: p['description'] ?? '',
        type: p['type'],
        flag: p['flag'],
        prefix: p['prefix'],
        suffix: p['suffix'],
        dependsOn:
            p['depends_on'] != null ? List<String>.from(p['depends_on']) : null,
        conflictsWith: p['conflicts_with'] != null
            ? List<String>.from(p['conflicts_with'])
            : null,
        mustDiffer: p['must_differ'] == true,
        required: p['required'] == true,
        order: p['order'] ?? 1000,
        options: p['options'] != null
            ? (p['options'] as YamlList)
                .map<Map<String, String>>(
                  (o) => Map<String, String>.from(
                    Map<String, dynamic>.from(o)
                        .map((k, v) => MapEntry(k.toString(), v.toString())),
                  ),
                )
                .toList()
            : null,
      ));
    }

    return CommandConfig(
      command: doc['command'],
      description: doc['description'] ?? '',
      helpText: doc['help_text'],
      parameters: params,
    );
  }
}
