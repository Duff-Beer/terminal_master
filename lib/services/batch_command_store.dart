import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

import '../models/batch_command.dart';
import '../utils/config_loader.dart';

/// Why editing the command list in a batch YAML file failed.
///
/// A code, not a sentence: the store runs without a `BuildContext`, so the UI
/// renders the reason in the active language.
enum BatchCommandStoreFailure {
  titleAndCommandRequired,
  unsupportedCommandListFormat,
  newCommandNotValid,
  commandToDeleteNotFound,
  commandNotFullyDeleted,
  invalidYamlRoot,
  missingCommandList,
  fileChangedMeanwhile,
  missingField,
}

class BatchCommandStoreException implements Exception {
  final BatchCommandStoreFailure failure;

  /// The field name the failure refers to, when it has one.
  final String? detail;

  const BatchCommandStoreException(this.failure, [this.detail]);

  /// Developer-facing English description; the UI renders the localized form.
  String get message => switch (failure) {
    BatchCommandStoreFailure.titleAndCommandRequired =>
      'Title and command must not be empty.',
    BatchCommandStoreFailure.unsupportedCommandListFormat =>
      'The command list uses an unsupported YAML format.',
    BatchCommandStoreFailure.newCommandNotValid =>
      'The new command could not be validated.',
    BatchCommandStoreFailure.commandToDeleteNotFound =>
      'The command to delete was not found.',
    BatchCommandStoreFailure.commandNotFullyDeleted =>
      'The command could not be deleted completely.',
    BatchCommandStoreFailure.invalidYamlRoot => 'The YAML root is invalid.',
    BatchCommandStoreFailure.missingCommandList =>
      'The command list is missing.',
    BatchCommandStoreFailure.fileChangedMeanwhile =>
      'The YAML file changed in the meantime. Open it again.',
    BatchCommandStoreFailure.missingField => 'The field "$detail" is missing.',
  };

  @override
  String toString() => message;
}

class BatchCommandStore {
  const BatchCommandStore._();

  static Future<void> addCommand({
    required String filePath,
    required BatchCommand command,
    required String expectedContent,
  }) async {
    final title = command.title.trim();
    final description = command.description.trim();
    final commandText = command.command.trim();
    if (title.isEmpty || commandText.isEmpty) {
      throw const BatchCommandStoreException(
        BatchCommandStoreFailure.titleAndCommandRequired,
      );
    }

    final file = File(filePath);
    final content = await file.readAsString();
    _ensureUnchanged(content, expectedContent);
    final (:document, :commands) = _commandNodes(content);
    final lineEnding = content.contains('\r\n') ? '\r\n' : '\n';
    final lines = content.split(lineEnding);
    final commandsLine = _keyLine(document, 'commands');
    final commandsIndent = _leadingWhitespace(lines[commandsLine]).length;
    final keyContent = lines[commandsLine].trim();
    if (commands.isEmpty && keyContent == 'commands: []') {
      lines[commandsLine] = '${' ' * commandsIndent}commands:';
    } else if (!keyContent.endsWith(':')) {
      throw const BatchCommandStoreException(
        BatchCommandStoreFailure.unsupportedCommandListFormat,
      );
    }

    final insertionLine = _listEnd(lines, commandsLine, commandsIndent);
    final itemIndent = ' ' * (commandsIndent + 2);
    final fieldIndent = ' ' * (commandsIndent + 4);
    final newLines = [
      '$itemIndent- title: ${jsonEncode(title)}',
      if (description.isNotEmpty)
        '${fieldIndent}description: ${jsonEncode(description)}',
      '${fieldIndent}command: ${jsonEncode(commandText)}',
    ];
    lines.insertAll(insertionLine, newLines);

    await _replaceValidated(
      filePath: filePath,
      expectedContent: expectedContent,
      updatedContent: lines.join(lineEnding),
      validate: (config) {
        final added = config.commands.last;
        if (added.title != title ||
            added.description != description ||
            added.command != commandText) {
          throw const BatchCommandStoreException(
            BatchCommandStoreFailure.newCommandNotValid,
          );
        }
      },
    );
  }

