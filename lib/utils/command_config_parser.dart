import 'dart:io';
import 'package:yaml/yaml.dart';

class CommandConfigParser {
  static Map<String, dynamic> convertYamlMap(YamlMap yamlMap) {
    final map = <String, dynamic>{};
    yamlMap.forEach((key, value) {
      if (value is YamlMap) {
        map[key.toString()] = convertYamlMap(value);
      } else if (value is YamlList) {
        map[key.toString()] = value
            .map((item) => item is YamlMap ? convertYamlMap(item) : item)
            .toList();
      } else {
        map[key.toString()] = value;
      }
    });
    return map;
  }

  static Map<String, dynamic>? loadConfig(String path) {
    final file = File(path);
    if (!file.existsSync()) return null;
    final yamlString = file.readAsStringSync();
    final doc = loadYaml(yamlString);
    if (doc == null || doc['command'] == null) return null;
    return convertYamlMap(doc as YamlMap);
  }
}
