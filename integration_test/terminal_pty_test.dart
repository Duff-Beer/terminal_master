import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:terminal_master/models/shell_profile.dart';
import 'package:terminal_master/services/flutter_pty_backend.dart';
import 'package:terminal_master/services/terminal_backend.dart';
import 'package:terminal_master/services/terminal_session.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('starts a native PTY and exchanges terminal data', (
    tester,
  ) async {
    final marker =
        'TERMINAL_MASTER_PTY_${DateTime.now().microsecondsSinceEpoch}';
    final splitAt = marker.length ~/ 2;
    final firstHalf = marker.substring(0, splitAt);
    final secondHalf = marker.substring(splitAt);
    final backend = FlutterPtyBackend.start(
      TerminalLaunchOptions(
        executable: Platform.isWindows
            ? 'cmd.exe'
            : Platform.environment['SHELL'] ?? '/bin/sh',
        arguments: Platform.isWindows ? const ['/V:ON'] : const [],
        environment: Platform.environment,
        rows: 24,
        columns: 80,
      ),
    );
    final output = StringBuffer();
    final markerSeen = Completer<void>();
    var exited = false;
    final subscription = backend.output
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen((chunk) {
          output.write(chunk);
          if (!markerSeen.isCompleted && output.toString().contains(marker)) {
            markerSeen.complete();
          }
        });
    addTearDown(() async {
      if (!exited) {
        backend.kill();
      }
      await subscription.cancel();
    });

    final lineEnding = Platform.isWindows ? '\r\n' : '\n';
    final command = Platform.isWindows
        ? 'set "TM_MARKER=$firstHalf" && echo !TM_MARKER!$secondHalf'
        : "printf '%s%s\\n' '$firstHalf' '$secondHalf'";
    backend.write(const Utf8Encoder().convert('$command$lineEnding'));

    await markerSeen.future.timeout(const Duration(seconds: 10));
    expect(output.toString(), contains(marker));

    backend.write(const Utf8Encoder().convert('exit$lineEnding'));
    final exitCode = await backend.exitCode.timeout(
      const Duration(seconds: 10),
    );
    exited = true;
    expect(exitCode, 0);
  });

  testWidgets('tracks a command through a native shell PTY', (tester) async {
    final outputMarker =
        'TRACKED_OUTPUT_${DateTime.now().microsecondsSinceEpoch}';
    final profile = ShellProfile(
      id: 'integration-shell',
      name: 'Integration Shell',
      executable: Platform.isWindows
          ? 'cmd.exe'
          : Platform.environment['SHELL'] ?? '/bin/sh',
      workingDirectory:
          Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'],
      dialect: Platform.isWindows
          ? ShellDialect.windowsCmd
          : ShellDialect.posix,
    );
    final session = TerminalSession(
      backendFactory: FlutterPtyBackend.start,
      profile: profile,
    );
    final completed = Completer<void>();
    void onSessionChanged() {
      if (session.commandBlocks.lastOrNull?.finishedAt != null &&
          !completed.isCompleted) {
        completed.complete();
      }
    }

    session.addListener(onSessionChanged);
    addTearDown(() {
      session.removeListener(onSessionChanged);
      session.dispose();
    });

    await session.start();
    expect(session.status, TerminalSessionStatus.running);
    session.sendTrackedCommand(
      Platform.isWindows
          ? 'echo $outputMarker'
          : "printf '%s\\n' '$outputMarker'",
    );

    await _waitForTrackedCommand(completed, session);
    final block = session.commandBlocks.single;
    expect(block.exitCode, 0);
    expect(block.output, contains(outputMarker));
    expect(session.terminal.buffer.getText(), isNot(contains(block.marker)));

    await session.stop();
  });

  testWidgets('tracks a command through Windows PowerShell', (tester) async {
    if (!Platform.isWindows) return;

    final outputMarker =
        'POWERSHELL_OUTPUT_${DateTime.now().microsecondsSinceEpoch}';
    final session = TerminalSession(
      backendFactory: FlutterPtyBackend.start,
      profile: ShellProfile(
        id: 'windows-powershell',
        name: 'Windows PowerShell',
        executable: 'powershell.exe',
        arguments: const ['-NoLogo'],
        workingDirectory: Platform.environment['USERPROFILE'],
        dialect: ShellDialect.powerShell,
      ),
    );
    final completed = Completer<void>();
    void onSessionChanged() {
      if (session.commandBlocks.lastOrNull?.finishedAt != null &&
          !completed.isCompleted) {
        completed.complete();
      }
    }

    session.addListener(onSessionChanged);
    addTearDown(() {
      session.removeListener(onSessionChanged);
      session.dispose();
    });

    await session.start();
    expect(session.status, TerminalSessionStatus.running);
    session.sendTrackedCommand("Write-Output '$outputMarker'");

    await _waitForTrackedCommand(completed, session);
    final block = session.commandBlocks.single;
    expect(block.exitCode, 0);
    expect(block.output, contains(outputMarker));
    expect(session.terminal.buffer.getText(), isNot(contains(block.marker)));

    await session.stop();
  });
}

Future<void> _waitForTrackedCommand(
  Completer<void> completed,
  TerminalSession session,
) async {
  try {
    await completed.future.timeout(const Duration(seconds: 10));
  } on TimeoutException {
    final blocks = session.commandBlocks;
    final block = blocks.isEmpty ? null : blocks.last;
    fail(
      'Tracked command timed out: session=${session.status.name}, '
      'block=${block?.status.name}, exitCode=${block?.exitCode}, '
      'capturedOutput=${jsonEncode(block?.output)}, '
      'terminal=${jsonEncode(session.terminal.buffer.getText())}',
    );
  }
}
