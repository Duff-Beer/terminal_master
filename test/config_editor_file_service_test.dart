import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/models/config_editor_document.dart';
import 'package:terminal_master/services/config_editor_file_service.dart';
import 'package:terminal_master/utils/config_loader.dart';

void main() {
  late Directory directory;
  const service = ConfigEditorFileService();

  setUp(() {
    directory = Directory.systemTemp.createTempSync('config-editor-test-');
  });

  tearDown(() => directory.deleteSync(recursive: true));

  test('loads, serializes and saves a configuration with conditions', () async {
    final file = File('${directory.path}/demo.yaml')
      ..writeAsStringSync('''
schema_version: 2
command: demo
display_name.en: Demo
display_name.de: Beispiel
description: Test
parameters:
  - name: mode
    type: options
    options:
      - value: basic
        description: Basic
      - value: advanced
        description: Advanced
  - name: extra
    type: text
    visible_when:
      all:
        - parameter: mode
          equals: advanced
''');

    final document = await service.load(file.path);
    expect(document.data['display_name.en'], 'Demo');
    expect(document.parameters, hasLength(2));
    document.parameters[1]['required_when'] = {
      'any': [
        {
          'parameter': 'mode',
          'in': ['advanced', 'basic'],
        },
      ],
    };

    await service.save(file.path, document);
    final reloaded = await service.load(file.path);
    expect(reloaded.data['display_name.de'], 'Beispiel');
    expect(reloaded.parameters[1]['required_when'], isNotNull);
    expect(ConfigLoader.loadConfig(file.path).parameters, hasLength(2));
  });

  test('creates a new configuration file after validating it', () async {
    final document = ConfigEditorDocument.empty()..command = 'new-command';
    final path = await service.createPath(directory.path, document.command);

    await service.save(path, document);

    expect(await File(path).exists(), isTrue);
    expect(await File('$path.editor-tmp.yaml').exists(), isFalse);
    expect(ConfigLoader.loadConfig(path).command, 'new-command');
  });

  test('does not replace an existing file when validation fails', () async {
    final file = File('${directory.path}/demo.yaml')
      ..writeAsStringSync('command: demo\nparameters: []\n');
    final document = ConfigEditorDocument.empty()..command = '';

    await expectLater(
      service.save(file.path, document),
      throwsA(
        isA<ConfigFormatException>().having(
          (error) => error.filePath,
          'filePath',
          file.path,
        ),
      ),
    );
    expect(await file.readAsString(), 'command: demo\nparameters: []\n');
  });
}
