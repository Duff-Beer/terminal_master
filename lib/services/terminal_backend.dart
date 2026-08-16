import 'dart:async';
import 'dart:typed_data';

class TerminalLaunchOptions {
  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final Map<String, String>? environment;
  final int rows;
  final int columns;
  final String? sshConnectionProfileId;

  const TerminalLaunchOptions({
    required this.executable,
    this.arguments = const [],
    this.workingDirectory,
    this.environment,
    required this.rows,
    required this.columns,
    this.sshConnectionProfileId,
  });
}

abstract interface class TerminalBackend {
  Stream<Uint8List> get output;

  Future<int> get exitCode;

  void write(Uint8List data);

  void resize(int rows, int columns);

  bool kill();
}

typedef TerminalBackendFactory =
    FutureOr<TerminalBackend> Function(TerminalLaunchOptions options);

TerminalBackend unavailableTerminalBackendFactory(
  TerminalLaunchOptions options,
) {
  throw UnsupportedError('Kein integriertes Terminal-Backend konfiguriert.');
}
