import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/widgets/remote_upload_dialog.dart';

import 'support/localized_app.dart';
import 'support/memory_remote_file_system.dart';

void main() {
  late MemoryRemoteFileSystem remote;
  SshDropChoice? choice;
  var closed = false;

  setUp(() {
    remote = MemoryRemoteFileSystem()
      ..directories.addAll({'/home', '/', '/srv', '/srv/app', '/srv/app/logs'});
    choice = null;
    closed = false;
  });

  Future<void> openDialog(WidgetTester tester, String initialDirectory) async {
    await tester.pumpWidget(
      localizedApp(
        languageCode: 'en',
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              choice = await showSshDropDialog(
                context,
                localPaths: const ['/local/report.pdf'],
                fileSystem: remote,
                initialDirectory: initialDirectory,
              );
              closed = true;
            },
            child: const Text('drop'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('drop'));
    await tester.pumpAndSettle();
  }

  testWidgets('uploads to the prefilled directory', (tester) async {
    await openDialog(tester, '/srv/app');
    expect(find.text('report.pdf'), findsOneWidget);

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();

    expect(choice?.action, SshDropAction.upload);
    expect(choice?.remoteDirectory, '/srv/app');
  });

  testWidgets('expands ~ and rejects missing directories', (tester) async {
    await openDialog(tester, '/srv/app');
    final field = find.byKey(const ValueKey('ssh-drop-directory'));

    await tester.enterText(field, '/srv/missing');
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    expect(
      find.text('This directory does not exist on the SSH host.'),
      findsOneWidget,
    );
    expect(closed, isFalse);

    await tester.enterText(field, '~');
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    expect(choice?.remoteDirectory, '/home/user');
  });

  testWidgets('picks a directory in the remote browser', (tester) async {
    await openDialog(tester, '/srv/app');

    await tester.tap(find.byTooltip('Choose directory'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('logs'));
    await tester.pumpAndSettle();
    expect(find.text('/srv/app/logs'), findsOneWidget);
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    expect(choice?.remoteDirectory, '/srv/app/logs');
  });

  testWidgets('offers inserting the local path instead', (tester) async {
    await openDialog(tester, '/srv/app');

    await tester.tap(find.text('Insert local path'));
    await tester.pumpAndSettle();

    expect(choice?.action, SshDropAction.insertLocalPath);
    expect(choice?.remoteDirectory, isNull);
  });
}
