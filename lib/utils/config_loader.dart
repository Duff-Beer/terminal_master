import 'dart:io';

import 'package:yaml/yaml.dart';

import '../models/batch_command.dart';
import '../models/command_config.dart';
import '../models/config_item.dart';

/// Why a configuration file was rejected.
///
/// The loader reports a code rather than a sentence so the UI can render the
/// reason in the active language. [ConfigFormatException.message] stays
/// English on purpose: it feeds logs and `toString()`, not the UI.
enum ConfigErrorReason {
  mustBeList,
  mustBeNonEmptyList,
  mustBeObject,
  mustBeText,
  mustBeBoolean,
  mustBeInteger,
  mustBeTextList,
  mustBeTextOrBoolean,
  mustBeFilePickerMode,
  mustBeExecutionMode,
  mustBeAttachmentMode,
  optionsParameterNeedsEntry,
  buttonNeedsExecutable,
  typeMismatch,
  notInOptions,
  duplicateParameterName,
  duplicateOptionValue,
  unknownParameterType,
  unknownParameterReference,
  unknownFields,
  unknownGroupFields,
  conditionSelfReference,
  conditionValueTypeMismatch,
  conditionValueNotAnOption,
  bothAllAndAny,
  needsAtLeastOneCondition,
  onlyEqualsInOrActive,
  unsupportedSchemaVersion,
  fileNotFound,
  fileUnreadable,
  invalidYaml,
}

class ConfigFormatException implements Exception {
  final String filePath;
  final String fieldPath;
  final ConfigErrorReason reason;

  /// The offending value, name, or nested error the reason refers to, when it
  /// has one. Never translated — it echoes content from the file.
  final String? detail;

  const ConfigFormatException(
    this.filePath,
    this.fieldPath,
    this.reason, [
    this.detail,
  ]);

  /// Developer-facing English description. User-facing text is produced by the
  /// localized presenter in the UI layer, never here.
  String get message => switch (reason) {
    ConfigErrorReason.mustBeList => 'must be a list',
    ConfigErrorReason.mustBeNonEmptyList => 'must be a non-empty list',
    ConfigErrorReason.mustBeObject => 'must be an object',
    ConfigErrorReason.mustBeText => 'must contain text',
    ConfigErrorReason.mustBeBoolean => 'must be true or false',
    ConfigErrorReason.mustBeInteger => 'must be an integer',
    ConfigErrorReason.mustBeTextList => 'must be a list of text',
    ConfigErrorReason.mustBeTextOrBoolean => 'must be text, true or false',
    ConfigErrorReason.mustBeFilePickerMode => 'must be file, directory or any',
    ConfigErrorReason.mustBeExecutionMode =>
      'must be automatic, before_command, argument or pipeline',
    ConfigErrorReason.mustBeAttachmentMode =>
      'must be automatic, separated or attached',
    ConfigErrorReason.optionsParameterNeedsEntry =>
      'an options parameter needs at least one entry',
    ConfigErrorReason.buttonNeedsExecutable =>
      'a button needs an executable program',
    ConfigErrorReason.typeMismatch =>
      'does not match the data type of the parameter type',
    ConfigErrorReason.notInOptions => 'is not contained in options',
    ConfigErrorReason.duplicateParameterName =>
      'parameter name "$detail" is duplicated',
    ConfigErrorReason.duplicateOptionValue =>
      'option value "$detail" is duplicated',
    ConfigErrorReason.unknownParameterType =>
      'unknown parameter type "$detail"',
    ConfigErrorReason.unknownParameterReference =>
      'refers to unknown parameter "$detail"',
    ConfigErrorReason.unknownFields => 'contains unknown fields: $detail',
    ConfigErrorReason.unknownGroupFields =>
      'contains unknown group fields: $detail',
    ConfigErrorReason.conditionSelfReference =>
      'a condition must not refer to its own parameter',
    ConfigErrorReason.conditionValueTypeMismatch =>
      'condition value does not match the type of "$detail"',
    ConfigErrorReason.conditionValueNotAnOption =>
      'condition value is not an option of "$detail"',
    ConfigErrorReason.bothAllAndAny =>
      'must not contain all and any at the same time',
    ConfigErrorReason.needsAtLeastOneCondition =>
      'must contain at least one condition',
    ConfigErrorReason.onlyEqualsInOrActive =>
      'may only use equals, in or active',
    ConfigErrorReason.unsupportedSchemaVersion =>
      'only version $detail is supported',
    ConfigErrorReason.fileNotFound => 'file was not found',
    ConfigErrorReason.fileUnreadable => 'file could not be read: $detail',
    ConfigErrorReason.invalidYaml => 'invalid YAML: $detail',
  };

