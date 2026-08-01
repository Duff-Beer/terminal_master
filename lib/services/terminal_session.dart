import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';

import 'terminal_backend.dart';

enum TerminalSessionStatus { idle, starting, running, exited, failed }

class TerminalSession extends ChangeNotifier {
  static const _terminalEnvironment = {
    'TERM': 'xterm-256color',
    'COLORTERM': 'truecolor',
    'TERM_PROGRAM': 'Terminal Master',
  };

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
    this.terminal.onPrivateOSC = _handlePrivateOsc;
  }

  TerminalBackend? _backend;
  StreamSubscription<String>? _outputSubscription;
  TerminalSessionStatus _status = TerminalSessionStatus.idle;
  String? _error;
  String? _title;
  String? _workingDirectory;
  int? _exitCode;
  CellAnchor? _pendingLinkStart;
  Uri? _pendingLinkUri;
  final List<TerminalHyperlink> _hyperlinks = [];
  bool _disposed = false;
  bool _processExited = false;

  TerminalSessionStatus get status => _status;

  String? get error => _error;

  String? get title => _title;

  String get shellName {
    final normalized = _shell.replaceAll('\\', '/');
    return normalized.substring(normalized.lastIndexOf('/') + 1);
  }

  String? get workingDirectory => _workingDirectory;

  int? get exitCode => _exitCode;

  bool get isRunning =>
      _status == TerminalSessionStatus.starting ||
      (_backend != null && !_processExited);

  Uri? hyperlinkAt(CellOffset position) {
    _hyperlinks.removeWhere((link) {
      if (link.isAttached) return false;
      link.dispose();
      return true;
    });
    for (final link in _hyperlinks.reversed) {
      if (link.contains(position)) return link.uri;
    }
    return null;
  }

  Future<void> start() async {
    if (_status != TerminalSessionStatus.idle) return;
    _setStatus(TerminalSessionStatus.starting);
    _workingDirectory ??= _homeDirectory;

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
          .listen(_writeOutput, onError: (Object error) => _fail(error));
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

  void sendInput(String data) => _writeInput(data);

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

  void _writeOutput(String data) {
    terminal.write(data);
    _notify();
  }

  void _resize(int width, int height, int pixelWidth, int pixelHeight) {
    if (width <= 0 || height <= 0) return;
    _backend?.resize(height, width);
  }

  void _updateTitle(String title) {
    _title = title.trim().isEmpty ? null : title.trim();
    _notify();
  }

  void _handlePrivateOsc(String code, List<String> arguments) {
    if (code == '7' && arguments.isNotEmpty) {
      _updateWorkingDirectory(arguments.join(';'));
      return;
    }
    if (code != '8' || arguments.isEmpty) return;

    final value = arguments.length > 1
        ? arguments.skip(1).join(';')
        : arguments.single;
    if (value.isEmpty) {
      _finishHyperlink();
      return;
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return;
    _finishHyperlink();
    _pendingLinkUri = uri;
    _pendingLinkStart = terminal.buffer.createAnchorFromCursor();
  }

  void _finishHyperlink() {
    final uri = _pendingLinkUri;
    final begin = _pendingLinkStart;
    _pendingLinkUri = null;
    _pendingLinkStart = null;
    if (uri == null || begin == null || !begin.attached) {
      begin?.dispose();
      return;
    }
    final end = terminal.buffer.createAnchorFromCursor();
    if (begin.offset == end.offset) {
      begin.dispose();
      end.dispose();
      return;
    }
    _hyperlinks.add(TerminalHyperlink(uri: uri, begin: begin, end: end));
  }

  void _updateWorkingDirectory(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'file' || uri.path.isEmpty) return;
    var path = Uri.decodeComponent(uri.path);
    if (Platform.isWindows && RegExp(r'^/[A-Za-z]:/').hasMatch(path)) {
      path = path.substring(1).replaceAll('/', '\\');
    }
    _workingDirectory = path;
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
      return {...Platform.environment, ..._terminalEnvironment};
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
      ..._terminalEnvironment,
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
    terminal.onPrivateOSC = null;
    _pendingLinkStart?.dispose();
    for (final link in _hyperlinks) {
      link.dispose();
    }
    _hyperlinks.clear();
    _outputSubscription?.cancel();
    if (isRunning) _backend?.kill();
    super.dispose();
  }
}

class TerminalHyperlink {
  final Uri uri;
  final CellAnchor begin;
  final CellAnchor end;

  TerminalHyperlink({
    required this.uri,
    required this.begin,
    required this.end,
  });

  bool get isAttached => begin.attached && end.attached;

  bool contains(CellOffset position) {
    if (!isAttached) return false;
    final range = BufferRangeLine(begin.offset, end.offset).normalized;
    return range.begin.isBeforeOrSame(position) && range.end.isAfter(position);
  }

  void dispose() {
    begin.dispose();
    end.dispose();
  }
}
