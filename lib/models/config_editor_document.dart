import 'package:yaml/yaml.dart';

class ConfigEditorDocument {
  final Map<String, Object?> data;

  ConfigEditorDocument._(this.data);

  factory ConfigEditorDocument.empty() => ConfigEditorDocument._({
    'schema_version': 2,
    'command': '',
    'parameters': <Object?>[],
  });

  factory ConfigEditorDocument.fromYaml(Object? value) {
    if (value is! Map) {
      throw const FormatException('The YAML root must be a map.');
    }
    return ConfigEditorDocument._(_copyMap(value));
  }

  String get command => data['command']?.toString() ?? '';

  set command(String value) => data['command'] = value;

  List<Map<String, Object?>> get parameters {
    final values = data.putIfAbsent('parameters', () => <Object?>[]);
    if (values is! List) {
      throw const FormatException('The parameters field must be a list.');
    }
    return values.cast<Map<String, Object?>>();
  }

  static Map<String, Object?> _copyMap(Map source) => {
    for (final entry in source.entries)
      entry.key.toString(): _copyValue(entry.value),
  };

  static Object? _copyValue(Object? value) {
    if (value is YamlMap || value is Map) return _copyMap(value as Map);
    if (value is YamlList || value is List) {
      return (value as List).map(_copyValue).toList();
    }
    return value;
  }
}
