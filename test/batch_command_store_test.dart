import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/models/batch_command.dart';
import 'package:terminal_master/services/batch_command_store.dart';
import 'package:terminal_master/utils/config_loader.dart';

void main() {
  test('adds a command while preserving the batch YAML', () async {
    final directory = await Directory.systemTemp.createTemp(
      'terminal-master-batch-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/-demo.yaml');
    await file.writeAsString('''
# keep root comment
schema_version: 1
commands:
  - title: Existing
    description: Existing command
    command: pwd
# keep trailing comment
''');
    final originalContent = await file.readAsString();

    await BatchCommandStore.addCommand(
      filePath: file.path,
      command: const BatchCommand(
        title: 'List files',
        description: 'Shows all files',
        command: 'ls -la',
      ),
      expectedContent: originalContent,
    );

    final content = await file.readAsString();
    expect(content, contains('# keep root comment'));
    expect(content, contains('# keep trailing comment'));
    expect(
      ConfigLoader.loadBatchConfig(file.path).commands.last.command,
      'ls -la',
    );
    expect(await File('${file.path}.bak').readAsString(), originalContent);
  });

  test('deletes commands and leaves a valid empty batch list', () async {
    final directory = await Directory.systemTemp.createTemp(
      'terminal-master-batch-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/-demo.yaml');
    await file.writeAsString('''
schema_version: 1
commands:
  - title: First
    description: One
    command: pwd
  - title: Second
    description: Two
    command: date
''');

    await BatchCommandStore.deleteCommand(
      filePath: file.path,
      commandIndex: 0,
      expectedContent: await file.readAsString(),
    );
    expect(
      ConfigLoader.loadBatchConfig(file.path).commands.single.title,
      'Second',
    );

    await BatchCommandStore.deleteCommand(
      filePath: file.path,
      commandIndex: 0,
      expectedContent: await file.readAsString(),
    );
    expect(ConfigLoader.loadBatchConfig(file.path).commands, isEmpty);
    expect(await file.readAsString(), contains('commands: []'));

    await BatchCommandStore.addCommand(
      filePath: file.path,
      command: const BatchCommand(
        title: 'Added again',
        description: '',
        command: 'whoami',
      ),
      expectedContent: await file.readAsString(),
    );
    expect(
      ConfigLoader.loadBatchConfig(file.path).commands.single.command,
      'whoami',
    );
  });

  test('rejects an externally changed batch file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'terminal-master-batch-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/-demo.yaml');
    await file.writeAsString('''
schema_version: 1
commands: []
''');
    final originalContent = await file.readAsString();
    await file.writeAsString('$originalContent# external edit\n');

    await expectLater(
      BatchCommandStore.addCommand(
        filePath: file.path,
        command: const BatchCommand(
          title: 'Date',
          description: '',
          command: 'date',
        ),
        expectedContent: originalContent,
      ),
      throwsA(isA<BatchCommandStoreException>()),
    );
  });
}
