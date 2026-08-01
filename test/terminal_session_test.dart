import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/models/shell_profile.dart';
import 'package:terminal_master/models/terminal_command_block.dart';
import 'package:terminal_master/services/terminal_session.dart';
import 'package:xterm/xterm.dart';

import 'support/fake_terminal_backend.dart';

void main() {
  test('starts a shell, forwards input and tracks resize and exit', () async {
    final factory = RecordingTerminalBackendFactory();
    final session = TerminalSession(
      backendFactory: factory.create,
      profile: _testProfile,
      initialCommand: 'echo ready',
    );
    addTearDown(session.dispose);

    await session.start();

    expect(session.status, TerminalSessionStatus.running);
    expect(factory.options, hasLength(1));
    expect(factory.options.single.rows, 24);
    expect(factory.options.single.columns, 80);
    final environment = factory.options.single.environment!;
    expect(environment['TERM'], 'xterm-256color');
    expect(environment['COLORTERM'], 'truecolor');
    expect(environment['TERM_PROGRAM'], 'Terminal Master');
    expect(session.shellName, _testProfile.name);
    expect(session.workingDirectory, factory.options.single.workingDirectory);
    expect(
      utf8.decode(factory.backends.single.writes.single),
      startsWith('echo ready'),
    );

    session.terminal.textInput('manual input');
    expect(utf8.decode(factory.backends.single.writes.last), 'manual input');

    session.terminal.resize(120, 40);
    expect(factory.backends.single.sizes.last, (40, 120));

    factory.backends.single.emit(utf8.encode('\x1b]0;Unit Shell\x07'));
    await Future<void>.delayed(Duration.zero);
    expect(session.title, 'Unit Shell');

    factory.backends.single.complete(0);
    await Future<void>.delayed(Duration.zero);
    expect(session.status, TerminalSessionStatus.exited);
    expect(session.exitCode, 0);
  });

  test(
    'renders ANSI true color, Unicode and alternate screen output',
    () async {
      final factory = RecordingTerminalBackendFactory();
      final session = TerminalSession(
        backendFactory: factory.create,
        profile: _testProfile,
      );
      addTearDown(session.dispose);
      await session.start();

      factory.backends.single.emit(
        utf8.encode('\x1b[1;3;4;38;2;12;34;56mA界🙂\x1b[0m'),
      );
      await Future<void>.delayed(Duration.zero);

      final line = session.terminal.mainBuffer.lines[0];
      expect(line.getText(), contains('A界🙂'));
      expect(line.getForeground(0) & CellColor.typeMask, CellColor.rgb);
      expect(line.getForeground(0) & CellColor.valueMask, 0x0c2238);
      expect(line.getAttributes(0) & CellAttr.bold, CellAttr.bold);
      expect(line.getAttributes(0) & CellAttr.italic, CellAttr.italic);
      expect(line.getAttributes(0) & CellAttr.underline, CellAttr.underline);
      expect(line.getWidth(1), 2);

      factory.backends.single.emit(utf8.encode('\x1b[?1049hALT SCREEN'));
      await Future<void>.delayed(Duration.zero);
      expect(session.terminal.isUsingAltBuffer, isTrue);
      expect(session.terminal.buffer.getText(), contains('ALT SCREEN'));

      factory.backends.single.emit(utf8.encode('\x1b[?1049l'));
      await Future<void>.delayed(Duration.zero);
      expect(session.terminal.isUsingAltBuffer, isFalse);
      expect(session.terminal.buffer.getText(), contains('A界🙂'));

      factory.backends.single.emit(
        utf8.encode(
          '\r\n\x1b]7;file://localhost/tmp/project\x07'
          '\x1b]8;;https://example.com/docs\x07Docs'
          '\x1b]8;;\x07',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(session.workingDirectory, '/tmp/project');
      expect(
        session.hyperlinkAt(const CellOffset(2, 1)),
        Uri.parse('https://example.com/docs'),
      );
      expect(session.hyperlinkAt(const CellOffset(4, 1)), isNull);
    },
  );

  test('reports backend startup failures without throwing', () async {
    final session = TerminalSession(
      backendFactory: (_) => throw StateError('PTY unavailable'),
      profile: _testProfile,
    );
    addTearDown(session.dispose);

    await session.start();

    expect(session.status, TerminalSessionStatus.failed);
    expect(session.error, contains('PTY unavailable'));
  });

  test(
    'starts a configured profile only once for concurrent callers',
    () async {
      final factory = RecordingTerminalBackendFactory();
      const profile = ShellProfile(
        id: 'custom',
        name: 'Custom Shell',
        executable: '/custom/shell',
        arguments: ['--login'],
        workingDirectory: '/workspace',
        environment: {'CUSTOM_VALUE': 'yes', 'TERM': 'ignored'},
        dialect: ShellDialect.posix,
      );
      final session = TerminalSession(
        backendFactory: factory.create,
        profile: profile,
      );
      addTearDown(session.dispose);

      await Future.wait([session.start(), session.start()]);

      expect(factory.options, hasLength(1));
      final options = factory.options.single;
      expect(options.executable, '/custom/shell');
      expect(options.arguments, ['--login']);
      expect(options.workingDirectory, '/workspace');
      expect(options.environment!['CUSTOM_VALUE'], 'yes');
      expect(options.environment!['TERM'], 'xterm-256color');
    },
  );

  test('tracks command output and exit codes across output chunks', () async {
    final factory = RecordingTerminalBackendFactory();
    final session = TerminalSession(
      backendFactory: factory.create,
      profile: _testProfile,
    );
    addTearDown(session.dispose);
    await session.start();

    session.sendTrackedCommand('printf hello');
    final successful = session.commandBlocks.single;
    expect(successful.status, TerminalCommandBlockStatus.running);
    final trackedPayload = factory.backends.single.writes
        .map(utf8.decode)
        .join();
    expect(trackedPayload, contains('TERMINAL_MASTER_END_MARKER'));
    expect(trackedPayload, isNot(contains(successful.marker)));
    expect(
      () => session.sendTrackedCommand('echo too-early'),
      throwsStateError,
    );

    factory.backends.single.emit(
      utf8.encode(
        'wrapper TERMINAL_MASTER_END_MARKER\r\n'
        'hello\r\n${successful.marker}:',
      ),
    );
    factory.backends.single.emit(utf8.encode('0\r\nprompt '));
    await Future<void>.delayed(Duration.zero);

    expect(successful.status, TerminalCommandBlockStatus.succeeded);
    expect(successful.exitCode, 0);
    expect(successful.output, 'hello');
    expect(session.hasActiveCommand, isFalse);
    expect(
      session.terminal.buffer.getText(),
      isNot(contains(successful.marker)),
    );

    session.sendTrackedCommand('false');
    final failed = session.commandBlocks.last;
    factory.backends.single.emit(utf8.encode('${failed.marker}:7\r\n'));
    await Future<void>.delayed(Duration.zero);
    expect(failed.status, TerminalCommandBlockStatus.failed);
    expect(failed.exitCode, 7);
  });

  test('captures Windows CMD output before the marker command echo', () async {
    final factory = RecordingTerminalBackendFactory();
    const profile = ShellProfile(
      id: 'windows-cmd',
      name: 'Windows CMD',
      executable: 'cmd.exe',
      dialect: ShellDialect.windowsCmd,
    );
    final session = TerminalSession(
      backendFactory: factory.create,
      profile: profile,
    );
    addTearDown(session.dispose);
    await session.start();

    session.sendTrackedCommand('echo hello');
    final block = session.commandBlocks.single;
    expect(factory.backends.single.writes.map(utf8.decode), [
      'echo hello\r\n',
      'echo %TERMINAL_MASTER_END_MARKER%:%errorlevel%\r\n',
    ]);
    factory.backends.single.emit(
      utf8.encode(
        'C:\\>echo hello\r\n'
        'hello\r\n'
        'C:\\>echo %TERMINAL_MASTER_END_MARKER%:%errorlevel%\r\n'
        '${block.marker}:0\r\n',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(block.status, TerminalCommandBlockStatus.succeeded);
    expect(block.output, 'hello');
    expect(session.terminal.buffer.getText(), isNot(contains(block.marker)));
  });

  test('ignores an expanded Windows CMD marker command echo', () async {
    final factory = RecordingTerminalBackendFactory();
    const profile = ShellProfile(
      id: 'windows-cmd',
      name: 'Windows CMD',
      executable: 'cmd.exe',
      dialect: ShellDialect.windowsCmd,
    );
    final session = TerminalSession(
      backendFactory: factory.create,
      profile: profile,
    );
    addTearDown(session.dispose);
    await session.start();

    session.sendTrackedCommand('echo hello');
    final block = session.commandBlocks.single;
    factory.backends.single.emit(
      utf8.encode(
        'C:\\>echo hello\r\n'
        'hello\r\n'
        'C:\\>echo ${block.marker}:0\r\n'
        '${block.marker}:0\r\n',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(block.status, TerminalCommandBlockStatus.succeeded);
    expect(block.output, 'hello');
    expect(session.terminal.buffer.getText(), isNot(contains(block.marker)));
  });

  test('tracks PowerShell commands through an encoded script block', () async {
    final factory = RecordingTerminalBackendFactory();
    const profile = ShellProfile(
      id: 'powershell',
      name: 'PowerShell',
      executable: 'pwsh',
      dialect: ShellDialect.powerShell,
    );
    final session = TerminalSession(
      backendFactory: factory.create,
      profile: profile,
    );
    addTearDown(session.dispose);
    await session.start();

    const command = "Write-Output 'quoted'\nWrite-Error 'failed'";
    session.sendTrackedCommand(command);
    final block = session.commandBlocks.single;
    final payload = utf8.decode(factory.backends.single.writes.single);
    expect(payload, contains(base64Encode(utf8.encode(command))));
    expect(payload, isNot(contains(command)));
    expect(payload, contains(r'$global:LASTEXITCODE=0'));
    expect(payload, contains(r'$__tm_success=$?'));
    expect(payload, contains(r'catch { [Console]::Error.WriteLine'));
    expect(payload, contains(r'$env:TERMINAL_MASTER_END_MARKER'));
    expect(payload, contains(r'elseif ($LASTEXITCODE -ne 0)'));
    expect(payload, contains(r'else { 1 }'));
    expect(payload, endsWith(Platform.isWindows ? '\r\n' : '\n'));

    factory.backends.single.emit(
      utf8.encode(
        r'$env:TERMINAL_MASTER_END_MARKER'
        '\r\n'
        'PowerShell output\r\n${block.marker}:1\r\n',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(block.status, TerminalCommandBlockStatus.failed);
    expect(block.exitCode, 1);
    expect(block.output, 'PowerShell output');
    expect(session.terminal.buffer.getText(), isNot(contains(block.marker)));
  });

  test('uses Fish status syntax for tracked commands', () async {
    final factory = RecordingTerminalBackendFactory();
    const profile = ShellProfile(
      id: 'fish',
      name: 'Fish',
      executable: '/usr/bin/fish',
      dialect: ShellDialect.posix,
    );
    final session = TerminalSession(
      backendFactory: factory.create,
      profile: profile,
    );
    addTearDown(session.dispose);
    await session.start();

    session.sendTrackedCommand("printf 'fish'");
    final payload = utf8.decode(factory.backends.single.writes.single);
    expect(payload, contains(r'set __terminal_master_exit $status'));
    expect(payload, isNot(contains(r'__terminal_master_exit=$?')));
  });

  test('does not report a failed process termination as exited', () async {
    final backend = FakeTerminalBackend(
      killSucceeds: false,
      exitOnCommand: false,
    );
    final session = TerminalSession(
      backendFactory: (_) => backend,
      profile: _testProfile,
    );
    addTearDown(session.dispose);
    await session.start();

    await expectLater(session.stop(), throwsStateError);

    expect(session.status, TerminalSessionStatus.failed);
    expect(session.isRunning, isTrue);
    expect(session.error, contains('nicht beendet'));
  });
}

final _testProfile = ShellProfile(
  id: 'test-shell',
  name: 'Test Shell',
  executable: Platform.isWindows ? 'cmd.exe' : '/bin/sh',
  workingDirectory:
      Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'],
  dialect: Platform.isWindows ? ShellDialect.windowsCmd : ShellDialect.posix,
);
