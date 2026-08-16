import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/models/ssh_connection_profile.dart';
import 'package:terminal_master/services/ssh_connection_profile_store.dart';
import 'package:terminal_master/services/ssh_host_key_verifier.dart';

void main() {
  testWidgets('requires confirmation and persists a trusted host key', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final store = MemorySshConnectionProfileStore();
    const profile = SshConnectionProfile(
      id: 'server',
      name: 'Server',
      host: 'server.example.com',
      username: 'deploy',
    );
    await store.upsert(profile);
    late final DialogSshHostKeyVerifier verifier;
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await verifier.verify(
                profile,
                'ssh-ed25519',
                'SHA256:trusted',
              );
            },
            child: const Text('Verify'),
          ),
        ),
      ),
    );
    verifier = DialogSshHostKeyVerifier(
      navigatorKey: navigatorKey,
      profileStore: store,
    );

    await tester.tap(find.text('Verify'));
    await tester.pump();
    expect(find.textContaining('SHA256:trusted'), findsOneWidget);
    await tester.tap(find.byKey(const Key('trust-ssh-host-key')));
    await tester.pump();

    expect(result, isTrue);
    expect(
      (await store.find(profile.id))!.hostKeyFingerprint,
      'SHA256:trusted',
    );
  });

  testWidgets('blocks a changed trusted host key', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final store = MemorySshConnectionProfileStore();
    const profile = SshConnectionProfile(
      id: 'server',
      name: 'Server',
      host: 'server.example.com',
      username: 'deploy',
      hostKeyType: 'ssh-ed25519',
      hostKeyFingerprint: 'SHA256:old',
    );
    await store.upsert(profile);
    late final DialogSshHostKeyVerifier verifier;
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await verifier.verify(
                profile,
                'ssh-ed25519',
                'SHA256:new',
              );
            },
            child: const Text('Verify'),
          ),
        ),
      ),
    );
    verifier = DialogSshHostKeyVerifier(
      navigatorKey: navigatorKey,
      profileStore: store,
    );

    await tester.tap(find.text('Verify'));
    await tester.pump();
    expect(find.text('SSH-Host-Key geändert'), findsOneWidget);
    await tester.tap(find.text('Schließen'));
    await tester.pump();

    expect(result, isFalse);
    expect((await store.find(profile.id))!.hostKeyFingerprint, 'SHA256:old');
  });

  testWidgets('does not overwrite a profile edited during trust confirmation', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final store = MemorySshConnectionProfileStore();
    const profile = SshConnectionProfile(
      id: 'server',
      name: 'Server',
      host: 'old.example.com',
      username: 'deploy',
    );
    await store.upsert(profile);
    late final DialogSshHostKeyVerifier verifier;
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await verifier.verify(
                profile,
                'ssh-ed25519',
                'SHA256:trusted',
              );
            },
            child: const Text('Verify'),
          ),
        ),
      ),
    );
    verifier = DialogSshHostKeyVerifier(
      navigatorKey: navigatorKey,
      profileStore: store,
    );

    await tester.tap(find.text('Verify'));
    await tester.pump();
    await store.upsert(
      profile.copyWith(host: 'new.example.com', clearHostKey: true),
    );
    await tester.tap(find.byKey(const Key('trust-ssh-host-key')));
    await tester.pump();

    expect(result, isFalse);
    final current = (await store.find(profile.id))!;
    expect(current.host, 'new.example.com');
    expect(current.hostKeyFingerprint, isNull);
  });
}
