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
      throw const FormatException('Ungültiger gespeicherter Befehl.');
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
  final int row;
  final int column;
  final String profileId;
  final String? workingDirectory;
  final String draft;
  final List<SavedTerminalCommand> commands;

  const SavedTerminalPane({
    required this.row,
    required this.column,
    required this.profileId,
    this.workingDirectory,
    this.draft = '',
    this.commands = const [],
  });

  factory SavedTerminalPane.fromJson(Map<String, Object?> json) {
    final row = json['row'];
    final column = json['column'];
    final profileId = json['profileId'];
    if (row is! int ||
        column is! int ||
        row < 0 ||
        row > 1 ||
        column < 0 ||
        column > 1 ||
        profileId is! String ||
        profileId.isEmpty) {
      throw const FormatException('Ungültige gespeicherte Terminal-Pane.');
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
      row: row,
      column: column,
      profileId: profileId,
      workingDirectory: json['workingDirectory'] as String?,
      draft: json['draft'] as String? ?? '',
      commands: List.unmodifiable(commands),
    );
  }

  Map<String, Object?> toJson() => {
    'row': row,
    'column': column,
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
  final bool verticalSplit;
  final bool horizontalSplit;
  final int focusedRow;
  final int focusedColumn;
  final List<SavedTerminalPane> panes;

  const SavedTerminalTab({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.verticalSplit,
    required this.horizontalSplit,
    required this.focusedRow,
    required this.focusedColumn,
    required this.panes,
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
      throw const FormatException('Ungültiger gespeicherter Terminal-Tab.');
    }
    final panes = <SavedTerminalPane>[];
    for (final value in (json['panes'] as List<Object?>? ?? const [])) {
      if (value case final Map<String, Object?> paneJson) {
        panes.add(SavedTerminalPane.fromJson(paneJson));
      }
    }
    final coordinates = <String>{};
    if (panes.length > 4 ||
        panes.any((pane) => !coordinates.add('${pane.row}:${pane.column}'))) {
      throw const FormatException('Ungültige Pane-Topologie.');
    }
    if (panes.isEmpty ||
        !panes.any((pane) => pane.row == 0 && pane.column == 0)) {
      throw const FormatException('Die Haupt-Pane fehlt.');
    }
    final verticalSplit = json['verticalSplit'] as bool? ?? false;
    final horizontalSplit = json['horizontalSplit'] as bool? ?? false;
    bool hasPane(int row, int column) =>
        panes.any((pane) => pane.row == row && pane.column == column);
    if ((verticalSplit && !hasPane(0, 1)) ||
        (horizontalSplit && !hasPane(1, 0)) ||
        (verticalSplit && horizontalSplit && !hasPane(1, 1))) {
      throw const FormatException('Die Split-Panes sind unvollständig.');
    }
    final focusedRow = json['focusedRow'] as int? ?? 0;
    final focusedColumn = json['focusedColumn'] as int? ?? 0;
    if (focusedRow < 0 ||
        focusedRow > 1 ||
        focusedColumn < 0 ||
        focusedColumn > 1 ||
        !hasPane(focusedRow, focusedColumn)) {
      throw const FormatException('Die fokussierte Pane ist ungültig.');
    }
    return SavedTerminalTab(
      id: id,
      name: name.trim(),
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
      verticalSplit: verticalSplit,
      horizontalSplit: horizontalSplit,
      focusedRow: focusedRow,
      focusedColumn: focusedColumn,
      panes: List.unmodifiable(panes),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'verticalSplit': verticalSplit,
    'horizontalSplit': horizontalSplit,
    'focusedRow': focusedRow,
    'focusedColumn': focusedColumn,
    'panes': panes.map((pane) => pane.toJson()).toList(),
  };
}
