import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/models/ssh_connection_profile.dart';
import 'package:terminal_master/services/routing_terminal_backend_factory.dart';
import 'package:terminal_master/services/ssh_authentication.dart';
import 'package:terminal_master/services/ssh_connection_profile_store.dart';
import 'package:terminal_master/services/ssh_credential_store.dart';
import 'package:terminal_master/services/ssh_host_key_verifier.dart';
import 'package:terminal_master/services/terminal_backend.dart';

import 'support/fake_terminal_backend.dart';

void main() {
  const localOptions = TerminalLaunchOptions(
    executable: '/bin/sh',
    rows: 24,
    columns: 80,
  );

  test('routes local terminals without reading SSH credentials', () async {
    final local = RecordingTerminalBackendFactory();
    final router = RoutingTerminalBackendFactory(
      localFactory: local.create,
      profileStore: MemorySshConnectionProfileStore(),
      credentialStore: MemorySshCredentialStore(),
      hostKeyVerifier: const TrustAllSshHostKeyVerifier(),
    );

    final backend = await router.create(localOptions);

    expect(backend, same(local.backends.single));
    expect(local.options.single.executable, '/bin/sh');
  });

  test('fails closed for missing SSH profiles or passwords', () async {
    final profileStore = MemorySshConnectionProfileStore();
    final router = RoutingTerminalBackendFactory(
      localFactory: RecordingTerminalBackendFactory().create,
      profileStore: profileStore,
      credentialStore: MemorySshCredentialStore(),
      hostKeyVerifier: const TrustAllSshHostKeyVerifier(),
    );
    const sshOptions = TerminalLaunchOptions(
      executable: 'ssh',
      rows: 24,
      columns: 80,
      sshConnectionProfileId: 'missing',
    );

    await expectLater(router.create(sshOptions), throwsA(isA<StateError>()));
    await profileStore.upsert(
      const SshConnectionProfile(
        id: 'missing',
        name: 'Server',
        host: 'example.com',
        username: 'user',
      ),
    );
    await expectLater(
      router.create(sshOptions),
      throwsA(isA<SshAuthenticationException>()),
    );
  });
}
