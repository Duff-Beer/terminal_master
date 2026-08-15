import 'dart:io';

import 'package:yaml/yaml.dart';

import '../models/command_config.dart';
import '../utils/config_loader.dart';

class CommandOptionStoreException implements Exception {
  final String message;

  const CommandOptionStoreException(this.message);

  @override
  String toString() => message;
}

class CommandOptionStore {
  const CommandOptionStore._();

  static Future<void> addOption({
    required String filePath,
    required String parameterName,
    required CommandOption option,
    required String expectedContent,
  }) async {
    final value = option.value.trim();
    final description = option.description.trim();
    if (value.isEmpty || description.isEmpty) {
      throw const CommandOptionStoreException(
        'Wert und Beschreibung dürfen nicht leer sein.',
      );
    }
    if (_containsControlCharacters(value) ||
        _containsControlCharacters(description)) {
      throw const CommandOptionStoreException(
        'Wert und Beschreibung dürfen keine Steuerzeichen enthalten.',
      );
    }

    final file = File(filePath);
    final content = await file.readAsString();
    if (content != expectedContent) {
      throw const CommandOptionStoreException(
        'Die YAML-Datei wurde zwischenzeitlich geändert. Öffne sie erneut.',
      );
    }
    final (:parameter, :optionsNode) = _optionNodes(content, parameterName);
    if (optionsNode.any(
      (entry) => entry is YamlMap && entry['value']?.toString() == value,
    )) {
      throw CommandOptionStoreException(
        'Der Optionswert "$value" ist bereits vorhanden.',
      );
    }

    final lineEnding = content.contains('\r\n') ? '\r\n' : '\n';
    final lines = content.split(lineEnding);
    final optionsLine = _keyLine(parameter, 'options');
    final optionsIndent = _leadingWhitespace(lines[optionsLine]).length;
    var insertionLine = optionsLine + 1;
    while (insertionLine < lines.length) {
      final line = lines[insertionLine];
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        var nextContentLine = '';
        for (var index = insertionLine + 1; index < lines.length; index++) {
          if (lines[index].trim().isNotEmpty) {
            nextContentLine = lines[index];
            break;
          }
        }
        if (nextContentLine.isEmpty ||
            _leadingWhitespace(nextContentLine).length <= optionsIndent) {
          break;
        }
      } else if (_leadingWhitespace(line).length <= optionsIndent) {
        break;
      }
      insertionLine++;
    }
    final itemIndent = '${' ' * optionsIndent}  ';
    lines.insertAll(insertionLine, [
      '$itemIndent- value: ${_yamlString(value)}',
      '$itemIndent  description: ${_yamlString(description)}',
    ]);
    final updated = lines.join(lineEnding);

