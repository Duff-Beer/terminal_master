import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/models/command_config.dart';
import 'package:terminal_master/utils/config_loader.dart';

void main() {
  group('ConfigLoader', () {
    test('loads every bundled command configuration', () {
      final files = Directory('data')
          .listSync()
          .whereType<File>()
          .where(
            (file) =>
                file.path.endsWith('.yaml') &&
                !file.uri.pathSegments.last.startsWith('-'),
          )
          .toList();

      expect(files, hasLength(13));
      for (final file in files) {
        expect(
          () => ConfigLoader.loadConfig(file.path),
          returnsNormally,
          reason: file.path,
        );
      }
    });

    test('preserves defaults, picker modes and button actions', () {
      final pishrink = ConfigLoader.loadConfig('data/pishrink.yaml');
      final dd = ConfigLoader.loadConfig('data/dd.yaml');
      final input = pishrink.parameters.singleWhere(
        (parameter) => parameter.name == 'input_file',
      );
      final action = dd.parameters.singleWhere(
        (parameter) => parameter.name == 'list_files',
      );

      expect(pishrink.defaultValues['use_sudo'], isTrue);
      expect(dd.defaultValues['status'], 'progress');
      expect(input.mode, FilePickerMode.file);
      expect(action.label, 'Liste Dateien');
      expect(action.executable, 'ls');
      expect(action.args, ['-la']);
    });

    test('rejects duplicate parameter names with a field path', () {
      final file = _temporaryConfig('''
schema_version: 1
command: demo
parameters:
  - name: value
    type: text
  - name: value
    type: text
''');

      expect(
        () => ConfigLoader.loadConfig(file.path),
        throwsA(
          isA<ConfigFormatException>()
              .having(
                (error) => error.fieldPath,
                'fieldPath',
                'parameters[1].name',
              )
              .having((error) => error.message, 'message', contains('doppelt')),
        ),
      );
    });

    test('keeps the first duplicate from legacy bundled configs', () {
      final file = _temporaryConfig('''
command: pishrink
parameters:
  - name: preserve_original
    type: boolean
    flag: -p
    conflicts_with: [output_file]
  - name: preserve_original
    type: boolean
    flag: -p
  - name: output_file
    type: text
''');

      final config = ConfigLoader.loadConfig(file.path);

      expect(
        config.parameters.where(
          (parameter) => parameter.name == 'preserve_original',
        ),
        hasLength(1),
      );
      expect(config.parameters.first.conflictsWith, ['output_file']);
    });

    test('rejects unknown dependency references', () {
      final file = _temporaryConfig('''
command: demo
parameters:
  - name: value
    type: text
    depends_on: [missing]
''');

      expect(
        () => ConfigLoader.loadConfig(file.path),
        throwsA(
          isA<ConfigFormatException>().having(
            (error) => error.message,
            'message',
            contains('missing'),
          ),
        ),
      );
    });

    test('shows malformed files as errors in the configuration list', () {
      final directory = Directory.systemTemp.createTempSync(
        'terminal-master-list-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      File(
        '${directory.path}${Platform.pathSeparator}broken.yaml',
      ).writeAsStringSync('command: [unterminated');

      final items = ConfigLoader.loadConfigs(directory.path);

      expect(items, hasLength(1));
      expect(items.single.error, isNotNull);
      expect(items.single.command, contains('broken.yaml'));
    });

    test('rejects malformed batch entries in list and detail loading', () {
      final directory = Directory.systemTemp.createTempSync(
        'terminal-master-batch-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final file =
          File('${directory.path}${Platform.pathSeparator}-broken.yaml')
            ..writeAsStringSync('''
schema_version: 1
commands:
  - invalid
''');

      final items = ConfigLoader.loadConfigs(directory.path);

      expect(items, hasLength(1));
      expect(items.single.error, isNotNull);
      expect(
        () => ConfigLoader.loadBatchConfig(file.path),
        throwsA(
          isA<ConfigFormatException>().having(
            (error) => error.fieldPath,
            'fieldPath',
            'commands[0]',
          ),
        ),
      );
    });
  });
}

File _temporaryConfig(String content) {
  final directory = Directory.systemTemp.createTempSync(
    'terminal-master-test-',
  );
  addTearDown(() => directory.deleteSync(recursive: true));
  return File('${directory.path}${Platform.pathSeparator}config.yaml')
    ..writeAsStringSync(content);
}
