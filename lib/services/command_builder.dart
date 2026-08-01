import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:process_run/shell.dart' show stringToArguments;

import '../models/command_config.dart';

enum CommandShell { posix, windowsCmd, powerShell }

class CommandBuildException implements Exception {
  final String message;

  const CommandBuildException(this.message);

  @override
  String toString() => message;
}

class CommandBuilder {
  final CommandConfig config;
  final Map<String, Object?> values;
  final CommandShell shell;

  const CommandBuilder({
    required this.config,
    required this.values,
    required this.shell,
  });

  String build() {
    _validate();

    final parameters = [...config.parameters]
      ..sort((a, b) {
        final order = a.order.compareTo(b.order);
        return order != 0 ? order : a.sourceIndex.compareTo(b.sourceIndex);
      });
    final beforeCommand = <String>[];
    final arguments = <String>[];
    final pipelines = <List<String>>[];

    for (final parameter in parameters) {
      if (parameter.type == CommandParameterType.button ||
          !config.isParameterVisible(parameter, values)) {
        continue;
      }
      final value = values[parameter.name];
      if (!_isActive(value)) continue;

      final placement = _placement(parameter);
      if (placement == CommandParameterPlacement.pipeline) {
        final pipeline = [..._configuredTokens(parameter.flag)];
        if (pipeline.firstOrNull == '|') pipeline.removeAt(0);
        if (pipeline.isEmpty) {
          throw CommandBuildException(
            'Pipeline "${parameter.name}" benötigt ein Kommando.',
          );
        }
        pipelines.add(pipeline);
        continue;
      }

      final rendered = _parameterTokens(parameter, value);
      if (placement == CommandParameterPlacement.beforeCommand) {
        beforeCommand.addAll(rendered);
      } else {
        arguments.addAll(rendered);
      }
    }

    final commandTokens = _configuredTokens(
      config.command.replaceAll('_', ' '),
    );
    if (commandTokens.isEmpty) {
      throw const CommandBuildException('Das auszuführende Kommando ist leer.');
    }

    var result = _render([...beforeCommand, ...commandTokens, ...arguments]);
    for (final pipeline in pipelines) {
      result = '$result | ${_render(pipeline)}';
    }
    return result;
  }

  String buildAction(CommandParameter parameter) {
    if (parameter.type != CommandParameterType.button ||
        parameter.executable == null) {
      throw const CommandBuildException('Ungültige Button-Aktion.');
    }
    return _render([parameter.executable!, ...parameter.args]);
  }

  void _validate() {
    for (final parameter in config.parameters) {
      if (parameter.type == CommandParameterType.button ||
          !config.isParameterVisible(parameter, values)) {
        continue;
      }
      final value = values[parameter.name];
      final active = _isActive(value);
      if (config.isParameterRequired(parameter, values) && !active) {
        throw CommandBuildException(
          'Erforderlicher Parameter "${parameter.name}" fehlt.',
        );
      }
      if (!active) continue;

      for (final dependency in parameter.dependsOn) {
        final dependencyParameter = config.parameters.singleWhere(
          (candidate) => candidate.name == dependency,
        );
        if (!config.isParameterVisible(dependencyParameter, values) ||
            !_isActive(values[dependency])) {
          throw CommandBuildException(
            'Parameter "${parameter.name}" erfordert "$dependency".',
          );
        }
      }
      for (final conflict in parameter.conflictsWith) {
        final conflictParameter = config.parameters.singleWhere(
          (candidate) => candidate.name == conflict,
        );
        if (config.isParameterVisible(conflictParameter, values) &&
            _isActive(values[conflict])) {
          throw CommandBuildException(
            'Parameter "${parameter.name}" kann nicht mit "$conflict" verwendet werden.',
          );
        }
      }
      if (parameter.mustDiffer && parameter.dependsOn.isNotEmpty) {
        final dependency = parameter.dependsOn.first;
        final dependencyParameter = config.parameters.singleWhere(
          (candidate) => candidate.name == dependency,
        );
        final valuesAreEqual =
            parameter.type == CommandParameterType.filepath &&
                dependencyParameter.type == CommandParameterType.filepath
            ? _samePath(value.toString(), values[dependency].toString())
            : _normalized(value) == _normalized(values[dependency]);
        if (valuesAreEqual) {
          throw CommandBuildException(
            'Parameter "${parameter.name}" muss sich von "$dependency" unterscheiden.',
          );
        }
      }
      if (parameter.type == CommandParameterType.options &&
          !parameter.options.any((option) => option.value == value)) {
        throw CommandBuildException(
          'Parameter "${parameter.name}" enthält einen ungültigen Optionswert.',
        );
      }
    }

    final command = config.command.replaceAll('_', ' ').trim();
    if (command == 'dd' &&
        _isActive(values['input_file']) &&
        _isActive(values['output_file']) &&
        _samePath(
          values['input_file'].toString(),
          values['output_file'].toString(),
        )) {
      throw const CommandBuildException(
        'Eingabe und Ausgabe von dd müssen sich unterscheiden.',
      );
    }
  }