  @override
  String toString() => '$filePath: $fieldPath: $message';
}

class ConfigLoader {
  /// Schema versions the loader accepts. Version 2 adds language-suffixed
  /// fields (`description.en`); version 1 files stay valid unchanged.
  static const supportedSchemaVersions = [1, 2];

  static List<ConfigItem> loadConfigs(String dirPath, {String? languageCode}) {
    final directory = Directory(dirPath);
    if (!directory.existsSync()) return [];

    final files = directory.listSync().whereType<File>().where((file) {
      final path = file.path.toLowerCase();
      return path.endsWith('.yaml') || path.endsWith('.yml');
    });

    final items = <ConfigItem>[];
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      try {
        final isBatch = name.startsWith('-');
        final doc = _readDocument(file.path);

        if (isBatch) {
          final batch = _parseBatchDocument(doc, file.path, languageCode);
          items.add(
            ConfigItem(
              command: _batchDisplayName(name),
              filePath: file.path,
              isBatch: true,
              batchCommandCount: batch.commands.length,
            ),
          );
          continue;
        }

        final command = doc['command'];
        if (command is! String || command.trim().isEmpty) continue;
        final displayName = _localizedString(
          doc,
          'display_name',
          file.path,
          'display_name',
          languageCode,
        );
        items.add(
          ConfigItem(
            command: displayName ?? command,
            description: _localizedString(
              doc,
              'description',
              file.path,
              'description',
              languageCode,
            ),
            filePath: file.path,
          ),
        );
      } on Object catch (error) {
        items.add(ConfigItem(command: name, filePath: file.path, error: error));
      }
    }

