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

      expect(files, hasLength(1));
      for (final file in files) {
        expect(
          () => ConfigLoader.loadConfig(file.path),
          returnsNormally,
          reason: file.path,
        );
      }
    });

    test('general example files cover command and batch features', () {
      final config = ConfigLoader.loadConfig('data/example-command.yaml');
      final batch = ConfigLoader.loadBatchConfig('data/-example-batch.yaml');
      final parameterTypes = config.parameters
          .map((parameter) => parameter.type)
          .toSet();

      expect(parameterTypes, containsAll(CommandParameterType.values));
      expect(config.displayName, 'Command Builder feature tour');
      expect(batch.commands, hasLength(3));
      expect(
        batch.commands.every((command) => command.command.startsWith('echo ')),
        isTrue,
      );
    });

    test('async directory loading matches the synchronous loader', () async {
      final syncItems = ConfigLoader.loadConfigs('data', languageCode: 'de');
      final asyncItems = await ConfigLoader.loadConfigsAsync(
        'data',
        languageCode: 'de',
      );

      expect(
        asyncItems.map(
          (item) => (
            item.command,
            item.description,
            item.filePath,
            item.isBatch,
            item.batchCommandCount,
            item.error?.toString(),
          ),
        ),
        syncItems.map(
          (item) => (
            item.command,
            item.description,
            item.filePath,
            item.isBatch,
            item.batchCommandCount,
            item.error?.toString(),
          ),
        ),
      );
      expect(
        await ConfigLoader.loadConfigsAsync('missing-test-directory'),
        isEmpty,
      );
    });

    test('uses the bundled example display name', () {
      final items = ConfigLoader.loadConfigs('data');
      final example = ConfigLoader.loadConfig('data/example-command.yaml');

      expect(example.command, 'echo');
      expect(example.displayName, 'Command Builder feature tour');
      expect(items.map((item) => item.command), contains(example.displayName));
    });

    test('loads the example searchable options and descriptions', () {
      final config = ConfigLoader.loadConfig('data/example-command.yaml');
      final style = config.parameters.singleWhere(
        (parameter) => parameter.name == 'style',
      );

      expect(style.type, CommandParameterType.options);
      expect(style.defaultValue, 'plain');
      expect(style.options.map((option) => option.value), [
        'plain',
        'quoted',
        'compact',
      ]);
      expect(style.options.first.description, 'A simple text value.');
    });

    test('preserves example defaults, picker modes and button actions', () {
      final config = ConfigLoader.loadConfig('data/example-command.yaml');
      final source = config.parameters.singleWhere(
        (parameter) => parameter.name == 'source_path',
      );
      final destination = config.parameters.singleWhere(
        (parameter) => parameter.name == 'destination_path',
      );
      final directory = config.parameters.singleWhere(
        (parameter) => parameter.name == 'output_directory',
      );
      final action = config.parameters.singleWhere(
        (parameter) => parameter.name == 'sample_action',
      );

      expect(config.defaultValues['message'], 'Hello from Terminal Master');
      expect(config.defaultValues['tags'], ['demo', 'yaml']);
      expect(source.mode, FilePickerMode.file);
      expect(destination.mode, FilePickerMode.any);
      expect(directory.mode, FilePickerMode.directory);
      expect(action.label, 'Stage a sample action');
      expect(action.executable, 'echo');
      expect(action.args, ['Sample action from the YAML demo']);
    });

    test(
      'loads the example parameter types and command composition options',
      () {
        final config = ConfigLoader.loadConfig('data/example-command.yaml');
        final tags = config.parameters.singleWhere(
          (parameter) => parameter.name == 'tags',
        );
        final style = config.parameters.singleWhere(
          (parameter) => parameter.name == 'style',
        );
        final message = config.parameters.singleWhere(
          (parameter) => parameter.name == 'message',
        );
        final source = config.parameters.singleWhere(
          (parameter) => parameter.name == 'source_path',
        );

        expect(tags.type, CommandParameterType.textList);
        expect(style.join, CommandValueJoin.attached);
        expect(style.flag, '--style=');
        expect(message.prefix, '[');
        expect(message.suffix, ']');
        expect(source.dependsOn, ['use_paths']);
        expect(
          config.parameters.map((parameter) => parameter.type),
          containsAll(CommandParameterType.values),
        );
      },
    );

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
              .having(
                (error) => error.reason,
                'reason',
                ConfigErrorReason.duplicateParameterName,
              )
              .having((error) => error.detail, 'detail', 'value'),
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
          isA<ConfigFormatException>()
              .having(
                (error) => error.reason,
                'reason',
                ConfigErrorReason.unknownParameterReference,
              )
              .having((error) => error.detail, 'detail', 'missing'),
        ),
      );
    });

    test('supports all, in and inactive conditions', () {
      final file = _temporaryConfig('''
schema_version: 1
command: demo
parameters:
  - name: mode
    type: options
    options:
      - value: basic
        description: Basic
      - value: advanced
        description: Advanced
  - name: disabled
    type: boolean
  - name: value
    type: text
    visible_when:
      all:
        - parameter: mode
          in: [advanced]
        - parameter: disabled
          active: false
''');
      final config = ConfigLoader.loadConfig(file.path);
      final value = config.parameters.singleWhere(
        (parameter) => parameter.name == 'value',
      );

      expect(
        config.isParameterVisible(value, const {
          'mode': 'advanced',
          'disabled': false,
        }),
        isTrue,
      );
      expect(
        config.isParameterVisible(value, const {
          'mode': 'basic',
          'disabled': false,
        }),
        isFalse,
      );
    });

    test('rejects unknown condition operators', () {
      final file = _temporaryConfig('''
schema_version: 1
command: demo
parameters:
  - name: enabled
    type: boolean
  - name: value
    type: text
    visible_when:
      parameter: enabled
      eqauls: true
''');

      expect(
        () => ConfigLoader.loadConfig(file.path),
        throwsA(
          isA<ConfigFormatException>()
              .having(
                (error) => error.reason,
                'reason',
                ConfigErrorReason.unknownFields,
              )
              .having((error) => error.detail, 'detail', contains('eqauls')),
        ),
      );
    });

    test('rejects unknown condition group fields', () {
      final file = _temporaryConfig('''
schema_version: 1
command: demo
parameters:
  - name: enabled
    type: boolean
  - name: value
    type: text
    visible_when:
      any:
        - parameter: enabled
          equals: true
      typo: true
''');

      expect(
        () => ConfigLoader.loadConfig(file.path),
        throwsA(
          isA<ConfigFormatException>()
              .having(
                (error) => error.reason,
                'reason',
                ConfigErrorReason.unknownGroupFields,
              )
              .having((error) => error.detail, 'detail', contains('typo')),
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

    test('creates a readable batch name from the file name', () {
      final directory = Directory.systemTemp.createTempSync(
        'terminal-master-batch-name-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      File(
        '${directory.path}${Platform.pathSeparator}-server_wartung.yaml',
      ).writeAsStringSync('''
schema_version: 1
commands:
  - title: Status
    command: uptime
''');

      final item = ConfigLoader.loadConfigs(directory.path).single;

      expect(item.command, 'Server Wartung');
      expect(item.batchCommandCount, 1);
      expect(item.isBatch, isTrue);
    });

    test('loads the general batch example', () {
      final config = ConfigLoader.loadBatchConfig('data/-example-batch.yaml');

      expect(config.commands, hasLength(3));
      expect(config.commands.first.title, 'Print a greeting');
    });

    test('prefers language-suffixed fields and falls back to base text', () {
      final germanBatch = ConfigLoader.loadBatchConfig(
        'data/-example-batch.yaml',
        languageCode: 'de',
      );
      expect(germanBatch.commands.first.title, 'Begrüßung ausgeben');

      // No French translation exists, so the base English fields are used.
      final frenchBatch = ConfigLoader.loadBatchConfig(
        'data/-example-batch.yaml',
        languageCode: 'fr',
      );
      expect(frenchBatch.commands.first.title, 'Print a greeting');

      final germanCommand = ConfigLoader.loadConfig(
        'data/example-command.yaml',
        languageCode: 'de',
      );
      expect(
        germanCommand.displayName,
        'Funktionsübersicht des Befehlseditors',
      );
      expect(
        germanCommand.parameters
            .firstWhere((parameter) => parameter.name == 'message')
            .label,
        'Nachricht',
      );

      final baseCommand = ConfigLoader.loadConfig('data/example-command.yaml');
      expect(baseCommand.displayName, 'Command Builder feature tour');
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