  List<String> _parameterTokens(CommandParameter parameter, Object? value) {
    if (parameter.type == CommandParameterType.boolean) {
      return _configuredTokens(parameter.flag);
    }

    final valueTokens = switch (parameter.type) {
      CommandParameterType.options => _configuredTokens(value.toString()),
      CommandParameterType.textList => _textListTokens(parameter, value),
      _ => [
        '${parameter.prefix ?? ''}${value.toString()}${parameter.suffix ?? ''}',
      ],
    };
    final flag = parameter.flag;
    if (flag == null || flag.isEmpty) return valueTokens;

    final join = parameter.join == CommandValueJoin.automatic
        ? (flag.endsWith('=')
              ? CommandValueJoin.attached
              : CommandValueJoin.separated)
        : parameter.join;
    if (join == CommandValueJoin.attached) {
      if (valueTokens.length != 1) {
        throw CommandBuildException(
          'Parameter "${parameter.name}" kann mehrere Werte nicht direkt an ein Flag anhängen.',
        );
      }
      return ['$flag${valueTokens.single}'];
    }
    return [..._configuredTokens(flag), ...valueTokens];
  }

  CommandParameterPlacement _placement(CommandParameter parameter) {
    if (parameter.placement != CommandParameterPlacement.automatic) {
      return parameter.placement;
    }
    if (parameter.flag?.trimLeft().startsWith('|') ?? false) {
      return CommandParameterPlacement.pipeline;
    }
    if (parameter.order == 0 || parameter.flag == 'sudo') {
      return CommandParameterPlacement.beforeCommand;
    }
    return CommandParameterPlacement.argument;
  }

  List<String> _configuredTokens(String? value) {
    if (value == null || value.trim().isEmpty) return const [];
    try {
      return stringToArguments(value.trim());
    } on Object catch (error) {
      throw CommandBuildException('Ungültiger Konfigurationswert: $error');
    }
  }

  List<String> _textListTokens(CommandParameter parameter, Object? value) {
    if (value is! Iterable) {
      throw CommandBuildException(
        'Parameter "${parameter.name}" muss eine Liste enthalten.',
      );
    }
    return value
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .map(
          (entry) => '${parameter.prefix ?? ''}$entry${parameter.suffix ?? ''}',
        )
        .toList();
  }

  String _render(List<String> tokens) => tokens.map(_quote).join(' ');

  String _quote(String value) {
    if (value.contains('\u0000') ||
        value.contains('\r') ||
        value.contains('\n')) {
      throw const CommandBuildException(
        'Kommandoargumente dürfen keine Steuerzeichen enthalten.',
      );
    }
    return switch (shell) {
      CommandShell.posix => _quotePosix(value),
      CommandShell.windowsCmd => _quoteWindows(value),
      CommandShell.powerShell => _quotePowerShell(value),
    };
  }

  String _quotePosix(String value) {
    if (value.isEmpty) return "''";
    if (RegExp(r'^[A-Za-z0-9_@%+=:,./-]+$').hasMatch(value)) return value;
    return "'${value.replaceAll("'", "'\"'\"'")}'";
  }

  String _quoteWindows(String value) {
    if (value.contains('%') || value.contains('!') || value.contains('"')) {
      throw const CommandBuildException(
        'Die Windows-Shell unterstützt dieses Zeichen in Eingabewerten nicht sicher.',
      );
    }
    if (value.isEmpty) return '""';
    if (RegExp(r'^[A-Za-z0-9_@+=:,./\\-]+$').hasMatch(value)) return value;
    final trailingBackslashes = RegExp(r'\\+$').firstMatch(value)?.group(0);
    if (trailingBackslashes != null) {
      value = '$value$trailingBackslashes';
    }
    return '"$value"';
  }

  String _quotePowerShell(String value) {
    if (value.isEmpty) return "''";
    if (RegExp(r'^[A-Za-z0-9_@%+=:,./\\-]+$').hasMatch(value)) return value;
    return "'${value.replaceAll("'", "''")}'";
  }

  bool _isActive(Object? value) => isCommandValueActive(value);

  String _normalized(Object? value) => value?.toString().trim() ?? '';

  bool _samePath(String first, String second) {
    try {
      if (FileSystemEntity.typeSync(first) != FileSystemEntityType.notFound &&
          FileSystemEntity.typeSync(second) != FileSystemEntityType.notFound &&
          FileSystemEntity.identicalSync(first, second)) {
        return true;
      }
    } on FileSystemException {
      // Fall back to lexical canonicalization for inaccessible paths.
    }
    return path.equals(
      path.canonicalize(path.absolute(first)),
      path.canonicalize(path.absolute(second)),
    );
  }
}
