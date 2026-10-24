import 'persisted_data_exception.dart';

class SavedTerminalCommand {
  final String command;
  final DateTime executedAt;
  final int? exitCode;

  const SavedTerminalCommand({
    required this.command,
    required this.executedAt,
    this.exitCode,
  });

  factory SavedTerminalCommand.fromJson(Map<String, Object?> json) {
    final command = json['command'];
    final executedAt = json['executedAt'];
    if (command is! String || command.trim().isEmpty || executedAt is! String) {
      throw const PersistedDataException(
        PersistedDataProblem.invalidSavedCommand,
      );
    }
    return SavedTerminalCommand(
      command: command,
      executedAt: DateTime.parse(executedAt),
      exitCode: json['exitCode'] as int?,
    );
  }

  Map<String, Object?> toJson() => {
    'command': command,
    'executedAt': executedAt.toUtc().toIso8601String(),
    if (exitCode case final code?) 'exitCode': code,
  };
}

class SavedTerminalPane {
  final String profileId;
  final String? workingDirectory;
  final String draft;
  final List<SavedTerminalCommand> commands;

  const SavedTerminalPane({
    required this.profileId,
    this.workingDirectory,
    this.draft = '',
    this.commands = const [],
  });

  factory SavedTerminalPane.fromJson(Map<String, Object?> json) {
    final profileId = json['profileId'];
    if (profileId is! String || profileId.isEmpty) {
      throw const PersistedDataException(PersistedDataProblem.invalidSavedPane);
    }
    final commands = <SavedTerminalCommand>[];
    for (final value in (json['commands'] as List<Object?>? ?? const [])) {
      if (value case final Map<String, Object?> commandJson) {
        commands.add(SavedTerminalCommand.fromJson(commandJson));
      }
    }
    if (commands.length > 20) {
      commands.removeRange(0, commands.length - 20);
    }
    return SavedTerminalPane(
      profileId: profileId,
      workingDirectory: json['workingDirectory'] as String?,
      draft: json['draft'] as String? ?? '',
      commands: List.unmodifiable(commands),
    );
  }

  Map<String, Object?> toJson() => {
    'profileId': profileId,
    if (workingDirectory case final directory?) 'workingDirectory': directory,
    if (draft.isNotEmpty) 'draft': draft,
    'commands': commands.map((command) => command.toJson()).toList(),
  };
}

class SavedTerminalTab {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SavedTerminalPane> panes;
  final Map<String, Object?> layout;
  final int focusedPaneIndex;

  const SavedTerminalTab({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.panes,
    required this.layout,
    required this.focusedPaneIndex,
  });

  factory SavedTerminalTab.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final createdAt = json['createdAt'];
    final updatedAt = json['updatedAt'];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        createdAt is! String ||
        updatedAt is! String) {
      throw const PersistedDataException(PersistedDataProblem.invalidSavedTab);
    }
    final panes = <SavedTerminalPane>[];
    for (final value in (json['panes'] as List<Object?>? ?? const [])) {
      if (value case final Map<String, Object?> paneJson) {
        panes.add(SavedTerminalPane.fromJson(paneJson));
      }
    }
    final layoutValue = json['layout'];
    final focusedPaneIndex = json['focusedPaneIndex'];
    if (panes.isEmpty ||
        layoutValue is! Map<String, Object?> ||
        focusedPaneIndex is! int ||
        focusedPaneIndex < 0 ||
        focusedPaneIndex >= panes.length) {
      throw const PersistedDataException(
        PersistedDataProblem.invalidPaneTopology,
      );
    }
    final seen = <int>{};
    _validateLayout(layoutValue, panes.length, seen);
    if (seen.length != panes.length) {
      throw const PersistedDataException(
        PersistedDataProblem.invalidPaneTopology,
      );
    }
    return SavedTerminalTab(
      id: id,
      name: name.trim(),
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
      panes: List.unmodifiable(panes),
      layout: Map.unmodifiable(layoutValue),
      focusedPaneIndex: focusedPaneIndex,
    );
  }

  static void _validateLayout(
    Map<String, Object?> node,
    int paneCount,
    Set<int> seen,
  ) {
    if (node['pane'] case final int paneIndex) {
      if (paneIndex < 0 || paneIndex >= paneCount || !seen.add(paneIndex)) {
        throw const PersistedDataException(
          PersistedDataProblem.invalidPaneTopology,
        );
      }
      return;
    }
    final orientation = node['orientation'];
    final ratio = node['ratio'];
    final first = node['first'];
    final second = node['second'];
    if ((orientation != 'vertical' && orientation != 'horizontal') ||
        ratio is! num ||
        !ratio.isFinite ||
        ratio <= 0 ||
        ratio >= 1 ||
        first is! Map<String, Object?> ||
        second is! Map<String, Object?>) {
      throw const PersistedDataException(
        PersistedDataProblem.invalidPaneTopology,
      );
    }
    _validateLayout(first, paneCount, seen);
    _validateLayout(second, paneCount, seen);
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'layout': layout,
    'focusedPaneIndex': focusedPaneIndex,
    'panes': panes.map((pane) => pane.toJson()).toList(),
  };
}