    items.sort((a, b) => a.command.compareTo(b.command));
    return items;
  }

  static String _batchDisplayName(String fileName) {
    final name = fileName
        .replaceFirst('-', '')
        .replaceFirst(RegExp(r'\.(?:yaml|yml)$', caseSensitive: false), '');
    return name
        .split(RegExp(r'[_\-\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  static CommandConfig loadConfig(String filePath, {String? languageCode}) {
    final doc = _readDocument(filePath);
    final schemaVersion = _schemaVersion(doc, filePath);
    final command = _requiredString(doc, 'command', filePath, 'command');
    final displayName = _localizedString(
      doc,
      'display_name',
      filePath,
      'display_name',
      languageCode,
    );
    final description =
        _localizedString(
          doc,
          'description',
          filePath,
          'description',
          languageCode,
        ) ??
        '';
    final helpText = _localizedString(
      doc,
      'help_text',
      filePath,
      'help_text',
      languageCode,
    );

    final rawParameters = doc['parameters'];
    if (rawParameters != null && rawParameters is! List) {
      throw ConfigFormatException(
        filePath,
        'parameters',
        ConfigErrorReason.mustBeList,
      );
    }

    final parameters = <CommandParameter>[];
    final names = <String>{};
    for (
      var index = 0;
      index < (rawParameters as List? ?? const []).length;
      index++
    ) {
      final fieldPath = 'parameters[$index]';
      final rawParameter = (rawParameters as List)[index];
      if (rawParameter is! Map) {
        throw ConfigFormatException(
          filePath,
          fieldPath,
          ConfigErrorReason.mustBeObject,
        );
      }

      final name = _requiredString(
        rawParameter,
        'name',
        filePath,
        '$fieldPath.name',
      );
      if (!names.add(name)) {
        if (schemaVersion == 0) continue;
        throw ConfigFormatException(
          filePath,
          '$fieldPath.name',
          ConfigErrorReason.duplicateParameterName,
          name,
        );
      }

      final typeName = _requiredString(
        rawParameter,
        'type',
        filePath,
        '$fieldPath.type',
      );
      final type = _parseType(typeName, filePath, '$fieldPath.type');
      final options = _parseOptions(
        rawParameter['options'],
        filePath,
        '$fieldPath.options',
        languageCode,
      );
      if (type == CommandParameterType.options && options.isEmpty) {
        throw ConfigFormatException(
          filePath,
          '$fieldPath.options',
          ConfigErrorReason.optionsParameterNeedsEntry,
        );
      }

      final rawDefaultValue = rawParameter['default'];
      Object? defaultValue = rawDefaultValue;
      if (defaultValue != null) {
        final validType = switch (type) {
          CommandParameterType.boolean => defaultValue is bool,
          CommandParameterType.textList =>
            defaultValue is List &&
                defaultValue.every((entry) => entry is String),
          _ => defaultValue is String,
        };
        if (!validType) {
          throw ConfigFormatException(
            filePath,
            '$fieldPath.default',
            ConfigErrorReason.typeMismatch,
          );
        }
        if (type == CommandParameterType.options &&
            !options.any((option) => option.value == defaultValue)) {
          throw ConfigFormatException(
            filePath,
            '$fieldPath.default',
            ConfigErrorReason.notInOptions,
          );
        }
        if (type == CommandParameterType.textList) {
          defaultValue = List<String>.unmodifiable(
            (rawDefaultValue as List).cast<String>(),
          );
        }
      }

      final executable = _optionalString(
        rawParameter,
        'executable',
        filePath,
        '$fieldPath.executable',
      );
      if (type == CommandParameterType.button && executable == null) {
        throw ConfigFormatException(
          filePath,
          '$fieldPath.executable',
          ConfigErrorReason.buttonNeedsExecutable,
        );
      }

      var prefix = _optionalString(
        rawParameter,
        'prefix',
        filePath,
        '$fieldPath.prefix',
        allowEmpty: true,
      );
      if (schemaVersion == 0 &&
          command == 'nmap' &&
          name == 'target' &&
          prefix == '- ') {
        prefix = null;
      }

      parameters.add(
        CommandParameter(
          name: name,
          description:
              _localizedString(
                rawParameter,
                'description',
                filePath,
                '$fieldPath.description',
                languageCode,
              ) ??
              '',
          type: type,
          sourceIndex: index,
          flag: _optionalString(
            rawParameter,
            'flag',
            filePath,
            '$fieldPath.flag',
            allowEmpty: true,
          ),
          prefix: prefix,
          suffix: _optionalString(
            rawParameter,
            'suffix',
            filePath,
            '$fieldPath.suffix',
            allowEmpty: true,
          ),
          dependsOn: _stringList(
            rawParameter['depends_on'],
            filePath,
            '$fieldPath.depends_on',
          ),
          conflictsWith: _stringList(
            rawParameter['conflicts_with'],
            filePath,
            '$fieldPath.conflicts_with',
          ),
          mustDiffer: _bool(
            rawParameter,
            'must_differ',
            filePath,
            '$fieldPath.must_differ',
          ),
          required: _bool(
            rawParameter,
            'required',
            filePath,
            '$fieldPath.required',
          ),
          order: _int(rawParameter, 'order', filePath, '$fieldPath.order'),
          options: options,
          defaultValue: defaultValue,
          mode: _parseMode(rawParameter['mode'], filePath, '$fieldPath.mode'),
          placement: _parsePlacement(
            rawParameter['placement'],
            filePath,
            '$fieldPath.placement',
          ),
          join: _parseJoin(rawParameter['join'], filePath, '$fieldPath.join'),
          example: _localizedString(
            rawParameter,
            'example',
            filePath,
            '$fieldPath.example',
            languageCode,
          ),
          note: _localizedString(
            rawParameter,
            'note',
            filePath,
            '$fieldPath.note',
            languageCode,
          ),
          label: _localizedString(
            rawParameter,
            'label',
            filePath,
            '$fieldPath.label',
            languageCode,
          ),
          executable: executable,
          args: _arguments(rawParameter['args'], filePath, '$fieldPath.args'),
          visibleWhen: _parseConditionGroup(
            rawParameter['visible_when'],
            filePath,
            '$fieldPath.visible_when',
          ),
          requiredWhen: _parseConditionGroup(
            rawParameter['required_when'],
            filePath,
            '$fieldPath.required_when',
          ),
        ),
      );
    }

    for (final parameter in parameters) {
      for (final reference in [
        ...parameter.dependsOn,
        ...parameter.conflictsWith,
        ...?parameter.visibleWhen?.conditions.map(
          (condition) => condition.parameter,
        ),
        ...?parameter.requiredWhen?.conditions.map(
          (condition) => condition.parameter,
        ),
      ]) {
        if (!names.contains(reference)) {
          throw ConfigFormatException(
            filePath,
            'parameters[${parameter.sourceIndex}]',
            ConfigErrorReason.unknownParameterReference,
            reference,
          );
        }
      }
      for (final condition in [
        ...?parameter.visibleWhen?.conditions,
        ...?parameter.requiredWhen?.conditions,
      ]) {
        if (condition.parameter == parameter.name) {
          throw ConfigFormatException(
            filePath,
            'parameters[${parameter.sourceIndex}]',
            ConfigErrorReason.conditionSelfReference,
          );
        }
        if (condition.expectedValues.isEmpty) continue;
        final referenced = parameters.singleWhere(
          (candidate) => candidate.name == condition.parameter,
        );
        final valuesHaveCorrectType =
            referenced.type == CommandParameterType.boolean
            ? condition.expectedValues.every((value) => value is bool)
            : condition.expectedValues.every((value) => value is String);
        if (!valuesHaveCorrectType) {
          throw ConfigFormatException(
            filePath,
            'parameters[${parameter.sourceIndex}]',
            ConfigErrorReason.conditionValueTypeMismatch,
            condition.parameter,
          );
        }
        if (referenced.type == CommandParameterType.options &&
            condition.expectedValues.any(
              (value) =>
                  !referenced.options.any((option) => option.value == value),
            )) {
          throw ConfigFormatException(
            filePath,
            'parameters[${parameter.sourceIndex}]',
            ConfigErrorReason.conditionValueNotAnOption,
            condition.parameter,
          );
        }
      }
    }

    return CommandConfig(
      command: command,
      displayName: displayName,
      description: description,
      helpText: helpText,
      parameters: parameters,
    );
  }

  static BatchCommandConfig loadBatchConfig(
    String filePath, {
    String? languageCode,
  }) {
    return _parseBatchDocument(_readDocument(filePath), filePath, languageCode);
  }

  static BatchCommandConfig _parseBatchDocument(
    Map doc,
    String filePath,
    String? languageCode,
  ) {
    _schemaVersion(doc, filePath);
    final rawCommands = doc['commands'];
    if (rawCommands is! List) {
      throw ConfigFormatException(
        filePath,
        'commands',
        ConfigErrorReason.mustBeList,
      );
    }

    final commands = <BatchCommand>[];
    for (var index = 0; index < rawCommands.length; index++) {
      final rawCommand = rawCommands[index];
      final fieldPath = 'commands[$index]';
      if (rawCommand is! Map) {
        throw ConfigFormatException(
          filePath,
          fieldPath,
          ConfigErrorReason.mustBeObject,
        );
      }
      commands.add(
        BatchCommand(
          title:
              _localizedString(
                rawCommand,
                'title',
                filePath,
                '$fieldPath.title',
                languageCode,
              ) ??
              '',
          description:
              _localizedString(
                rawCommand,
                'description',
                filePath,
                '$fieldPath.description',
                languageCode,
              ) ??
              '',
          command: _requiredString(
            rawCommand,
            'command',
            filePath,
            '$fieldPath.command',
          ),
        ),
      );
    }
    return BatchCommandConfig(commands: List.unmodifiable(commands));
  }

  static Map _readDocument(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw ConfigFormatException(
        filePath,
        r'$',
        ConfigErrorReason.fileNotFound,
      );
    }
    try {
      final document = loadYaml(file.readAsStringSync());
      if (document is! Map) {
        throw ConfigFormatException(
          filePath,
          r'$',
          ConfigErrorReason.mustBeObject,
        );
      }
      return document;
    } on ConfigFormatException {
      rethrow;
    } on FileSystemException catch (error) {
      throw ConfigFormatException(
        filePath,
        r'$',
        ConfigErrorReason.fileUnreadable,
        error.message,
      );
    } on Object catch (error) {
      throw ConfigFormatException(
        filePath,
        r'$',
        ConfigErrorReason.invalidYaml,
        '$error',
      );
    }
  }

  static int _schemaVersion(Map doc, String filePath) {
    final value = doc['schema_version'];
    if (value == null) return 0;
    if (value is! int || !supportedSchemaVersions.contains(value)) {
      throw ConfigFormatException(
        filePath,
        'schema_version',
        ConfigErrorReason.unsupportedSchemaVersion,
        supportedSchemaVersions.join(', '),
      );
    }
    return value;
  }

  static String _requiredString(
    Map map,
    String key,
    String filePath,
    String fieldPath,
  ) {
    final value = map[key];
    if (value is! String || value.trim().isEmpty) {
      throw ConfigFormatException(
        filePath,
        fieldPath,
        ConfigErrorReason.mustBeText,
      );
    }
    return value;
  }

  /// Reads `<key>.<languageCode>` when the file provides it, otherwise `<key>`.
  ///
  /// This is what makes template files multilingual without a breaking change:
  /// a file that only has plain fields resolves exactly as it did before, and a
  /// file may translate some fields and leave others to the base language.
  static String? _localizedString(
    Map map,
    String key,
    String filePath,
    String fieldPath,
    String? languageCode,
  ) {
    if (languageCode != null) {
      final suffixed = '$key.$languageCode';
      if (map[suffixed] != null) {
        return _optionalString(
          map,
          suffixed,
          filePath,
          '$fieldPath.$languageCode',
        );
      }
    }
    return _optionalString(map, key, filePath, fieldPath);
  }

  static String? _optionalString(
    Map map,
    String key,
    String filePath,
    String fieldPath, {
    bool allowEmpty = false,
  }) {
    final value = map[key];
    if (value == null) return null;
    if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
      throw ConfigFormatException(
        filePath,
        fieldPath,
        ConfigErrorReason.mustBeText,
      );
    }
    return value;
  }

  static bool _bool(Map map, String key, String filePath, String fieldPath) {
    final value = map[key];
    if (value == null) return false;
    if (value is! bool) {
      throw ConfigFormatException(
        filePath,
        fieldPath,
        ConfigErrorReason.mustBeBoolean,
      );
    }
    return value;
  }

  static int _int(Map map, String key, String filePath, String fieldPath) {
    final value = map[key];
    if (value == null) return 1000;
    if (value is! int) {
      throw ConfigFormatException(
        filePath,
        fieldPath,
        ConfigErrorReason.mustBeInteger,
      );
    }
    return value;
  }

  static List<String> _stringList(
    Object? value,
    String filePath,
    String fieldPath,
  ) {
    if (value == null) return const [];
    if (value is! List || value.any((entry) => entry is! String)) {
      throw ConfigFormatException(
        filePath,
        fieldPath,
        ConfigErrorReason.mustBeTextList,
      );
    }
    return List<String>.unmodifiable(value.cast<String>());
  }

  static List<String> _arguments(
    Object? value,
    String filePath,
    String fieldPath,
  ) {
    if (value == null) return const [];
    if (value is String) {
      return value.trim().isEmpty
          ? const []
          : List.unmodifiable(value.trim().split(RegExp(r'\s+')));
    }
    return _stringList(value, filePath, fieldPath);
  }

  static List<CommandOption> _parseOptions(
    Object? value,
    String filePath,
    String fieldPath,
    String? languageCode,
  ) {
    if (value == null) return const [];
    if (value is! List) {
      throw ConfigFormatException(
        filePath,
        fieldPath,
        ConfigErrorReason.mustBeList,
      );
    }
    final options = <CommandOption>[];
    final values = <String>{};
    for (var index = 0; index < value.length; index++) {
      final rawOption = value[index];
      if (rawOption is! Map) {
        throw ConfigFormatException(
          filePath,
          '$fieldPath[$index]',
          ConfigErrorReason.mustBeObject,
        );
      }
      final optionValue = _requiredString(
        rawOption,
        'value',
        filePath,
        '$fieldPath[$index].value',
      );
      if (!values.add(optionValue)) {
        throw ConfigFormatException(
          filePath,
          '$fieldPath[$index].value',
          ConfigErrorReason.duplicateOptionValue,
          optionValue,
        );
      }
      options.add(
        CommandOption(
          value: optionValue,
          description:
              _localizedString(
                rawOption,
                'description',
                filePath,
                '$fieldPath[$index].description',
                languageCode,
              ) ??
              '',
        ),
      );
    }
    return List.unmodifiable(options);
  }

  static CommandParameterType _parseType(
    String value,
    String filePath,
    String fieldPath,
  ) {
    return switch (value) {
      'boolean' => CommandParameterType.boolean,
      'text' => CommandParameterType.text,
      'text_list' => CommandParameterType.textList,
      'options' => CommandParameterType.options,
      'filepath' => CommandParameterType.filepath,
      'button' => CommandParameterType.button,
      _ => throw ConfigFormatException(
        filePath,
        fieldPath,
        ConfigErrorReason.unknownParameterType,
        value,
      ),
    };
  }

  static CommandConditionGroup? _parseConditionGroup(
    Object? value,
    String filePath,
    String fieldPath,
  ) {
    if (value == null) return null;

    var matchAny = false;
    Object? rawConditions = value;
    if (value is Map &&
        (value.containsKey('all') || value.containsKey('any'))) {
      final unknownGroupKeys = value.keys
          .map((key) => key.toString())
          .where((key) => key != 'all' && key != 'any')
          .toList();
      if (unknownGroupKeys.isNotEmpty) {
        throw ConfigFormatException(
          filePath,
          fieldPath,
          ConfigErrorReason.unknownGroupFields,
          unknownGroupKeys.join(', '),
        );
      }
      if (value.containsKey('all') && value.containsKey('any')) {
        throw ConfigFormatException(
          filePath,
          fieldPath,
          ConfigErrorReason.bothAllAndAny,
        );
      }
      matchAny = value.containsKey('any');
      rawConditions = value[matchAny ? 'any' : 'all'];
    }

    final conditionValues = rawConditions is List
        ? rawConditions
        : <Object?>[rawConditions];
    if (conditionValues.isEmpty) {
      throw ConfigFormatException(
        filePath,
        fieldPath,
        ConfigErrorReason.needsAtLeastOneCondition,
      );
    }

    final conditions = <CommandCondition>[];
    for (var index = 0; index < conditionValues.length; index++) {
      final rawCondition = conditionValues[index];
      final conditionPath = '$fieldPath[$index]';
      if (rawCondition is! Map) {
        throw ConfigFormatException(
          filePath,
          conditionPath,
          ConfigErrorReason.mustBeObject,
        );
      }
      const allowedKeys = {'parameter', 'equals', 'in', 'active'};
      final unknownKeys = rawCondition.keys
          .map((key) => key.toString())
          .where((key) => !allowedKeys.contains(key))
          .toList();
      if (unknownKeys.isNotEmpty) {
        throw ConfigFormatException(
          filePath,
          conditionPath,
          ConfigErrorReason.unknownFields,
          unknownKeys.join(', '),
        );
      }
      final parameter = _requiredString(
        rawCondition,
        'parameter',
        filePath,
        '$conditionPath.parameter',
      );
      final hasEquals = rawCondition.containsKey('equals');
      final hasIn = rawCondition.containsKey('in');
      final hasActive = rawCondition.containsKey('active');
      if ([hasEquals, hasIn, hasActive].where((present) => present).length >
          1) {
        throw ConfigFormatException(
          filePath,
          conditionPath,
          ConfigErrorReason.onlyEqualsInOrActive,
        );
      }

      var expectedValues = const <Object>[];
      bool? active;
      if (hasEquals) {
        expectedValues = [
          _conditionValue(
            rawCondition['equals'],
            filePath,
            '$conditionPath.equals',
          ),
        ];
      } else if (hasIn) {
        final values = rawCondition['in'];
        if (values is! List || values.isEmpty) {
          throw ConfigFormatException(
            filePath,
            '$conditionPath.in',
            ConfigErrorReason.mustBeNonEmptyList,
          );
        }
        expectedValues = List<Object>.unmodifiable(
          values.indexed.map(
            (entry) => _conditionValue(
              entry.$2,
              filePath,
              '$conditionPath.in[${entry.$1}]',
            ),
          ),
        );
      } else {
        final rawActive = rawCondition['active'];
        if (hasActive && rawActive is! bool) {
          throw ConfigFormatException(
            filePath,
            '$conditionPath.active',
            ConfigErrorReason.mustBeBoolean,
          );
        }
        active = rawActive as bool? ?? true;
      }
      conditions.add(
        CommandCondition(
          parameter: parameter,
          expectedValues: expectedValues,
          active: active,
        ),
      );
    }
    return CommandConditionGroup(
      conditions: List.unmodifiable(conditions),
      matchAny: matchAny,
    );
  }

  static Object _conditionValue(
    Object? value,
    String filePath,
    String fieldPath,
  ) {
    if (value is String) return value;
    if (value is bool) return value;
    throw ConfigFormatException(
      filePath,
      fieldPath,
      ConfigErrorReason.mustBeTextOrBoolean,
    );
  }

  static FilePickerMode _parseMode(
    Object? value,
    String filePath,
    String fieldPath,
  ) {
    return switch (value) {
      null || 'file' => FilePickerMode.file,
      'directory' => FilePickerMode.directory,
      'any' => FilePickerMode.any,
      _ => throw ConfigFormatException(
        filePath,
        fieldPath,
        ConfigErrorReason.mustBeFilePickerMode,
      ),
    };
  }

  static CommandParameterPlacement _parsePlacement(
    Object? value,
    String filePath,
    String fieldPath,
  ) {
    return switch (value) {
      null || 'automatic' => CommandParameterPlacement.automatic,
      'before_command' => CommandParameterPlacement.beforeCommand,
      'argument' => CommandParameterPlacement.argument,
      'pipeline' => CommandParameterPlacement.pipeline,
      _ => throw ConfigFormatException(
        filePath,
        fieldPath,
        ConfigErrorReason.mustBeExecutionMode,
      ),
    };
  }

  static CommandValueJoin _parseJoin(
    Object? value,
    String filePath,
    String fieldPath,
  ) {
    return switch (value) {
      null || 'automatic' => CommandValueJoin.automatic,
      'separated' => CommandValueJoin.separated,
      'attached' => CommandValueJoin.attached,
      _ => throw ConfigFormatException(
        filePath,
        fieldPath,
        ConfigErrorReason.mustBeAttachmentMode,
      ),
    };
  }
}
