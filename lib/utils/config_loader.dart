import 'dart:io';

import 'package:yaml/yaml.dart';

import '../models/batch_command.dart';
import '../models/command_config.dart';
import '../models/config_item.dart';

class ConfigFormatException implements Exception {
  final String filePath;
  final String fieldPath;
  final String message;

  const ConfigFormatException(this.filePath, this.fieldPath, this.message);

  @override
  String toString() => '$filePath: $fieldPath: $message';
}

class ConfigLoader {
  static List<ConfigItem> loadConfigs(String dirPath) {
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
          final batch = _parseBatchDocument(doc, file.path);
          items.add(
            ConfigItem(
              command: _batchDisplayName(name),
              description: batch.commands.length == 1
                  ? '1 Befehl in dieser Datei'
                  : '${batch.commands.length} Befehle in dieser Datei',
              filePath: file.path,
              isBatch: true,
            ),
          );
          continue;
        }

        final command = doc['command'];
        if (command is! String || command.trim().isEmpty) continue;
        final displayName = _optionalString(
          doc,
          'display_name',
          file.path,
          'display_name',
        );
        items.add(
          ConfigItem(
            command: displayName ?? command,
            description: doc['description']?.toString() ?? 'No description',
            filePath: file.path,
          ),
        );
      } on Object catch (error) {
        items.add(
          ConfigItem(
            command: 'Fehler: $name',
            description: error.toString(),
            filePath: file.path,
            error: error.toString(),
          ),
        );
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

  static CommandConfig loadConfig(String filePath) {
    final doc = _readDocument(filePath);
    final schemaVersion = _schemaVersion(doc, filePath);
    final command = _requiredString(doc, 'command', filePath, 'command');
    final displayName = _optionalString(
      doc,
      'display_name',
      filePath,
      'display_name',
    );
    final description =
        _optionalString(doc, 'description', filePath, 'description') ?? '';
    final helpText = _optionalString(doc, 'help_text', filePath, 'help_text');

    final rawParameters = doc['parameters'];
    if (rawParameters != null && rawParameters is! List) {
      throw ConfigFormatException(
        filePath,
        'parameters',
        'muss eine Liste sein',
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
          'muss ein Objekt sein',
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
          'Parametername "$name" ist doppelt vorhanden',
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
      );
      if (type == CommandParameterType.options && options.isEmpty) {
        throw ConfigFormatException(
          filePath,
          '$fieldPath.options',
          'Optionsparameter benötigt mindestens einen Eintrag',
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
            'hat nicht den zum Parametertyp passenden Datentyp',
          );
        }
        if (type == CommandParameterType.options &&
            !options.any((option) => option.value == defaultValue)) {
          throw ConfigFormatException(
            filePath,
            '$fieldPath.default',
            'ist nicht in options enthalten',
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
          'Button benötigt ein ausführbares Programm',
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
              _optionalString(
                rawParameter,
                'description',
                filePath,
                '$fieldPath.description',
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
          example: _optionalString(
            rawParameter,
            'example',
            filePath,
            '$fieldPath.example',
          ),
          note: _optionalString(
            rawParameter,
            'note',
            filePath,
            '$fieldPath.note',
          ),
          label: _optionalString(
            rawParameter,
            'label',
            filePath,
            '$fieldPath.label',
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
            'verweist auf unbekannten Parameter "$reference"',
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
            'Bedingung darf nicht auf den eigenen Parameter verweisen',
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
            'Bedingungswert passt nicht zum Typ von "${condition.parameter}"',
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
            'Bedingungswert ist keine Option von "${condition.parameter}"',
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

  static BatchCommandConfig loadBatchConfig(String filePath) {
    return _parseBatchDocument(_readDocument(filePath), filePath);
  }

  static BatchCommandConfig _parseBatchDocument(Map doc, String filePath) {
    _schemaVersion(doc, filePath);
    final rawCommands = doc['commands'];
    if (rawCommands is! List) {
      throw ConfigFormatException(filePath, 'commands', 'muss eine Liste sein');
    }

    final commands = <BatchCommand>[];
    for (var index = 0; index < rawCommands.length; index++) {
      final rawCommand = rawCommands[index];
      final fieldPath = 'commands[$index]';
      if (rawCommand is! Map) {
        throw ConfigFormatException(
          filePath,
          fieldPath,
          'muss ein Objekt sein',
        );
      }
      commands.add(
        BatchCommand(
          title:
              _optionalString(
                rawCommand,
                'title',
                filePath,
                '$fieldPath.title',
              ) ??
              'Ohne Titel',
          description:
              _optionalString(
                rawCommand,
                'description',
                filePath,
                '$fieldPath.description',
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
      throw ConfigFormatException(filePath, r'$', 'Datei wurde nicht gefunden');
    }
    try {
      final document = loadYaml(file.readAsStringSync());
      if (document is! Map) {
        throw ConfigFormatException(filePath, r'$', 'muss ein Objekt sein');
      }
      return document;
    } on ConfigFormatException {
      rethrow;
    } on FileSystemException catch (error) {
      throw ConfigFormatException(
        filePath,
        r'$',
        'Datei konnte nicht gelesen werden: ${error.message}',
      );
    } on Object catch (error) {
      throw ConfigFormatException(filePath, r'$', 'ungültiges YAML: $error');
    }
  }

  static int _schemaVersion(Map doc, String filePath) {
    final value = doc['schema_version'];
    if (value == null) return 0;
    if (value is! int || value != 1) {
      throw ConfigFormatException(
        filePath,
        'schema_version',
        'unterstützt wird nur Version 1',
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
      throw ConfigFormatException(filePath, fieldPath, 'muss Text enthalten');
    }
    return value;
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
      throw ConfigFormatException(filePath, fieldPath, 'muss Text enthalten');
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
        'muss true oder false sein',
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
        'muss eine Ganzzahl sein',
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
        'muss eine Textliste sein',
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
  ) {
    if (value == null) return const [];
    if (value is! List) {
      throw ConfigFormatException(filePath, fieldPath, 'muss eine Liste sein');
    }
    final options = <CommandOption>[];
    final values = <String>{};
    for (var index = 0; index < value.length; index++) {
      final rawOption = value[index];
      if (rawOption is! Map) {
        throw ConfigFormatException(
          filePath,
          '$fieldPath[$index]',
          'muss ein Objekt sein',
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
          'Optionswert "$optionValue" ist doppelt vorhanden',
        );
      }
      options.add(
        CommandOption(
          value: optionValue,
          description:
              _optionalString(
                rawOption,
                'description',
                filePath,
                '$fieldPath[$index].description',
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
        'unbekannter Parametertyp "$value"',
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
          'enthält unbekannte Gruppenfelder: ${unknownGroupKeys.join(', ')}',
        );
      }
      if (value.containsKey('all') && value.containsKey('any')) {
        throw ConfigFormatException(
          filePath,
          fieldPath,
          'darf nicht gleichzeitig all und any enthalten',
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
        'muss mindestens eine Bedingung enthalten',
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
          'muss ein Objekt sein',
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
          'enthält unbekannte Felder: ${unknownKeys.join(', ')}',
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
          'darf nur equals, in oder active verwenden',
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
            'muss eine nicht leere Liste sein',
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
            'muss true oder false sein',
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
      'muss Text, true oder false sein',
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
        'muss file, directory oder any sein',
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
        'muss automatic, before_command, argument oder pipeline sein',
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
        'muss automatic, separated oder attached sein',
      ),
    };
  }
}
