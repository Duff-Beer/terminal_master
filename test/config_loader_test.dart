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

      expect(files, hasLength(19));
      for (final file in files) {
        expect(
          () => ConfigLoader.loadConfig(file.path),
          returnsNormally,
          reason: file.path,
        );
      }
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

    test('uses display names to distinguish Nmap configurations', () {
      final items = ConfigLoader.loadConfigs('data');
      final advanced = ConfigLoader.loadConfig('data/nmap.yaml');
      final basic = ConfigLoader.loadConfig('data/nmap_basic.yaml');

      expect(advanced.command, 'nmap');
      expect(advanced.displayName, 'Nmap Advanced');
      expect(basic.command, 'nmap');
      expect(basic.displayName, 'Nmap Basic');
      expect(
        items.map((item) => item.command),
        containsAll(['Nmap Advanced', 'Nmap Basic']),
      );
    });

    test('loads SSH hosts as a required dropdown', () {
      final ssh = ConfigLoader.loadConfig('data/ssh.yaml');
      final host = ssh.parameters.singleWhere(
        (parameter) => parameter.name == 'host',
      );

      expect(ssh.command, 'ssh');
      expect(ssh.displayName, 'SSH connection');
      expect(host.type, CommandParameterType.options);
      expect(host.required, isTrue);
      expect(host.defaultValue, 'localhost');
      expect(host.options.map((option) => option.value), [
        'localhost',
        'staging.example.com',
        'production.example.com',
      ]);
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
      expect(action.label, 'List files');
      expect(action.executable, 'ls');
      expect(action.args, ['-la']);
    });

    test('loads the expanded Nmap schema with value-bearing options', () {
      final nmap = ConfigLoader.loadConfig('data/nmap.yaml');
      final target = nmap.parameters.singleWhere(
        (parameter) => parameter.name == 'target',
      );
      final synDiscovery = nmap.parameters.singleWhere(
        (parameter) => parameter.name == 'syn_discovery_ports',
      );
      final outputXml = nmap.parameters.singleWhere(
        (parameter) => parameter.name == 'output_xml',
      );
      final scanTechnique = nmap.parameters.singleWhere(
        (parameter) => parameter.name == 'scan_technique',
      );

      expect(target.type, CommandParameterType.textList);
      expect(target.required, isTrue);
      expect(synDiscovery.join, CommandValueJoin.attached);
      expect(outputXml.flag, '-oX');
      expect(
        scanTechnique.options.map((option) => option.value),
        contains('-sO'),
      );
      expect(
        nmap.parameters.map((parameter) => parameter.name),
        isNot(contains('filter_up')),
      );
      final scriptArgs = nmap.parameters.singleWhere(
        (parameter) => parameter.name == 'script_args',
      );
      expect(nmap.isParameterVisible(scriptArgs, const {}), isFalse);
      expect(
        nmap.isParameterVisible(scriptArgs, const {'scripts': 'safe'}),
        isTrue,
      );
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

    test('loads the fast local network discovery batch', () {
      final config = ConfigLoader.loadBatchConfig('data/-netzwerk.yaml');

      expect(config.commands, hasLength(1));
      expect(
        config.commands.single.title,
        'Find active devices on the network',
      );
      expect(
        config.commands.single.command,
        "sudo nmap -sn -n -PR -T5 --min-rate 1000 --max-retries 1 "
        "--host-timeout 3s -oG - 192.168.0.0/24 | "
        "awk '/Status: Up/{print \$2}'",
      );
    });

    test(
      'prefers language-suffixed fields and falls back to the base ones',
      () {
        final german = ConfigLoader.loadBatchConfig(
          'data/-netzwerk.yaml',
          languageCode: 'de',
        );
        expect(
          german.commands.single.title,
          'Aktive Geräte im Netzwerk finden',
        );

        // No French translation exists, so the base (English) fields are used.
        final french = ConfigLoader.loadBatchConfig(
          'data/-netzwerk.yaml',
          languageCode: 'fr',
        );
        expect(
          french.commands.single.title,
          'Find active devices on the network',
        );

        final germanCommand = ConfigLoader.loadConfig(
          'data/git_status.yaml',
          languageCode: 'de',
        );
        expect(
          germanCommand.description,
          'Zeigt den Arbeitsverzeichnis‑Status an',
        );
        expect(
          germanCommand.parameters
              .firstWhere((parameter) => parameter.name == 'short')
              .description,
          'Kompakte Ausgabe',
        );

        final baseCommand = ConfigLoader.loadConfig('data/git_status.yaml');
        expect(baseCommand.description, 'Shows the working tree status');
      },
    );
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
