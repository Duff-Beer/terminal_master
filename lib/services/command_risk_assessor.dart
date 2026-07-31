import 'package:process_run/shell.dart' show stringToArguments;

import '../models/command_config.dart';

enum CommandRiskLevel { standard, elevated, destructive }

class CommandRiskAssessment {
  final CommandRiskLevel level;
  final List<String> reasons;
  final bool containsRawConfiguration;

  const CommandRiskAssessment({
    required this.level,
    this.reasons = const [],
    this.containsRawConfiguration = false,
  });

  bool get requiresAcknowledgement => level != CommandRiskLevel.standard;
}

class CommandRiskAssessor {
  const CommandRiskAssessor._();

  static CommandRiskAssessment assessConfig(
    CommandConfig config,
    Map<String, Object?> values,
  ) {
    var level = CommandRiskLevel.standard;
    final reasons = <String>[];
    final command = config.command.replaceAll('_', ' ').trim().toLowerCase();

    if (_containsExecutable(command, const {'rm'})) {
      level = CommandRiskLevel.destructive;
      reasons.add('rm kann Dateien und Verzeichnisse dauerhaft löschen.');
    }
    if (_containsExecutable(command, const {'dd'})) {
      level = CommandRiskLevel.destructive;
      reasons.add(
        'dd kann Dateien, Datenträger und Partitionen überschreiben.',
      );
    }

    for (final parameter in config.parameters) {
      if (values[parameter.name] != true) continue;
      if (parameter.name == 'force' ||
          parameter.flag == '--force' ||
          parameter.flag == '-f') {
        level = CommandRiskLevel.destructive;
        reasons.add('Die Force-Option überspringt normale Schutzabfragen.');
      }
      if (parameter.name == 'use_sudo' || parameter.flag == 'sudo') {
        if (level == CommandRiskLevel.standard) {
          level = CommandRiskLevel.elevated;
        }
        reasons.add('Das Kommando wird mit erhöhten Rechten ausgeführt.');
      }
    }

    return CommandRiskAssessment(
      level: level,
      reasons: List.unmodifiable(reasons.toSet()),
    );
  }

  static CommandRiskAssessment assessRawCommands(
    Iterable<String> commands, {
    bool containsRawConfiguration = true,
  }) {
    var level = CommandRiskLevel.standard;
    final reasons = <String>[];
    final joined = commands.join('\n').toLowerCase();

    if (_containsExecutable(joined, const {
      'rm',
      'dd',
      'mkfs',
      'shutdown',
      'reboot',
    })) {
      level = CommandRiskLevel.destructive;
      reasons.add(
        'Mindestens ein Batch-Kommando kann Daten löschen oder überschreiben.',
      );
    }
    final knownShortForce = RegExp(
      r'\b(?:git\s+push|rm|pishrink)\b[^\n;&|]*(?:^|\s)-f(?:\s|$)',
      multiLine: true,
    );
    if (RegExp(r'(^|\s)--force(?:\s|$)').hasMatch(joined) ||
        knownShortForce.hasMatch(joined)) {
      level = CommandRiskLevel.destructive;
      reasons.add('Mindestens ein Batch-Kommando verwendet eine Force-Option.');
    }
    if (RegExp(r'(^|\s)sudo(?:\s|$)').hasMatch(joined)) {
      if (level == CommandRiskLevel.standard) {
        level = CommandRiskLevel.elevated;
      }
      reasons.add('Mindestens ein Batch-Kommando verwendet erhöhte Rechte.');
    }

    return CommandRiskAssessment(
      level: level,
      reasons: List.unmodifiable(reasons),
      containsRawConfiguration: containsRawConfiguration,
    );
  }

  static bool _containsExecutable(String command, Set<String> names) {
    List<String> tokens;
    try {
      tokens = stringToArguments(command);
    } on Object {
      tokens = command.split(RegExp(r'\s+'));
    }

    for (final token in tokens) {
      for (final fragment in token.split(RegExp(r'[\s;&|]+'))) {
        final cleaned = fragment.replaceAll(RegExp(r'''^["']+|["']+$'''), '');
        final executable = cleaned.split(RegExp(r'[/\\]')).last.toLowerCase();
        if (names.contains(executable) ||
            (names.contains('mkfs') && executable.startsWith('mkfs.'))) {
          return true;
        }
      }
    }
    return false;
  }
}
