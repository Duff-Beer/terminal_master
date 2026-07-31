import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/services/terminal_session.dart';

import 'support/fake_terminal_backend.dart';

void main() {
  test('starts a shell, forwards input and tracks resize and exit', () async {
    final factory = RecordingTerminalBackendFactory();
    final session = TerminalSession(
      backendFactory: factory.create,
      initialCommand: 'echo ready',
    );
    addTearDown(session.dispose);

    await session.start();

    expect(session.status, TerminalSessionStatus.running);
    expect(factory.options, hasLength(1));
    expect(factory.options.single.rows, 24);
    expect(factory.options.single.columns, 80);
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

  test('reports backend startup failures without throwing', () async {
    final session = TerminalSession(
      backendFactory: (_) => throw StateError('PTY unavailable'),
    );
    addTearDown(session.dispose);

    await session.start();

    expect(session.status, TerminalSessionStatus.failed);
    expect(session.error, contains('PTY unavailable'));
  });

  test('does not report a failed process termination as exited', () async {
    final backend = FakeTerminalBackend(
      killSucceeds: false,
      exitOnCommand: false,
    );
    final session = TerminalSession(backendFactory: (_) => backend);
    addTearDown(session.dispose);
    await session.start();

    await expectLater(session.stop(), throwsStateError);

    expect(session.status, TerminalSessionStatus.failed);
    expect(session.isRunning, isTrue);
    expect(session.error, contains('nicht beendet'));
  });
}
