import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/pages/ssh_connections_page.dart';
import 'package:terminal_master/services/ssh_connection_profile_store.dart';
import 'package:terminal_master/services/ssh_credential_store.dart';
import 'package:terminal_master/services/ssh_host_key_verifier.dart';

void main() {
  testWidgets('adds and deletes an SSH profile and its password', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final profiles = MemorySshConnectionProfileStore();
    final credentials = MemorySshCredentialStore();
    await tester.pumpWidget(
      MaterialApp(
        home: SshConnectionsPage(
          profileStore: profiles,
          credentialStore: credentials,
          hostKeyVerifier: const TrustAllSshHostKeyVerifier(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('add-ssh-profile')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('ssh-profile-name')),
      'Production',
    );
    await tester.enterText(
      find.byKey(const Key('ssh-profile-host')),
      'server.example.com',
    );
    await tester.enterText(
      find.byKey(const Key('ssh-profile-username')),
      'deploy',
    );
    await tester.enterText(
      find.byKey(const Key('ssh-profile-password')),
      'secret-password',
    );
    await tester.tap(find.byKey(const Key('save-ssh-profile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    var profile = (await profiles.load()).single;
    final originalCredentialId = profile.credentialId;
    expect(find.text('Production'), findsOneWidget);
    expect(
      await credentials.readPassword(profile.credentialId),
      'secret-password',
    );

    await tester.tap(find.text('Bearbeiten'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('ssh-profile-host')),
      'new.example.com',
    );
    await tester.enterText(
      find.byKey(const Key('ssh-profile-password')),
      'new-secret',
    );
    await tester.tap(find.byKey(const Key('save-ssh-profile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    profile = (await profiles.load()).single;
    expect(profile.host, 'new.example.com');
    expect(profile.credentialId, isNot(originalCredentialId));
    expect(await credentials.readPassword(originalCredentialId), isNull);
    expect(await credentials.readPassword(profile.credentialId), 'new-secret');

    await tester.tap(find.byKey(Key('delete-ssh-profile-${profile.id}')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-delete-ssh-profile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(await profiles.load(), isEmpty);
    expect(await credentials.readPassword(profile.credentialId), isNull);
  });
}
