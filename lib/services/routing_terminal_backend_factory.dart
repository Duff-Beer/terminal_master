import 'service_exception.dart';
import 'ssh_authentication.dart';
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
      throw const ServiceException(ServiceFailure.sshProfileNotFound);
    }
    final authentication = await SshAuthenticationResolver(
      credentialStore: credentialStore,
    ).resolve(profile);
    return SshTerminalBackend.connect(
      profile: profile,
      authentication: authentication,
      hostKeyVerifier: hostKeyVerifier,
      rows: options.rows,
      columns: options.columns,
    );
  }
}
