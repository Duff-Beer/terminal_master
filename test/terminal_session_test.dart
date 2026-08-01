import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/services/terminal_session.dart';
import 'package:xterm/xterm.dart';

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
    final environment = factory.options.single.environment!;
    expect(environment['TERM'], 'xterm-256color');
    expect(environment['COLORTERM'], 'truecolor');
    expect(environment['TERM_PROGRAM'], 'Terminal Master');
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
      final session = TerminalSession(backendFactory: factory.create);
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
    },
  );

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
