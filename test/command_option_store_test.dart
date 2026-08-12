import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/models/command_config.dart';
import 'package:terminal_master/services/command_option_store.dart';
import 'package:terminal_master/utils/config_loader.dart';

void main() {
  test('adds an option while preserving comments and other fields', () async {
    final directory = await Directory.systemTemp.createTemp(
      'terminal-master-options-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/ssh.yaml');
    await file.writeAsString('''
# keep this comment
schema_version: 1
command: ssh
parameters:
  - name: host
    type: options
    required: true
    options:
      - value: localhost
        description: Local host
    # keep this parameter comment in place
help_text: keep this text
''');
    final originalContent = await file.readAsString();

    await CommandOptionStore.addOption(
      filePath: file.path,
      parameterName: 'host',
      option: const CommandOption(
        value: 'new-host.example.com',
        description: 'New production host',
      ),
      expectedContent: originalContent,
    );

    final content = await file.readAsString();
    expect(content, contains('# keep this comment'));
    expect(content, contains('help_text: keep this text'));
    expect(
      content.indexOf('new-host.example.com'),
      lessThan(content.indexOf('# keep this parameter comment in place')),
    );
    final config = ConfigLoader.loadConfig(file.path);
    final host = config.parameters.single;
    expect(host.options.map((option) => option.value), [
      'localhost',
      'new-host.example.com',
    ]);
    expect(await File('${file.path}.bak').readAsString(), originalContent);
  });

  test('rejects duplicates and externally changed files', () async {
    final directory = await Directory.systemTemp.createTemp(
      'terminal-master-options-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/config.yaml');
    await file.writeAsString('''
schema_version: 1
command: demo
parameters:
  - name: mode
    type: options
    options:
      - value: basic
        description: Basic mode
''');
    final originalContent = await file.readAsString();
    await expectLater(
      CommandOptionStore.addOption(
        filePath: file.path,
        parameterName: 'mode',
        option: const CommandOption(value: 'basic', description: 'Duplicate'),
        expectedContent: originalContent,
      ),
      throwsA(isA<CommandOptionStoreException>()),
    );

    await Future<void>.delayed(const Duration(milliseconds: 10));
    await file.writeAsString('${await file.readAsString()}# external\n');
    await expectLater(
      CommandOptionStore.addOption(
        filePath: file.path,
        parameterName: 'mode',
        option: const CommandOption(value: 'advanced', description: 'Advanced'),
        expectedContent: originalContent,
      ),
      throwsA(isA<CommandOptionStoreException>()),
    );
  });

  test('preserves trailing lines when options are at the end', () async {
    final directory = await Directory.systemTemp.createTemp(
      'terminal-master-options-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/config.yaml');
    await file.writeAsString('''
schema_version: 1
command: demo
parameters:
  - name: mode
    type: options
    options:
      - value: basic
        description: Basic mode

''');
    final originalContent = await file.readAsString();

    await CommandOptionStore.addOption(
      filePath: file.path,
      parameterName: 'mode',
      option: const CommandOption(
        value: 'advanced',
        description: 'Advanced mode',
      ),
      expectedContent: originalContent,
    );

    final content = await file.readAsString();
    expect(content, endsWith('\n\n'));
    expect(
      content,
      contains(
        '        description: Basic mode\n'
        '      - value: "advanced"\n'
        '        description: "Advanced mode"\n\n',
      ),
    );
  });
}
