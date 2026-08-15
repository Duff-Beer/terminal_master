import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/pages/batch_command_page.dart';

void main() {
  testWidgets('offers add fields and delete confirmation', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final directory = Directory.systemTemp.createTempSync(
      'terminal-master-batch-page-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/-demo.yaml');
    file.writeAsStringSync('''
schema_version: 1
commands:
  - title: Existing
    description: Existing command
    command: pwd
''');

    await tester.pumpWidget(
      MaterialApp(home: BatchCommandPage(filePath: file.path)),
    );

    expect(find.byKey(const Key('add-batch-command')), findsOneWidget);
    expect(find.byKey(const Key('delete-batch-command-0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-batch-command')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('new-batch-command-title')), findsOneWidget);
    expect(
      find.byKey(const Key('new-batch-command-description')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('new-batch-command-command')), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('delete-batch-command-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Batch Command löschen?'), findsOneWidget);
    expect(
      find.byKey(const Key('confirm-delete-batch-command')),
      findsOneWidget,
    );
    await tester.tap(find.text('Abbrechen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });
}
