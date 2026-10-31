import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../models/ssh_connection_profile.dart';
import 'remote_file_upload.dart';
import 'ssh_authentication.dart';
import 'ssh_host_key_verifier.dart';
import 'terminal_backend.dart';

class SshTerminalBackend implements TerminalBackend, RemoteFileTransfer {
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
    required ResolvedSshAuthentication authentication,
    required SshHostKeyVerifier hostKeyVerifier,
    required int rows,
    required int columns,
  }) async {
    SSHSocket? socket;
    SSHClient? client;
    String? pendingPassword = switch (authentication) {
      ResolvedSshPasswordAuthentication(:final password) => password,
      ResolvedSshPrivateKeyAuthentication() => null,
    };
    try {
      socket = await SSHSocket.connect(
        profile.host,
        profile.port,
        timeout: const Duration(seconds: 10),
      );
      client = SSHClient(
        socket,
        username: profile.username,
        identities: switch (authentication) {
          ResolvedSshPrivateKeyAuthentication(:final identities) => identities,
          ResolvedSshPasswordAuthentication() => null,
        },
        handshakeTimeout: const Duration(seconds: 10),
        authTimeout: const Duration(seconds: 15),
        onVerifyHostKey: (type, fingerprintBytes) => hostKeyVerifier.verify(
          profile,
          type,
          utf8.decode(fingerprintBytes),
        ),
        onPasswordRequest: authentication is ResolvedSshPasswordAuthentication
            ? () => pendingPassword
            : null,
        onUserInfoRequest: authentication is ResolvedSshPasswordAuthentication
            ? (request) {
                final value = pendingPassword;
                if (value == null ||
                    request.prompts.length != 1 ||
                    request.prompts.single.echo) {
                  return null;
                }
                return List.filled(request.prompts.length, value);
              }
            : null,
        onAuthenticated: () => pendingPassword = null,
      );
      final pty = SSHPtyConfig(
        type: 'xterm-256color',
        width: columns,
        height: rows,
      );
      final session =
          await (await _isUnixHost(client)
                  ? client.execute(_pidReportingShellCommand, pty: pty)
                  : client.shell(pty: pty))
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

  /// Starts the user's login shell like a plain shell request, but first
  /// reports its process ID (kept across `exec`) via [remoteShellPidOscKey],
  /// so the working directory can be looked up without touching the prompt.
  /// `sh -c` keeps `$$` working when the login shell is fish or csh.
  static const _pidReportingShellCommand =
      "exec sh -c 'printf \"\\033]1337;$remoteShellPidOscKey=%s\\007\" \$\$; "
      'exec "\${SHELL:-/bin/sh}" -l\'';

  static const _unixKernels = {
    'Linux',
    'Darwin',
    'FreeBSD',
    'OpenBSD',
    'NetBSD',
  };

  /// Whether the host runs a Unix shell. Windows OpenSSH starts cmd.exe, where
  /// the wrapper command would end the session right away.
  static Future<bool> _isUnixHost(SSHClient client) async {
    try {
      final result = await client
          .runWithResult('uname -s', stderr: false)
          .timeout(const Duration(seconds: 5));
      return result.exitCode == 0 &&
          _unixKernels.contains(utf8.decode(result.stdout).trim());
    } on Object {
      return false;
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
  Future<RemoteFileSystem> openFileSystem() async =>
      SftpRemoteFileSystem(await _client.sftp());

  @override
  Future<String?> workingDirectoryOfProcess(int pid) async {
    final result = await _client
        .runWithResult(
          "sh -c 'readlink /proc/$pid/cwd 2>/dev/null || "
          'lsof -a -p $pid -d cwd -Fn 2>/dev/null | sed -n "s/^n//p"\'',
          stderr: false,
        )
        .timeout(const Duration(seconds: 5));
    final directory = utf8.decode(result.stdout, allowMalformed: true).trim();
    return directory.startsWith('/') ? directory : null;
  }

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
