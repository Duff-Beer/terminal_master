import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';

import 'terminal_backend.dart';

enum TerminalSessionStatus { idle, starting, running, exited, failed }

class TerminalSession extends ChangeNotifier {
  final TerminalBackendFactory backendFactory;
  final String? initialCommand;
  final Terminal terminal;

  TerminalSession({
    required this.backendFactory,
    this.initialCommand,
    Terminal? terminal,
  }) : terminal =
           terminal ??
           Terminal(maxLines: 10000, platform: _terminalTargetPlatform) {
    this.terminal.onOutput = _writeInput;
    this.terminal.onResize = _resize;
    this.terminal.onTitleChange = _updateTitle;
  }

  TerminalBackend? _backend;
  StreamSubscription<String>? _outputSubscription;
  TerminalSessionStatus _status = TerminalSessionStatus.idle;
  String? _error;
  String? _title;
  int? _exitCode;
  bool _disposed = false;
  bool _processExited = false;

  TerminalSessionStatus get status => _status;

  String? get error => _error;

  String? get title => _title;

  int? get exitCode => _exitCode;

  bool get isRunning =>
      _status == TerminalSessionStatus.starting ||
      (_backend != null && !_processExited);

  Future<void> start() async {
    if (_status != TerminalSessionStatus.idle) return;
    _setStatus(TerminalSessionStatus.starting);

    try {
      final backend = backendFactory(
        TerminalLaunchOptions(
          executable: _shell,
          arguments: _shellArguments,
          workingDirectory: _homeDirectory,
          environment: _environment,
          rows: terminal.viewHeight,
          columns: terminal.viewWidth,
        ),
      );
      _backend = backend;
      _outputSubscription = backend.output
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(terminal.write, onError: (Object error) => _fail(error));
      backend.exitCode.then(_handleExit, onError: _fail);
      _setStatus(TerminalSessionStatus.running);

      final command = initialCommand;
      if (command != null && command.trim().isNotEmpty) {
        sendCommand(command);
      }
    } on Object catch (error) {
      _fail(error);
    }
  }

  void sendCommand(String command) {
    final backend = _backend;
    if (backend == null || _status != TerminalSessionStatus.running) {
      throw StateError('Die Terminal-Sitzung läuft nicht.');
    }
    backend.write(
      const Utf8Encoder().convert(
        '$command${Platform.isWindows ? '\r\n' : '\n'}',
      ),
    );
  }

  Future<void> stop() async {
    final backend = _backend;
    if (backend == null || !isRunning) return;

    backend.write(Uint8List.fromList(const [0x03]));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    backend.write(
      const Utf8Encoder().convert(Platform.isWindows ? 'exit\r\n' : 'exit\n'),
    );
    try {
      await backend.exitCode.timeout(const Duration(seconds: 1));
      return;
    } on TimeoutException {
      // The shell or its foreground process ignored the graceful shutdown.
    }

    final killed = backend.kill();
    if (!killed) {
      final error = StateError(
        'Der Terminal-Prozess konnte nicht beendet werden.',
      );
      _fail(error);
      throw error;
    }
    try {
      await backend.exitCode.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      final error = TimeoutException(
        'Der Terminal-Prozess wurde nicht innerhalb des Zeitlimits beendet.',
      );
      _fail(error);
      throw error;
    }
  }

  void _writeInput(String data) {
    final backend = _backend;
    if (backend == null || _status != TerminalSessionStatus.running) return;
    backend.write(const Utf8Encoder().convert(data));
  }

  void _resize(int width, int height, int pixelWidth, int pixelHeight) {
    if (width <= 0 || height <= 0) return;
    _backend?.resize(height, width);
  }

  void _updateTitle(String title) {
    _title = title.trim().isEmpty ? null : title.trim();
    _notify();
  }

  void _handleExit(int code) {
    if (_processExited) return;
    _processExited = true;
    _exitCode = code;
    terminal.write('\r\n\x1b[90m[Prozess beendet: $code]\x1b[0m\r\n');
    _setStatus(TerminalSessionStatus.exited);
  }

  void _fail(Object error) {
    _error = error.toString();
    terminal.write('\r\n\x1b[31m[Terminalfehler: $_error]\x1b[0m\r\n');
    _setStatus(TerminalSessionStatus.failed);
  }

  void _setStatus(TerminalSessionStatus status) {
    _status = status;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String get _shell {
    if (Platform.isWindows) return 'cmd.exe';
    return Platform.environment['SHELL'] ?? '/bin/bash';
  }

  List<String> get _shellArguments {
    if (Platform.isWindows) return const [];
    return const ['-l'];
  }

  String? get _homeDirectory {
    return Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
  }

  Map<String, String> get _environment {
    if (!Platform.isWindows) {
      return {...Platform.environment, 'TERM': 'xterm-256color'};
    }

    final home = Platform.environment['USERPROFILE'];
    if (home != null && !_isAscii(home)) {
      throw UnsupportedError(
        'flutter_pty unterstützt unter Windows derzeit keine Benutzerpfade '
        'mit Nicht-ASCII-Zeichen. Verwende vorerst das externe Terminal.',
      );
    }

    final environment = <String, String>{
      for (final entry in Platform.environment.entries)
        if (_isAscii(entry.key) && _isAscii(entry.value))
          entry.key: entry.value,
      'TERM': 'xterm-256color',
    };
    final path = Platform.environment['PATH'];
    if (path != null) {
      environment['PATH'] = path.split(';').where(_isAscii).join(';');
    }
    return environment;
  }

  bool _isAscii(String value) => value.codeUnits.every((unit) => unit <= 0x7f);

  static TerminalTargetPlatform get _terminalTargetPlatform {
    if (Platform.isMacOS) return TerminalTargetPlatform.macos;
    if (Platform.isLinux) return TerminalTargetPlatform.linux;
    if (Platform.isWindows) return TerminalTargetPlatform.windows;
    return TerminalTargetPlatform.unknown;
  }

  @override
  void dispose() {
    _disposed = true;
    terminal.onOutput = null;
    terminal.onResize = null;
    terminal.onTitleChange = null;
    _outputSubscription?.cancel();
    if (isRunning) _backend?.kill();
    super.dispose();
  }
}
