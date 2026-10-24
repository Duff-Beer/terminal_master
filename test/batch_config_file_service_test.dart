import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/models/batch_command.dart';
import 'package:terminal_master/services/batch_command_store.dart';
import 'package:terminal_master/services/batch_config_file_service.dart';
import 'package:terminal_master/utils/config_loader.dart';

void main() {
  late Directory directory;
  const service = BatchConfigFileService();

  setUp(() {
    directory = Directory.systemTemp.createTempSync('batch-config-test-');
  });

  tearDown(() => directory.deleteSync(recursive: true));

  test('creates a valid empty batch file with a batch filename', () async {
    final path = await service.createEmptyBatchFile(
      directoryPath: directory.path,
      name: 'Network Tools',
    );

    expect(path, endsWith('/-network_tools.yaml'));
    expect(await File(path).readAsString(), 'commands: []\n');
    expect(ConfigLoader.loadBatchConfig(path).commands, isEmpty);

    await BatchCommandStore.addCommand(
      filePath: path,
      command: const BatchCommand(
        title: 'List files',
        description: '',
        command: 'ls',
      ),
      expectedContent: await File(path).readAsString(),
    );
    expect(ConfigLoader.loadBatchConfig(path).commands.single.command, 'ls');
  });

  test('uses a unique filename for duplicate names', () async {
    final first = await service.createEmptyBatchFile(
      directoryPath: directory.path,
      name: 'Tools',
    );
    final second = await service.createEmptyBatchFile(
      directoryPath: directory.path,
      name: 'Tools',
    );

    expect(first, isNot(second));
    expect(second, endsWith('/-tools_2.yaml'));
    expect(directory.listSync().whereType<File>(), hasLength(2));
  });
}
