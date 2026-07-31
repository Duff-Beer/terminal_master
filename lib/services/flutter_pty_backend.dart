import 'dart:typed_data';

import 'package:flutter_pty/flutter_pty.dart';

import 'terminal_backend.dart';

class FlutterPtyBackend implements TerminalBackend {
  final Pty _pty;

  FlutterPtyBackend._(this._pty);

  factory FlutterPtyBackend.start(TerminalLaunchOptions options) {
    return FlutterPtyBackend._(
      Pty.start(
        options.executable,
        arguments: options.arguments,
        workingDirectory: options.workingDirectory,
        environment: options.environment,
        rows: options.rows,
        columns: options.columns,
      ),
    );
  }

  @override
  Stream<Uint8List> get output => _pty.output;

  @override
  Future<int> get exitCode => _pty.exitCode;

  @override
  void write(Uint8List data) => _pty.write(data);

  @override
  void resize(int rows, int columns) => _pty.resize(rows, columns);

  @override
  bool kill() => _pty.kill();
}
