import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/models/saved_terminal_tab.dart';
import 'package:terminal_master/models/shell_profile.dart';
import 'package:terminal_master/models/ssh_connection_profile.dart';
import 'package:terminal_master/services/saved_terminal_tab_store.dart';
import 'package:terminal_master/services/terminal_backend.dart';
import 'package:terminal_master/services/terminal_session.dart';
import 'package:terminal_master/widgets/terminal_panel.dart';

import 'support/fake_terminal_backend.dart';

void main() {
  test(
    'passes the SSH profile ID and uses a remote-safe command marker',
    () async {
      final factory = RecordingTerminalBackendFactory();
      const profile = ShellProfile(
        id: 'ssh:production',
        name: 'Production',
        executable: 'ssh',
        dialect: ShellDialect.posix,
        sshConnectionProfileId: 'production',
      );
      final session = TerminalSession(
        backendFactory: factory.create,
        profile: profile,
      );
      addTearDown(session.dispose);
      await session.start();

      session.sendTrackedCommand('pwd');

      expect(factory.options.single.sshConnectionProfileId, 'production');
      final payload = utf8.decode(factory.backends.single.writes.single);
      expect(payload, contains(session.commandBlocks.single.marker));
      expect(payload, isNot(contains('TERMINAL_MASTER_END_MARKER')));
    },
  );

  test('kills a backend that finishes starting after disposal', () async {
    final backendCompleter = Completer<TerminalBackend>();
    final backend = FakeTerminalBackend();
    final session = TerminalSession(
      backendFactory: (_) => backendCompleter.future,
      profile: const ShellProfile(
        id: 'slow',
        name: 'Slow',
        executable: '/bin/sh',
        dialect: ShellDialect.posix,
      ),
    );

    final start = session.start();
    await Future<void>.delayed(Duration.zero);
    expect(session.status, TerminalSessionStatus.starting);
    session.dispose();
    backendCompleter.complete(backend);
    await start;

    expect(backend.wasKilled, isTrue);
  });

  test('does not save SSH tabs or restore missing profiles locally', () async {
    final store = MemorySavedTerminalTabStore([
      SavedTerminalTab(
        id: 'remote',
        name: 'Remote',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        verticalSplit: false,
        horizontalSplit: false,
        focusedRow: 0,
        focusedColumn: 0,
        panes: const [
          SavedTerminalPane(row: 0, column: 0, profileId: 'ssh:missing'),
        ],
      ),
    ]);
    final controller = TerminalPanelController(
      backendFactory: RecordingTerminalBackendFactory().create,
      navigatorKey: GlobalKey<NavigatorState>(),
      savedTabStore: store,
      profiles: const [
        ShellProfile(
          id: 'local',
          name: 'Local',
          executable: '/bin/sh',
          dialect: ShellDialect.posix,
        ),
      ],
    );
    addTearDown(controller.dispose);
    await controller.createSshTab(
      const SshConnectionProfile(
        id: 'production',
        name: 'Production',
        host: 'example.com',
        username: 'deploy',
      ),
    );

    await expectLater(
      controller.saveActiveTab('Remote'),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      controller.openSavedTab('remote'),
      throwsA(isA<StateError>()),
    );
    expect(controller.tabs, hasLength(2));
  });
}