  static Future<void> deleteCommand({
    required String filePath,
    required int commandIndex,
    required String expectedContent,
  }) async {
    final file = File(filePath);
    final content = await file.readAsString();
    _ensureUnchanged(content, expectedContent);
    final (:document, :commands) = _commandNodes(content);
    if (commandIndex < 0 || commandIndex >= commands.length) {
      throw const BatchCommandStoreException(
        BatchCommandStoreFailure.commandToDeleteNotFound,
      );
    }

    final lineEnding = content.contains('\r\n') ? '\r\n' : '\n';
    final lines = content.split(lineEnding);
    final commandsLine = _keyLine(document, 'commands');
    final commandsIndent = _leadingWhitespace(lines[commandsLine]).length;
    final itemIndent = commandsIndent + 2;
    final listEnd = _listEnd(lines, commandsLine, commandsIndent);
    final itemLines = <int>[];
    for (var index = commandsLine + 1; index < listEnd; index++) {
      final line = lines[index];
      final trimmed = line.trimLeft();
      if (_leadingWhitespace(line).length == itemIndent &&
          (trimmed == '-' || trimmed.startsWith('- '))) {
        itemLines.add(index);
      }
    }
    if (itemLines.length != commands.length) {
      throw const BatchCommandStoreException(
        BatchCommandStoreFailure.unsupportedCommandListFormat,
      );
    }

    final start = itemLines[commandIndex];
    final end = commandIndex + 1 < itemLines.length
        ? itemLines[commandIndex + 1]
        : listEnd;
    for (var index = end - 1; index >= start; index--) {
      lines.removeAt(index);
    }
    if (commands.length == 1) {
      lines[commandsLine] = '${' ' * commandsIndent}commands: []';
    }

    await _replaceValidated(
      filePath: filePath,
      expectedContent: expectedContent,
      updatedContent: lines.join(lineEnding),
      validate: (config) {
        if (config.commands.length != commands.length - 1) {
          throw const BatchCommandStoreException(
            BatchCommandStoreFailure.commandNotFullyDeleted,
          );
        }
      },
    );
  }

  static Future<void> _replaceValidated({
    required String filePath,
    required String expectedContent,
    required String updatedContent,
    required void Function(BatchCommandConfig config) validate,
  }) async {
    final file = File(filePath);
    final temporary = File('$filePath.tmp');
    final backup = File('$filePath.bak');
    await temporary.writeAsString(updatedContent, flush: true);
    try {
      validate(ConfigLoader.loadBatchConfig(temporary.path));
      _ensureUnchanged(await file.readAsString(), expectedContent);
      if (await backup.exists()) await backup.delete();
      await file.copy(backup.path);
      _ensureUnchanged(await backup.readAsString(), expectedContent);
      _ensureUnchanged(await file.readAsString(), expectedContent);
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  static ({YamlMap document, YamlList commands}) _commandNodes(String content) {
    final document = loadYamlNode(content);
    if (document is! YamlMap) {
      throw const BatchCommandStoreException(
        BatchCommandStoreFailure.invalidYamlRoot,
      );
    }
    final commands = _nodeFor(document, 'commands');
    if (commands is! YamlList) {
      throw const BatchCommandStoreException(
        BatchCommandStoreFailure.missingCommandList,
      );
    }
    return (document: document, commands: commands);
  }

  static int _listEnd(List<String> lines, int keyLine, int keyIndent) {
    for (var index = keyLine + 1; index < lines.length; index++) {
      final line = lines[index];
      final trimmed = line.trimLeft();
      if (trimmed.isNotEmpty &&
          !trimmed.startsWith('#') &&
          _leadingWhitespace(line).length <= keyIndent) {
        return index;
      }
    }
    return lines.length;
  }

  static void _ensureUnchanged(String content, String expectedContent) {
    if (content != expectedContent) {
      throw const BatchCommandStoreException(
        BatchCommandStoreFailure.fileChangedMeanwhile,
      );
    }
  }

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
    throw BatchCommandStoreException(
      BatchCommandStoreFailure.missingField,
      key,
    );
  }

  static String _leadingWhitespace(String value) =>
      RegExp(r'^\s*').firstMatch(value)!.group(0)!;
}
