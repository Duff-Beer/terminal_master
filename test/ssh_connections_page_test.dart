import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/models/ssh_connection_profile.dart';
import 'package:terminal_master/pages/ssh_connections_page.dart';
import 'package:terminal_master/services/ssh_backup_service.dart';
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
    expect(find.byKey(const Key('export-ssh-backup')), findsOneWidget);
    expect(find.byKey(const Key('import-ssh-backup')), findsOneWidget);
    await tester.tap(find.byKey(const Key('export-ssh-backup')));
    await tester.pump();
    expect(find.text('Verschlüsseltes SSH-Backup'), findsOneWidget);
    expect(find.byKey(const Key('ssh-backup-export-password')), findsOneWidget);
    expect(
      find.byKey(const Key('ssh-backup-export-confirmation')),
      findsOneWidget,
    );
    await tester.tap(find.text('Abbrechen'));
    await tester.pump();

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

  testWidgets('previews and replaces a conflicting encrypted import', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final directory = Directory.systemTemp.createTempSync(
      'terminal-master-ssh-import-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    const existing = SshConnectionProfile(
      id: 'existing',
      name: 'Existing',
      host: 'server.example.com',
      username: 'deploy',
      credentialId: 'old-credential',
    );
    final profiles = MemorySshConnectionProfileStore([existing]);
    final credentials = MemorySshCredentialStore({
      'old-credential': 'old-password',
      'export-credential': 'imported-password',
    });
    late final String backup;
    await tester.runAsync(() async {
      backup = await SshBackupService(credentialStore: credentials)
          .exportEncrypted(const [
            SshConnectionProfile(
              id: 'export',
              name: 'Imported',
              host: 'server.example.com',
              username: 'deploy',
              credentialId: 'export-credential',
            ),
          ], 'correct horse battery staple');
    });
    final file = File('${directory.path}/backup.tmsshbackup')
      ..writeAsStringSync(backup);
    await tester.pumpWidget(
      MaterialApp(
        home: SshConnectionsPage(
          profileStore: profiles,
          credentialStore: credentials,
          hostKeyVerifier: const TrustAllSshHostKeyVerifier(),
          importPathPicker: () async => file.path,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('import-ssh-backup')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('ssh-backup-import-password')),
      'correct horse battery staple',
    );
    await tester.tap(find.byKey(const Key('open-ssh-backup')));
    await tester.pump();
    for (
      var attempt = 0;
      attempt < 30 && find.text('SSH-Import prüfen').evaluate().isEmpty;
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
    }

    expect(find.text('SSH-Import prüfen'), findsOneWidget);
    expect(find.textContaining('Vorhandene Verbindung'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ssh-import-action-0')));
    await tester.pump();
    await tester.tap(find.text('Ersetzen').last);
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-import-ssh-backup')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final imported = (await profiles.load()).single;
    expect(imported.id, 'existing');
    expect(imported.name, 'Imported');
    expect(
      await credentials.readPassword(imported.credentialId),
      'imported-password',
    );
    expect(await credentials.readPassword('old-credential'), isNull);
  });

  testWidgets('locks profile actions and atomically writes an export', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final directory = Directory.systemTemp.createTempSync(
      'terminal-master-ssh-export-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final target = File('${directory.path}/backup.tmsshbackup')
      ..writeAsStringSync('previous backup');
    final pickerCalled = Completer<void>();
    final pickedPath = Completer<String?>();
    final profiles = MemorySshConnectionProfileStore(const [
      SshConnectionProfile(
        id: 'server',
        name: 'Server',
        host: 'server.example.com',
        username: 'deploy',
        credentialId: 'credential',
      ),
    ]);
    final credentials = MemorySshCredentialStore({
      'credential': 'server-password',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: SshConnectionsPage(
          profileStore: profiles,
          credentialStore: credentials,
          hostKeyVerifier: const TrustAllSshHostKeyVerifier(),
          exportPathPicker: () {
            pickerCalled.complete();
            return pickedPath.future;
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('export-ssh-backup')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('ssh-backup-export-password')),
      'correct horse battery staple',
    );
    await tester.enterText(
      find.byKey(const Key('ssh-backup-export-confirmation')),
      'correct horse battery staple',
    );
    await tester.tap(find.byKey(const Key('confirm-export-ssh-backup')));
    await tester.pump();
    for (
      var attempt = 0;
      attempt < 30 && !pickerCalled.isCompleted;
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
    }
    expect(pickerCalled.isCompleted, isTrue);

    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Bearbeiten'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('connect-ssh-profile-server')),
          )
          .onPressed,
      isNull,
    );
    expect(target.readAsStringSync(), 'previous backup');

    pickedPath.complete(target.path);
    for (
      var attempt = 0;
      attempt < 20 && target.readAsStringSync() == 'previous backup';
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    final backup = target.readAsStringSync();
    expect(backup, isNot('previous backup'));
    final imported = await tester.runAsync(
      () => SshBackupService(
        credentialStore: credentials,
      ).decrypt(backup, 'correct horse battery staple'),
    );
    expect(imported!.single.password, 'server-password');
    expect(
      directory.listSync().where((entry) => entry.path.contains('.tmp-')),
      isEmpty,
    );
  });
}
