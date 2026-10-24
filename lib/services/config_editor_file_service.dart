import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../models/config_editor_document.dart';
import '../utils/config_loader.dart';

class ConfigEditorFileService {
  const ConfigEditorFileService();

  Future<ConfigEditorDocument> load(String filePath) async {
    final source = await File(filePath).readAsString();
    final parsed = loadYaml(source);
    ConfigLoader.loadConfig(filePath);
    return ConfigEditorDocument.fromYaml(parsed);
  }

  String serialize(ConfigEditorDocument document) {
    final editor = YamlEditor('{}');
    editor.update([], document.data);
    return editor.toString();
  }

  Future<void> save(String filePath, ConfigEditorDocument document) async {
    final target = File(filePath);
    final temporary = File('${target.path}.editor-tmp.yaml');
    final backup = File('${target.path}.editor-bak');
    final yaml = serialize(document);

    try {
      await temporary.writeAsString(yaml, flush: true);
      try {
        ConfigLoader.loadConfig(temporary.path);
      } on ConfigFormatException catch (error) {
        throw ConfigFormatException(
          filePath,
          error.fieldPath,
          error.reason,
          error.detail,
        );
      }
      var hadOriginal = await target.exists();
      if (await backup.exists()) {
        if (hadOriginal) {
          await backup.delete();
        } else {
          await backup.rename(target.path);
          hadOriginal = true;
        }
      }
      if (hadOriginal) await target.rename(backup.path);
      try {
        await temporary.rename(target.path);
        if (hadOriginal && await backup.exists()) await backup.delete();
      } on Object {
        if (hadOriginal && !await target.exists() && await backup.exists()) {
          await backup.rename(target.path);
        }
        rethrow;
      }
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<String> createPath(String directory, String command) async {
    final slug = command
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'^[_-]+|[_-]+$'), '');
    final base = slug.isEmpty ? 'new_config' : slug;
    var candidate = p.join(directory, '$base.yaml');
    var suffix = 2;
    while (await FileSystemEntity.type(candidate) !=
        FileSystemEntityType.notFound) {
      candidate = p.join(directory, '${base}_$suffix.yaml');
      suffix++;
    }
    return candidate;
  }
}
