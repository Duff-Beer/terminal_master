import 'dart:io';

import 'package:yaml/yaml.dart';

import '../models/command_config.dart';
import '../utils/config_loader.dart';

/// Why editing the option list in a YAML file failed.
///
/// A code, not a sentence: the store runs without a `BuildContext`, so the UI
/// renders the reason in the active language.
enum CommandOptionStoreFailure {
  valueAndDescriptionRequired,
  controlCharactersNotAllowed,
  fileChangedMeanwhile,
  duplicateOptionValue,
  newEntryNotValid,
  optionValueNotFound,
  lastOptionCannotBeDeleted,
  unsupportedOptionListFormat,
  entryNotFullyDeleted,
  invalidYamlRoot,
  missingParameterList,
  optionsParameterNotFound,
  missingOptionList,
  missingField,
}

class CommandOptionStoreException implements Exception {
  final CommandOptionStoreFailure failure;

  /// The value, parameter or field name the failure refers to, when it has one.
  final String? detail;

  const CommandOptionStoreException(this.failure, [this.detail]);

  /// Developer-facing English description; the UI renders the localized form.
  String get message => switch (failure) {
    CommandOptionStoreFailure.valueAndDescriptionRequired =>
      'Value and description must not be empty.',
    CommandOptionStoreFailure.controlCharactersNotAllowed =>
      'Value and description must not contain control characters.',
    CommandOptionStoreFailure.fileChangedMeanwhile =>
      'The YAML file changed in the meantime. Open it again.',
    CommandOptionStoreFailure.duplicateOptionValue =>
      'The option value "$detail" already exists.',
    CommandOptionStoreFailure.newEntryNotValid =>
      'The new entry could not be validated.',
    CommandOptionStoreFailure.optionValueNotFound =>
      'The option value "$detail" was not found.',
    CommandOptionStoreFailure.lastOptionCannotBeDeleted =>
      'The last option value cannot be deleted.',
    CommandOptionStoreFailure.unsupportedOptionListFormat =>
      'The option list uses an unsupported YAML format.',
    CommandOptionStoreFailure.entryNotFullyDeleted =>
      'The entry could not be deleted completely.',
    CommandOptionStoreFailure.invalidYamlRoot => 'The YAML root is invalid.',
    CommandOptionStoreFailure.missingParameterList =>
      'The parameter list is missing.',
    CommandOptionStoreFailure.optionsParameterNotFound =>
      'The options parameter "$detail" was not found.',
    CommandOptionStoreFailure.missingOptionList =>
      'The option list is missing.',
    CommandOptionStoreFailure.missingField => 'The field "$detail" is missing.',
  };

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
        CommandOptionStoreFailure.valueAndDescriptionRequired,
      );
    }
    if (_containsControlCharacters(value) ||
        _containsControlCharacters(description)) {
      throw const CommandOptionStoreException(
        CommandOptionStoreFailure.controlCharactersNotAllowed,
      );
    }

    final file = File(filePath);
    final content = await file.readAsString();
    if (content != expectedContent) {
      throw const CommandOptionStoreException(
        CommandOptionStoreFailure.fileChangedMeanwhile,
      );
    }
    final (:parameter, :optionsNode) = _optionNodes(content, parameterName);
    if (optionsNode.any(
      (entry) => entry is YamlMap && entry['value']?.toString() == value,
    )) {
      throw CommandOptionStoreException(
        CommandOptionStoreFailure.duplicateOptionValue,
        value,
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
            CommandOptionStoreFailure.newEntryNotValid,
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
        CommandOptionStoreFailure.fileChangedMeanwhile,
      );
    }
    final (:parameter, :optionsNode) = _optionNodes(content, parameterName);
    final optionIndex = optionsNode.nodes.indexWhere(
      (entry) => entry is YamlMap && entry['value']?.toString() == optionValue,
    );
    if (optionIndex < 0) {
      throw CommandOptionStoreException(
        CommandOptionStoreFailure.optionValueNotFound,
        optionValue,
      );
    }
    if (optionsNode.nodes.length == 1) {
      throw const CommandOptionStoreException(
        CommandOptionStoreFailure.lastOptionCannotBeDeleted,
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
        CommandOptionStoreFailure.unsupportedOptionListFormat,
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
            CommandOptionStoreFailure.entryNotFullyDeleted,
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
          CommandOptionStoreFailure.fileChangedMeanwhile,
        );
      }
      if (await backup.exists()) await backup.delete();
      await file.copy(backup.path);
      if (await backup.readAsString() != expectedContent ||
          await file.readAsString() != expectedContent) {
        throw const CommandOptionStoreException(
          CommandOptionStoreFailure.fileChangedMeanwhile,
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
      throw const CommandOptionStoreException(
        CommandOptionStoreFailure.invalidYamlRoot,
      );
    }
    final parameters = _nodeFor(document, 'parameters');
    if (parameters is! YamlList) {
      throw const CommandOptionStoreException(
        CommandOptionStoreFailure.missingParameterList,
      );
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
        CommandOptionStoreFailure.optionsParameterNotFound,
        parameterName,
      );
    }
    final optionsNode = _nodeFor(parameter, 'options');
    if (optionsNode is! YamlList) {
      throw const CommandOptionStoreException(
        CommandOptionStoreFailure.missingOptionList,
      );
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
    throw CommandOptionStoreException(
      CommandOptionStoreFailure.missingField,
      key,
    );
  }

  static String _leadingWhitespace(String value) =>
      RegExp(r'^\s*').firstMatch(value)!.group(0)!;
}
