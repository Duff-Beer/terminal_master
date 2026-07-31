import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:terminal_master/services/flutter_pty_backend.dart';
import 'package:terminal_master/services/terminal_backend.dart';

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
    final exitCode = await backend.exitCode.timeout(const Duration(seconds: 10));
    exited = true;
    expect(exitCode, 0);
  });
}
