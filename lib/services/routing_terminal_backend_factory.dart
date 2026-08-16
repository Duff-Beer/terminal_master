import 'ssh_connection_profile_store.dart';
import 'ssh_credential_store.dart';
import 'ssh_host_key_verifier.dart';
import 'ssh_terminal_backend.dart';
import 'terminal_backend.dart';

class RoutingTerminalBackendFactory {
  final TerminalBackendFactory localFactory;
  final SshConnectionProfileStore profileStore;
  final SshCredentialStore credentialStore;
  final SshHostKeyVerifier hostKeyVerifier;

  const RoutingTerminalBackendFactory({
    required this.localFactory,
    required this.profileStore,
    required this.credentialStore,
    required this.hostKeyVerifier,
  });

  Future<TerminalBackend> create(TerminalLaunchOptions options) async {
    final profileId = options.sshConnectionProfileId;
    if (profileId == null) {
      return await Future.sync(() => localFactory(options));
    }
    final profile = await profileStore.find(profileId);
    if (profile == null) {
      throw StateError('Das SSH-Verbindungsprofil wurde nicht gefunden.');
    }
    final password = await credentialStore.readPassword(profile.credentialId);
    if (password == null || password.isEmpty) {
      throw StateError(
        'Für "${profile.name}" ist kein Passwort im Schlüsselbund gespeichert.',
      );
    }
    return SshTerminalBackend.connect(
      profile: profile,
      password: password,
      hostKeyVerifier: hostKeyVerifier,
      rows: options.rows,
      columns: options.columns,
    );
  }
}
