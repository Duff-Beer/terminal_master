import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';

import '../models/shell_profile.dart';
import '../models/terminal_command_block.dart';
import 'terminal_backend.dart';

enum TerminalSessionStatus { idle, starting, running, exited, failed }

class TerminalSession extends ChangeNotifier {
  static const _commandMarkerVariable = 'TERMINAL_MASTER_END_MARKER';
  static const _terminalEnvironment = {
    'TERM': 'xterm-256color',
    'COLORTERM': 'truecolor',
    'TERM_PROGRAM': 'Terminal Master',
  };

  final TerminalBackendFactory backendFactory;
  final ShellProfile profile;
  final String? initialCommand;
  final Terminal terminal;

  TerminalSession({
    required this.backendFactory,
    required this.profile,
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
  final List<TerminalCommandBlock> _commandBlocks = [];
  TerminalCommandBlock? _activeCommandBlock;
  String _trackedOutputBuffer = '';
  String _trackedEchoBuffer = '';
  bool _awaitingTrackedEcho = false;
  bool _trackedCommandEchoSeen = false;
  var _commandSequence = 0;
  final String _commandEndMarker =
      '__TERMINAL_MASTER_END_${DateTime.now().microsecondsSinceEpoch}__';
  bool _disposed = false;
  bool _processExited = false;
  Future<void>? _startOperation;

  TerminalSessionStatus get status => _status;

  String? get error => _error;

  String? get title => _title;

  String get shellName => profile.name;

  String? get workingDirectory => _workingDirectory;

  int? get exitCode => _exitCode;

  bool get isRunning =>
      _status == TerminalSessionStatus.starting ||
      (_backend != null && !_processExited);

  List<TerminalCommandBlock> get commandBlocks =>
      List.unmodifiable(_commandBlocks);

  bool get hasActiveCommand => _activeCommandBlock != null;

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

  Future<void> start() {
    if (_startOperation case final operation?) return operation;
    if (_status != TerminalSessionStatus.idle) return Future.value();
    return _startOperation = _start();
  }

  Future<void> _start() async {
    _setStatus(TerminalSessionStatus.starting);
    _workingDirectory ??= profile.workingDirectory;

    try {
      _validateProfile();
      final backend = backendFactory(
        TerminalLaunchOptions(
          executable: profile.executable,
          arguments: profile.arguments,
          workingDirectory: profile.workingDirectory,
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
    backend.write(const Utf8Encoder().convert('$command$_lineEnding'));
  }

  void sendTrackedCommand(String command) {
    final backend = _backend;
    if (backend == null || _status != TerminalSessionStatus.running) {
      throw StateError('Die Terminal-Sitzung läuft nicht.');
    }
    if (_activeCommandBlock != null) {
      throw StateError(
        'In diesem Terminal läuft bereits ein getrackter Befehl.',
      );
    }
    if (command.contains('\u0000')) {
      throw ArgumentError.value(command, 'command', 'NUL ist nicht erlaubt.');
    }

    final id = '${DateTime.now().microsecondsSinceEpoch}-${_commandSequence++}';
    final marker = _commandEndMarker;
    final block = TerminalCommandBlock(
      id: id,
      command: command,
      startedAt: DateTime.now(),
      marker: marker,
    );
    _commandBlocks.add(block);
    _activeCommandBlock = block;
    _trackedOutputBuffer = '';
    _trackedEchoBuffer = '';
    _awaitingTrackedEcho = true;
    _trackedCommandEchoSeen = false;
    final payloads = switch (profile.dialect) {
      ShellDialect.posix => [
        _isFish ? _fishTrackedPayload(command) : _posixTrackedPayload(command),
      ],
      ShellDialect.windowsCmd => _windowsTrackedPayload(command),
      ShellDialect.powerShell => [_powerShellTrackedPayload(command)],
    };
    for (final payload in payloads) {
      backend.write(const Utf8Encoder().convert(payload));
    }
    _notify();
  }

  void clearCommandBlocks() {
    if (_activeCommandBlock != null) return;
    _commandBlocks.clear();
    _notify();
  }

  void sendInput(String data) => _writeInput(data);

  Future<void> stop() async {
    final backend = _backend;
    if (backend == null || !isRunning) return;

    backend.write(Uint8List.fromList(const [0x03]));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    backend.write(const Utf8Encoder().convert('exit$_lineEnding'));
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
    final block = _activeCommandBlock;
    if (block == null) {
      terminal.write(data);
      _notify();
      return;
    }

    var trackedData = data;
    final pattern = RegExp('${RegExp.escape(block.marker)}:(-?\\d+)');
    if (_awaitingTrackedEcho) {
      _trackedEchoBuffer += trackedData;
      final expandedWindowsEcho = 'echo ${block.marker}:';
      if (pattern.hasMatch(_trackedEchoBuffer) &&
          !_trackedEchoBuffer.contains(_commandMarkerVariable) &&
          !_trackedEchoBuffer.contains(expandedWindowsEcho)) {
        trackedData = _trackedEchoBuffer;
        _trackedEchoBuffer = '';
        _awaitingTrackedEcho = false;
      } else {
        while (_awaitingTrackedEcho) {
          final lineEnd = _trackedEchoBuffer.indexOf('\n');
          if (lineEnd < 0) return;
          final line = _trackedEchoBuffer.substring(0, lineEnd + 1);
          _trackedEchoBuffer = _trackedEchoBuffer.substring(lineEnd + 1);
          if (line.contains(_commandMarkerVariable) ||
              line.contains(expandedWindowsEcho)) {
            trackedData = _trackedEchoBuffer;
            _trackedEchoBuffer = '';
            _awaitingTrackedEcho = false;
            if (!_trackedCommandEchoSeen) {
              final visibleCommand = block.command.replaceAll('\n', '\n> ');
              terminal.write('> $visibleCommand\r\n');
            }
          } else {
            terminal.write(line);
            final firstCommandLine = block.command
                .split(RegExp(r'[\r\n]'))
                .first;
            if (!_trackedCommandEchoSeen &&
                firstCommandLine.isNotEmpty &&
                line.contains(firstCommandLine)) {
              _trackedCommandEchoSeen = true;
            } else if (_trackedCommandEchoSeen) {
              block.appendOutput(line);
            }
          }
          _notify();
        }
        if (trackedData.isEmpty) return;
      }
    }

    _trackedOutputBuffer += trackedData;
    final match = pattern.firstMatch(_trackedOutputBuffer);
    if (match != null) {
      _emitTrackedOutput(_trackedOutputBuffer.substring(0, match.start));
      var remaining = _trackedOutputBuffer.substring(match.end);
      remaining = remaining.replaceFirst(RegExp(r'^\r?\n'), '');
      _trackedOutputBuffer = '';
      block.finish(int.parse(match.group(1)!));
      _activeCommandBlock = null;
      if (remaining.isNotEmpty) {
        terminal.write(_trackedVisibleOutput(remaining, block));
      }
      _notify();
      return;
    }

    final heldSuffixLength = _trackedMarkerSuffixLength(
      _trackedOutputBuffer,
      block.marker,
    );
    final flushLength = _trackedOutputBuffer.length - heldSuffixLength;
    if (flushLength > 0) {
      _emitTrackedOutput(_trackedOutputBuffer.substring(0, flushLength));
      _trackedOutputBuffer = _trackedOutputBuffer.substring(flushLength);
    }
  }

  void _emitTrackedOutput(String value) {
    if (value.isEmpty) return;
    final block = _activeCommandBlock;
    if (block == null) return;
    terminal.write(_trackedVisibleOutput(value, block));
    block.appendOutput(value);
    _notify();
  }

  String _trackedVisibleOutput(String value, TerminalCommandBlock block) {
    final echoedWrapper = RegExp(
      '^.*(?:${RegExp.escape(block.marker)}|$_commandMarkerVariable).*(?:\\r?\\n|\$)',
      multiLine: true,
    );
    return value.replaceAllMapped(echoedWrapper, (match) {
      final matched = match.group(0)!;
      final ending = matched.endsWith('\r\n')
          ? '\r\n'
          : matched.endsWith('\n')
          ? '\n'
          : '';
      final command = block.command.replaceAll('\n', '$ending> ');
      return '> $command$ending';
    });
  }

  int _trackedMarkerSuffixLength(String value, String marker) {
    final markerIndex = value.lastIndexOf(marker);
    if (markerIndex >= 0) {
      final suffix = value.substring(markerIndex + marker.length);
      if (!suffix.contains('\n') ||
          suffix.isEmpty ||
          suffix == ':' ||
          RegExp(r'^:-?\d*$').hasMatch(suffix)) {
        return value.length - markerIndex;
      }
    }
    final maximum = value.length < marker.length ? value.length : marker.length;
    for (var length = maximum; length > 0; length--) {
      if (marker.startsWith(value.substring(value.length - length))) {
        return length;
      }
    }
    return 0;
  }

  String _posixTrackedPayload(String command) {
    final quoted = command.replaceAll("'", "'\"'\"'");
    return "eval '$quoted'; __terminal_master_exit=\$?; "
        "printf '\\r\\n%s:%s\\r\\n' "
        '"\$$_commandMarkerVariable" "\$__terminal_master_exit"\n';
  }

  List<String> _windowsTrackedPayload(String command) => [
    '$command\r\n',
    'echo %$_commandMarkerVariable%:%errorlevel%\r\n',
  ];

  String _fishTrackedPayload(String command) {
    final quoted = command.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
    return "eval '$quoted'; set __terminal_master_exit \$status; "
        "printf '\\r\\n%s:%s\\r\\n' "
        '"\$$_commandMarkerVariable" "\$__terminal_master_exit"\n';
  }

  String _powerShellTrackedPayload(String command) {
    final encoded = base64Encode(const Utf8Encoder().convert(command));
    return '\$global:LASTEXITCODE=0; '
        "\$__tm_script=[Text.Encoding]::UTF8.GetString("
        "[Convert]::FromBase64String('$encoded')); "
        '\$__tm_success=\$false; '
        'try { & ([ScriptBlock]::Create(\$__tm_script)); '
        '\$__tm_success=\$? } '
        'catch { [Console]::Error.WriteLine([string]\$_) }; '
        '\$__tm_exit=if (\$__tm_success) { 0 } '
        'elseif (\$LASTEXITCODE -ne 0) { \$LASTEXITCODE } else { 1 }; '
        '[Console]::Write("`r`n{0}:{1}`r`n", '
        '\$env:$_commandMarkerVariable, \$__tm_exit)$_lineEnding';
  }

  bool get _isFish {
    final executable = profile.executable.replaceAll('\\', '/');
    return executable
            .substring(executable.lastIndexOf('/') + 1)
            .toLowerCase() ==
        'fish';
  }

  String get _lineEnding {
    if (profile.dialect == ShellDialect.windowsCmd ||
        (profile.dialect == ShellDialect.powerShell && Platform.isWindows)) {
      return '\r\n';
    }
    return '\n';
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
    _interruptTrackedCommand(code);
    terminal.write('\r\n\x1b[90m[Prozess beendet: $code]\x1b[0m\r\n');
    _setStatus(TerminalSessionStatus.exited);
  }

  void _fail(Object error) {
    _error = error.toString();
    _interruptTrackedCommand();
    terminal.write('\r\n\x1b[31m[Terminalfehler: $_error]\x1b[0m\r\n');
    _setStatus(TerminalSessionStatus.failed);
  }

  void _interruptTrackedCommand([int? code]) {
    final block = _activeCommandBlock;
    if (block == null) return;
    if (_trackedOutputBuffer.isNotEmpty) {
      terminal.write(_trackedOutputBuffer);
      block.appendOutput(_trackedOutputBuffer);
      _trackedOutputBuffer = '';
    }
    if (_trackedEchoBuffer.isNotEmpty) {
      terminal.write(_trackedEchoBuffer);
      block.appendOutput(_trackedEchoBuffer);
      _trackedEchoBuffer = '';
    }
    _awaitingTrackedEcho = false;
    _trackedCommandEchoSeen = false;
    block.interrupt(code);
    _activeCommandBlock = null;
  }

  void _setStatus(TerminalSessionStatus status) {
    _status = status;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Map<String, String> get _environment {
    if (!Platform.isWindows) {
      return {
        ...Platform.environment,
        ...profile.environment,
        _commandMarkerVariable: _commandEndMarker,
        ..._terminalEnvironment,
      };
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
      ...profile.environment,
      _commandMarkerVariable: _commandEndMarker,
      ..._terminalEnvironment,
    };
    final path = Platform.environment['PATH'];
    if (path != null && !profile.environment.containsKey('PATH')) {
      environment['PATH'] = path.split(';').where(_isAscii).join(';');
    }
    return environment;
  }

  void _validateProfile() {
    if (profile.executable.trim().isEmpty) {
      throw ArgumentError.value(
        profile.executable,
        'profile.executable',
        'Das Shell-Programm darf nicht leer sein.',
      );
    }
    if (!Platform.isWindows) return;
    final values = <String>[
      profile.executable,
      ...profile.arguments,
      if (profile.workingDirectory case final directory?) directory,
      ...profile.environment.keys,
      ...profile.environment.values,
    ];
    if (values.any((value) => !_isAscii(value))) {
      throw UnsupportedError(
        'flutter_pty unterstützt unter Windows derzeit nur ASCII-Zeichen in '
        'integrierten Shell-Profilen. Verwende vorerst das externe Terminal.',
      );
    }
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
