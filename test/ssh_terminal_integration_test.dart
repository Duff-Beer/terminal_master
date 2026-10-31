import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/models/saved_terminal_tab.dart';
import 'package:terminal_master/models/shell_profile.dart';
import 'package:terminal_master/models/ssh_connection_profile.dart';
import 'package:terminal_master/services/remote_file_upload.dart';
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

  test('exposes the reported remote directory and file transfer', () async {
    final backend = _TransferTerminalBackend();
    final session = TerminalSession(
      backendFactory: (_) => backend,
      profile: const ShellProfile(
        id: 'ssh:production',
        name: 'Production',
        executable: 'ssh',
        dialect: ShellDialect.posix,
        sshConnectionProfileId: 'production',
      ),
    );
    addTearDown(session.dispose);
    expect(session.remoteFileTransfer, isNull);
    await session.start();

    expect(session.remoteFileTransfer, same(backend));
    expect(session.remoteWorkingDirectory, isNull);
    backend.emit(utf8.encode('\x1b]7;file://server/srv/My%20App\x07'));
    await Future<void>.delayed(Duration.zero);
    expect(session.remoteWorkingDirectory, '/srv/My App');
  });

  test('looks up the directory of the reported shell process', () async {
    final backend = _TransferTerminalBackend();
    final session = TerminalSession(
      backendFactory: (_) => backend,
      profile: const ShellProfile(
        id: 'ssh:production',
        name: 'Production',
        executable: 'ssh',
        dialect: ShellDialect.posix,
        sshConnectionProfileId: 'production',
      ),
    );
    addTearDown(session.dispose);
    await session.start();
    expect(await session.resolveRemoteWorkingDirectory(), isNull);

    backend.emit(utf8.encode('\x1b]1337;TerminalMasterShellPid=4711\x07'));
    // A later report, e.g. printed by a program in the shell, is ignored.
    backend.emit(utf8.encode('\x1b]1337;TerminalMasterShellPid=1\x07'));
    await Future<void>.delayed(Duration.zero);
    expect(await session.resolveRemoteWorkingDirectory(), '/proc/cwd/of/4711');
    expect(backend.queriedPids, [4711]);

    backend.emit(utf8.encode('\x1b]7;file://server/srv/app\x07'));
    await Future<void>.delayed(Duration.zero);
    expect(await session.resolveRemoteWorkingDirectory(), '/srv/app');
    expect(backend.queriedPids, [4711]);
  });

  test('reports no remote directory for local sessions', () async {
    final factory = RecordingTerminalBackendFactory();
    final session = TerminalSession(
      backendFactory: factory.create,
      profile: const ShellProfile(
        id: 'local',
        name: 'Local',
        executable: '/bin/sh',
        dialect: ShellDialect.posix,
      ),
    );
    addTearDown(session.dispose);
    await session.start();

    factory.backends.single.emit(
      utf8.encode('\x1b]7;file://localhost/tmp\x07'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(session.remoteWorkingDirectory, isNull);
    expect(session.remoteFileTransfer, isNull);
  });

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
        focusedPaneIndex: 0,
        layout: const {'pane': 0},
        panes: const [SavedTerminalPane(profileId: 'ssh:missing')],
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
      throwsA(
        isA<TerminalTabException>().having(
          (error) => error.failure,
          'failure',
          TerminalTabFailure.sshTabsCannotBeSnapshotted,
        ),
      ),
    );
    await expectLater(
      controller.openSavedTab('remote'),
      throwsA(
        isA<TerminalTabException>().having(
          (error) => error.failure,
          'failure',
          TerminalTabFailure.shellProfileUnavailable,
        ),
      ),
    );
    expect(controller.tabs, hasLength(2));
  });
}

class _TransferTerminalBackend extends FakeTerminalBackend
    implements RemoteFileTransfer {
  final List<int> queriedPids = [];

  @override
  Future<RemoteFileSystem> openFileSystem() =>
      throw UnimplementedError('not needed');

  @override
  Future<String?> workingDirectoryOfProcess(int pid) async {
    queriedPids.add(pid);
    return '/proc/cwd/of/$pid';
  }
}