    await _replaceValidated(
      filePath: filePath,
      expectedContent: expectedContent,
      updatedContent: updated,
      validate: (config) {
        final parsedParameter = config.parameters.singleWhere(
          (candidate) => candidate.name == parameterName,
        );
        if (!parsedParameter.options.any(
          (candidate) =>
              candidate.value == value && candidate.description == description,
        )) {
          throw const CommandOptionStoreException(
            'Der neue Eintrag konnte nicht validiert werden.',
          );
        }
      },
    );
  }

  static Future<void> deleteOption({
    required String filePath,
    required String parameterName,
    required String optionValue,
    required String expectedContent,
  }) async {
    final file = File(filePath);
    final content = await file.readAsString();
    if (content != expectedContent) {
      throw const CommandOptionStoreException(
        'Die YAML-Datei wurde zwischenzeitlich geändert. Öffne sie erneut.',
      );
    }
    final (:parameter, :optionsNode) = _optionNodes(content, parameterName);
    final optionIndex = optionsNode.nodes.indexWhere(
      (entry) => entry is YamlMap && entry['value']?.toString() == optionValue,
    );
    if (optionIndex < 0) {
      throw CommandOptionStoreException(
        'Der Optionswert "$optionValue" wurde nicht gefunden.',
      );
    }
    if (optionsNode.nodes.length == 1) {
      throw const CommandOptionStoreException(
        'Der letzte Optionswert kann nicht gelöscht werden.',
      );
    }

    final lineEnding = content.contains('\r\n') ? '\r\n' : '\n';
    final lines = content.split(lineEnding);
    final optionsLine = _keyLine(parameter, 'options');
    final optionsIndent = _leadingWhitespace(lines[optionsLine]).length;
    final itemIndent = optionsIndent + 2;
    final itemLines = <int>[];
    var listEnd = lines.length;
    for (var index = optionsLine + 1; index < lines.length; index++) {
      final line = lines[index];
      final trimmed = line.trimLeft();
      if (trimmed.isNotEmpty &&
          !trimmed.startsWith('#') &&
          _leadingWhitespace(line).length <= optionsIndent) {
        listEnd = index;
        break;
      }
      if (_leadingWhitespace(line).length == itemIndent &&
          (trimmed == '-' || trimmed.startsWith('- '))) {
        itemLines.add(index);
      }
    }
    if (itemLines.length != optionsNode.nodes.length) {
      throw const CommandOptionStoreException(
        'Die Optionsliste verwendet ein nicht unterstütztes YAML-Format.',
      );
    }
    final start = itemLines[optionIndex];
    final end = optionIndex + 1 < itemLines.length
        ? itemLines[optionIndex + 1]
        : listEnd;
    for (var index = end - 1; index >= start; index--) {
      final trimmed = lines[index].trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      lines.removeAt(index);
    }
    final updated = lines.join(lineEnding);

    await _replaceValidated(
      filePath: filePath,
      expectedContent: expectedContent,
      updatedContent: updated,
      validate: (config) {
        final parsedParameter = config.parameters.singleWhere(
          (candidate) => candidate.name == parameterName,
        );
        if (parsedParameter.options.any(
          (candidate) => candidate.value == optionValue,
        )) {
          throw const CommandOptionStoreException(
            'Der Eintrag konnte nicht vollständig gelöscht werden.',
          );
        }
      },
    );
  }

  static Future<void> _replaceValidated({
    required String filePath,
    required String expectedContent,
    required String updatedContent,
    required void Function(CommandConfig config) validate,
  }) async {
    final file = File(filePath);
    final temporary = File('$filePath.tmp');
    final backup = File('$filePath.bak');
    await temporary.writeAsString(updatedContent, flush: true);
    try {
      final parsed = ConfigLoader.loadConfig(temporary.path);
      validate(parsed);
      if (await file.readAsString() != expectedContent) {
        throw const CommandOptionStoreException(
          'Die YAML-Datei wurde zwischenzeitlich geändert. Öffne sie erneut.',
        );
      }
      if (await backup.exists()) await backup.delete();
      await file.copy(backup.path);
      if (await backup.readAsString() != expectedContent ||
          await file.readAsString() != expectedContent) {
        throw const CommandOptionStoreException(
          'Die YAML-Datei wurde zwischenzeitlich geändert. Öffne sie erneut.',
        );
      }
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  static ({YamlMap parameter, YamlList optionsNode}) _optionNodes(
    String content,
    String parameterName,
  ) {
    final document = loadYamlNode(content);
    if (document is! YamlMap) {
      throw const CommandOptionStoreException('Die YAML-Wurzel ist ungültig.');
    }
    final parameters = _nodeFor(document, 'parameters');
    if (parameters is! YamlList) {
      throw const CommandOptionStoreException('Die Parameterliste fehlt.');
    }
    YamlMap? parameter;
    for (final node in parameters.nodes) {
      if (node case final YamlMap candidate) {
        if (candidate['name'] == parameterName) {
          parameter = candidate;
          break;
        }
      }
    }
    if (parameter == null || parameter['type'] != 'options') {
      throw CommandOptionStoreException(
        'Der Optionsparameter "$parameterName" wurde nicht gefunden.',
      );
    }
    final optionsNode = _nodeFor(parameter, 'options');
    if (optionsNode is! YamlList) {
      throw const CommandOptionStoreException('Die Optionsliste fehlt.');
    }
    return (parameter: parameter, optionsNode: optionsNode);
  }

  static String _yamlString(String value) =>
      '"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';

  static bool _containsControlCharacters(String value) =>
      value.runes.any((rune) => rune < 0x20 || rune == 0x7f);

  static YamlNode? _nodeFor(YamlMap map, String key) {
    for (final entry in map.nodes.entries) {
      if (entry.key.value == key) return entry.value;
    }
    return null;
  }

  static int _keyLine(YamlMap map, String key) {
    for (final entry in map.nodes.entries) {
      if (entry.key.value == key) return entry.key.span.start.line;
    }
    throw CommandOptionStoreException('Das Feld "$key" fehlt.');
  }

  static String _leadingWhitespace(String value) =>
      RegExp(r'^\s*').firstMatch(value)!.group(0)!;
}
