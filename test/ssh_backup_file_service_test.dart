import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_master/services/ssh_backup_file_service.dart';
import 'package:terminal_master/services/ssh_backup_service.dart';

void main() {
  late Directory directory;
  const service = SshBackupFileService();

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ssh-backup-file-test-');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('reads and atomically writes backup content', () async {
    final path = '${directory.path}/profile.tmsshbackup';
    final bytes = Uint8List.fromList([0x54, 0x4d, 0x0a]);

    await service.writeAtomically(path, bytes);

    expect(await File(path).readAsBytes(), bytes);
    expect(await service.read(File(path)), 'TM\n');
    expect(await directory.list().length, 1);
  });

  test('rejects files larger than the configured import limit', () async {
    final file = File('${directory.path}/too-large.tmsshbackup');
    await file.writeAsBytes(
      List<int>.filled(SshBackupService.maximumFileBytes + 1, 0),
      flush: true,
    );

    await expectLater(
      service.read(file),
      throwsA(
        isA<SshBackupException>().having(
          (error) => error.failure,
          'failure',
          SshBackupFailure.fileTooLarge,
        ),
      ),
    );
  });
}
