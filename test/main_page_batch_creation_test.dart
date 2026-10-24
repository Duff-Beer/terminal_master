import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/pages/main_page.dart';
import 'package:terminal_master/services/batch_config_file_service.dart';

import 'support/localized_app.dart';

void main() {
  testWidgets('offers the command configuration editor', (tester) async {
    final directory = Directory.systemTemp.createTempSync('main-command-test-');
    addTearDown(() => directory.deleteSync(recursive: true));

    await tester.pumpWidget(
      localizedApp(
        home: MainPage(
          configDirectoryPath: directory.path,
          displayPath: directory.path,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-yaml-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('choose-command-config')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('config-editor-command')), findsOneWidget);
  });

  testWidgets('asks for a name and creates a batch YAML file', (tester) async {
    final directory = Directory.systemTemp.createTempSync('main-batch-test-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final fileService = _MemoryBatchConfigFileService();

    await tester.pumpWidget(
      localizedApp(
        home: MainPage(
          configDirectoryPath: directory.path,
          displayPath: directory.path,
          batchFileService: fileService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create-yaml-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('choose-batch-config')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('new-batch-file-name')),
      'My batch',
    );
    await tester.tap(find.byKey(const Key('confirm-create-batch-file')));
    await tester.pumpAndSettle();

    expect(fileService.directoryPath, directory.path);
    expect(fileService.name, 'My batch');
  });
}

class _MemoryBatchConfigFileService extends BatchConfigFileService {
  String? directoryPath;
  String? name;

  @override
  Future<String> createEmptyBatchFile({
    required String directoryPath,
    required String name,
  }) async {
    this.directoryPath = directoryPath;
    this.name = name;
    return '$directoryPath/-my_batch.yaml';
  }
}
