import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/models/saved_terminal_tab.dart';
import 'package:terminal_master/services/saved_terminal_tab_store.dart';

void main() {
  test('persists and restores terminal tab snapshots', () async {
    final directory = await Directory.systemTemp.createTemp(
      'terminal-master-snapshots-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = FileSavedTerminalTabStore(directory);
    final snapshot = _snapshot();

    await store.save([snapshot]);
    final loaded = await store.load();

    expect(loaded, hasLength(1));
    expect(loaded.single.id, snapshot.id);
    expect(loaded.single.name, 'Server Maintenance');
    expect(loaded.single.layout['orientation'], 'horizontal');
    expect(loaded.single.panes, hasLength(4));
    expect(loaded.single.panes.last.draft, 'git status');
    expect(loaded.single.panes.last.commands.single.command, 'uname -a');
    expect(loaded.single.panes.last.commands.single.exitCode, 0);
  });

  test('ignores one damaged snapshot without losing valid entries', () async {
    final directory = await Directory.systemTemp.createTemp(
      'terminal-master-snapshots-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      '${FileSavedTerminalTabStore.fileName}',
    );
    await file.writeAsString(
      jsonEncode({
        'version': 1,
        'tabs': [
          {'id': 'damaged'},
          _snapshot().toJson(),
        ],
      }),
    );

    final store = FileSavedTerminalTabStore(directory);
    final loaded = await store.load();

    expect(loaded.map((snapshot) => snapshot.id), ['server-maintenance']);
    await store.save(loaded);
    final rewritten = jsonDecode(await file.readAsString()) as Map;
    expect(rewritten['tabs'], hasLength(2));
    expect(
      (rewritten['tabs'] as List).whereType<Map>().any(
        (entry) => entry['id'] == 'damaged',
      ),
      isTrue,
    );
  });

  test('recovers a backup left by an interrupted atomic write', () async {
    final directory = await Directory.systemTemp.createTemp(
      'terminal-master-snapshots-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = FileSavedTerminalTabStore(directory);
    await store.save([_snapshot()]);
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      '${FileSavedTerminalTabStore.fileName}',
    );
    await file.rename('${file.path}.bak');

    final loaded = await FileSavedTerminalTabStore(directory).load();

    expect(loaded.single.id, 'server-maintenance');
    expect(await file.exists(), isTrue);
  });
}

SavedTerminalTab _snapshot() {
  final createdAt = DateTime.utc(2026, 8, 11, 18);
  return SavedTerminalTab(
    id: 'server-maintenance',
    name: 'Server Maintenance',
    createdAt: createdAt,
    updatedAt: createdAt.add(const Duration(minutes: 5)),
    focusedPaneIndex: 3,
    layout: {
      'orientation': 'horizontal',
      'ratio': 0.5,
      'first': {
        'orientation': 'vertical',
        'ratio': 0.5,
        'first': {'pane': 0},
        'second': {'pane': 1},
      },
      'second': {
        'orientation': 'vertical',
        'ratio': 0.5,
        'first': {'pane': 2},
        'second': {'pane': 3},
      },
    },
    panes: [
      const SavedTerminalPane(profileId: 'primary'),
      const SavedTerminalPane(profileId: 'primary'),
      const SavedTerminalPane(profileId: 'primary'),
      SavedTerminalPane(
        profileId: 'primary',
        workingDirectory: '/tmp',
        draft: 'git status',
        commands: [
          SavedTerminalCommand(
            command: 'uname -a',
            executedAt: createdAt,
            exitCode: 0,
          ),
        ],
      ),
    ],
  );
}
