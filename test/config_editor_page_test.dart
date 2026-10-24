import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/l10n/app_localizations.dart';
import 'package:terminal_master/models/config_editor_document.dart';
import 'package:terminal_master/pages/config_editor_page.dart';
import 'package:terminal_master/services/config_editor_file_service.dart';

void main() {
  testWidgets('creates a configuration and adds an input element', (
    tester,
  ) async {
    final fileService = _MemoryConfigEditorFileService();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ConfigEditorPage(directoryPath: '/tmp', fileService: fileService),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('config-editor-command')),
      'demo-tool',
    );
    await tester.tap(find.byKey(const Key('add-config-editor-parameter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-config-editor-parameter')));
    await tester.pumpAndSettle();
    expect(find.text('parameter_0'), findsWidgets);
    expect(find.text('parameter_1'), findsWidgets);

    final addCondition = find.byKey(
      const Key('add-condition-visible_when-parameter_1'),
    );
    await tester.ensureVisible(addCondition);
    await tester.pumpAndSettle();
    await tester.tap(addCondition);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-config-editor')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(fileService.savedDocument?.command, 'demo-tool');
    expect(fileService.savedDocument?.parameters[0]['name'], 'parameter_0');
    expect(fileService.savedDocument?.parameters[1]['visible_when'], isNotNull);
  });
}

class _MemoryConfigEditorFileService extends ConfigEditorFileService {
  ConfigEditorDocument? savedDocument;

  @override
  Future<String> createPath(String directory, String command) async =>
      '$directory/$command.yaml';

  @override
  Future<void> save(String filePath, ConfigEditorDocument document) async {
    savedDocument = document;
  }
}
