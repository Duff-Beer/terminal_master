import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../models/ssh_connection_profile.dart';
import 'ssh_host_key_verifier.dart';
import 'terminal_backend.dart';

class SshTerminalBackend implements TerminalBackend {
  final SSHSocket _socket;
  final SSHClient _client;
  final SSHSession _session;
  final StreamController<Uint8List> _outputController;
  final Completer<int> _exitCodeCompleter = Completer<int>();
  final List<StreamSubscription<Uint8List>> _subscriptions = [];
  var _closedStreams = 0;
  var _killed = false;
  var _transportClosed = false;

  SshTerminalBackend._(
    this._socket,
    this._client,
    this._session,
    this._outputController,
  ) {
    _subscriptions.add(
      _session.stdout.listen(
        _outputController.add,
        onError: _outputController.addError,
        onDone: _handleOutputDone,
      ),
    );
    _subscriptions.add(
      _session.stderr.listen(
        _outputController.add,
        onError: _outputController.addError,
        onDone: _handleOutputDone,
      ),
    );
    _session.done.then(
      (_) {
        if (!_exitCodeCompleter.isCompleted) {
          _exitCodeCompleter.complete(
            _session.exitCode ?? (_killed ? -15 : 255),
          );
        }
        _closeTransport();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_exitCodeCompleter.isCompleted) {
          _exitCodeCompleter.completeError(error, stackTrace);
        }
        if (!_outputController.isClosed) {
          _outputController.addError(error, stackTrace);
        }
        _closeTransport();
      },
    );
  }

  static Future<SshTerminalBackend> connect({
    required SshConnectionProfile profile,
    required String password,
    required SshHostKeyVerifier hostKeyVerifier,
    required int rows,
    required int columns,
  }) async {
    SSHSocket? socket;
    SSHClient? client;
    String? pendingPassword = password;
    try {
      socket = await SSHSocket.connect(
        profile.host,
        profile.port,
        timeout: const Duration(seconds: 10),
      );
      client = SSHClient(
        socket,
        username: profile.username,
        handshakeTimeout: const Duration(seconds: 10),
        authTimeout: const Duration(seconds: 15),
        onVerifyHostKey: (type, fingerprintBytes) => hostKeyVerifier.verify(
          profile,
          type,
          utf8.decode(fingerprintBytes),
        ),
        onPasswordRequest: () => pendingPassword,
        onUserInfoRequest: (request) {
          final value = pendingPassword;
          if (value == null ||
              request.prompts.length != 1 ||
              request.prompts.single.echo) {
            return null;
          }
          return List.filled(request.prompts.length, value);
        },
        onAuthenticated: () => pendingPassword = null,
      );
      final session = await client
          .shell(
            pty: SSHPtyConfig(
              type: 'xterm-256color',
              width: columns,
              height: rows,
            ),
          )
          .timeout(const Duration(seconds: 15));
      pendingPassword = null;
      return SshTerminalBackend._(
        socket,
        client,
        session,
        StreamController<Uint8List>(),
      );
    } on Object {
      pendingPassword = null;
      client?.close();
      socket?.destroy();
      rethrow;
    }
  }

  @override
  Stream<Uint8List> get output => _outputController.stream;

  @override
  Future<int> get exitCode => _exitCodeCompleter.future;

  @override
  void write(Uint8List data) => _session.write(data);

  @override
  void resize(int rows, int columns) => _session.resizeTerminal(columns, rows);

  @override
  bool kill() {
    if (_killed) return true;
    _killed = true;
    _session.close();
    _closeTransport();
    return true;
  }

  void _handleOutputDone() {
    _closedStreams++;
    if (_closedStreams == 2 && !_outputController.isClosed) {
      _outputController.close();
    }
  }

  void _closeTransport() {
    if (_transportClosed) return;
    _transportClosed = true;
    _client.close();
    _socket.destroy();
  }
}
