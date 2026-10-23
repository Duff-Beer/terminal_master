import 'package:process_run/shell.dart' show stringToArguments;

import '../models/command_config.dart';

enum CommandRiskLevel { standard, elevated, destructive }

/// Why a command was flagged as risky.
///
/// Codes rather than sentences: the assessor runs without a `BuildContext`,
/// so the confirmation dialog renders these in the active language.
enum CommandRiskReason {
  rmDeletesPermanently,
  ddOverwrites,
  forceOptionSkipsPrompts,
  elevatedPrivileges,
  batchMayDeleteOrOverwrite,
  batchUsesForce,
  batchUsesElevatedPrivileges,
}

class CommandRiskAssessment {
  final CommandRiskLevel level;
  final List<CommandRiskReason> reasons;
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
    final reasons = <CommandRiskReason>[];
    final command = config.command.replaceAll('_', ' ').trim().toLowerCase();

    if (_containsExecutable(command, const {'rm'})) {
      level = CommandRiskLevel.destructive;
      reasons.add(CommandRiskReason.rmDeletesPermanently);
    }
    if (_containsExecutable(command, const {'dd'})) {
      level = CommandRiskLevel.destructive;
      reasons.add(CommandRiskReason.ddOverwrites);
    }

    for (final parameter in config.parameters) {
      if (!config.isParameterVisible(parameter, values)) continue;
      if (values[parameter.name] != true) continue;
      if (parameter.name == 'force' ||
          parameter.flag == '--force' ||
          parameter.flag == '-f') {
        level = CommandRiskLevel.destructive;
        reasons.add(CommandRiskReason.forceOptionSkipsPrompts);
      }
      if (parameter.name == 'use_sudo' || parameter.flag == 'sudo') {
        if (level == CommandRiskLevel.standard) {
          level = CommandRiskLevel.elevated;
        }
        reasons.add(CommandRiskReason.elevatedPrivileges);
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
    final reasons = <CommandRiskReason>[];
    final joined = commands.join('\n').toLowerCase();

    if (_containsExecutable(joined, const {
      'rm',
      'dd',
      'mkfs',
      'shutdown',
      'reboot',
      'del',
      'erase',
      'rmdir',
      'rd',
      'format',
      'diskpart',
      'remove-item',
      'clear-disk',
      'format-volume',
      'initialize-disk',
      'remove-partition',
    })) {
      level = CommandRiskLevel.destructive;
      reasons.add(CommandRiskReason.batchMayDeleteOrOverwrite);
    }
    final knownShortForce = RegExp(
      r'\b(?:git\s+push|rm|pishrink)\b[^\n;&|]*(?:^|\s)-f(?:\s|$)',
      multiLine: true,
    );
    if (RegExp(r'(^|\s)--?force(?:\s|$)').hasMatch(joined) ||
        knownShortForce.hasMatch(joined)) {
      level = CommandRiskLevel.destructive;
      reasons.add(CommandRiskReason.batchUsesForce);
    }
    if (RegExp(r'(^|\s)sudo(?:\s|$)').hasMatch(joined)) {
      if (level == CommandRiskLevel.standard) {
        level = CommandRiskLevel.elevated;
      }
      reasons.add(CommandRiskReason.batchUsesElevatedPrivileges);
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
