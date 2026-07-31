import 'dart:async';
import 'dart:typed_data';

import 'package:terminal_master/services/terminal_backend.dart';

class RecordingTerminalBackendFactory {
  final List<TerminalLaunchOptions> options = [];
  final List<FakeTerminalBackend> backends = [];

  TerminalBackend create(TerminalLaunchOptions launchOptions) {
    options.add(launchOptions);
    final backend = FakeTerminalBackend();
    backends.add(backend);
    return backend;
  }
}

class FakeTerminalBackend implements TerminalBackend {
  final bool killSucceeds;
  final bool exitOnCommand;
  final outputController = StreamController<Uint8List>();
  final exitCodeCompleter = Completer<int>();
  final List<Uint8List> writes = [];
  final List<(int, int)> sizes = [];
  bool wasKilled = false;

  FakeTerminalBackend({this.killSucceeds = true, this.exitOnCommand = true});

  @override
  Stream<Uint8List> get output => outputController.stream;

  @override
  Future<int> get exitCode => exitCodeCompleter.future;

  @override
  void write(Uint8List data) {
    writes.add(Uint8List.fromList(data));
    if (exitOnCommand && String.fromCharCodes(data).trim() == 'exit') {
      complete(0);
    }
  }

  @override
  void resize(int rows, int columns) => sizes.add((rows, columns));

  @override
  bool kill() {
    wasKilled = true;
    if (!killSucceeds) return false;
    complete(-15);
    return true;
  }

  void emit(List<int> data) => outputController.add(Uint8List.fromList(data));

  void complete(int code) {
    if (!exitCodeCompleter.isCompleted) exitCodeCompleter.complete(code);
    if (!outputController.isClosed) outputController.close();
  }
}
