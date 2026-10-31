import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:terminal_master/services/remote_file_upload.dart';

import 'support/memory_remote_file_system.dart';

void main() {
  late Directory local;
  late MemoryRemoteFileSystem remote;

  setUp(() {
    local = Directory.systemTemp.createTempSync('remote_upload_test');
    remote = MemoryRemoteFileSystem();
  });

  tearDown(() => local.deleteSync(recursive: true));

  String localFile(String relative, String content) {
    final file = File(path.join(local.path, relative))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
    return file.path;
  }

  RemoteFileUploader uploader({
    List<UploadConflictDecision?> decisions = const [],
    List<UploadConflict>? conflicts,
    List<UploadProgress>? progress,
    bool Function()? isCancelled,
  }) {
    final pending = [...decisions];
    return RemoteFileUploader(
      fileSystem: remote,
      resolveConflict: (conflict) async {
        conflicts?.add(conflict);
        if (pending.isEmpty) fail('Unexpected conflict ${conflict.remotePath}');
        return pending.removeAt(0);
      },
      onProgress: progress?.add,
      isCancelled: isCancelled,
    );
  }

  test('uploads files into the given directory and reports progress', () async {
    final progress = <UploadProgress>[];
    final file = localFile('My Report.txt', 'hello');
    remote.directories.add('/srv/app');

    final result = await uploader(
      progress: progress,
    ).upload([file], remoteDirectory: '/srv/app');

    expect(result, ['/srv/app/My Report.txt']);
    expect(
      String.fromCharCodes(remote.files['/srv/app/My Report.txt']!),
      'hello',
    );
    expect(progress.last.transferredBytes, 5);
    expect(progress.last.totalBytes, 5);
    expect(progress.last.fraction, 1);
  });

  test('falls back to the remote home directory', () async {
    final result = await uploader().upload([localFile('a.txt', 'a')]);

    expect(result, ['/home/user/a.txt']);
  });

  test('uploads directories recursively and skips symbolic links', () async {
    localFile('project/readme.md', 'readme');
    localFile('project/src/main.dart', 'main');
    final outside = localFile('secret.txt', 'secret');
    Link(path.join(local.path, 'project', 'link')).createSync(outside);

    final result = await uploader().upload([path.join(local.path, 'project')]);

    expect(result, ['/home/user/project']);
    expect(
      remote.directories,
      containsAll(['/home/user/project', '/home/user/project/src']),
    );
    expect(remote.files.keys, {
      '/home/user/project/readme.md',
      '/home/user/project/src/main.dart',
    });
  });

  test('renames on conflict with a free numbered name', () async {
    remote.files['/home/user/report.tar.gz'] = [1];
    remote.files['/home/user/report.tar (1).gz'] = [2];
    final conflicts = <UploadConflict>[];

    final result = await uploader(
      conflicts: conflicts,
      decisions: const [UploadConflictDecision(UploadConflictAction.rename)],
    ).upload([localFile('report.tar.gz', 'new')]);

    expect(conflicts.single.remotePath, '/home/user/report.tar.gz');
    expect(conflicts.single.canOverwrite, isTrue);
    expect(result, ['/home/user/report.tar (2).gz']);
    expect(remote.files['/home/user/report.tar.gz'], [1]);
  });

  test(
    'overwrites, skips and remembers a decision for all conflicts',
    () async {
      remote.files['/home/user/a.txt'] = [0];
      remote.files['/home/user/b.txt'] = [0];
      remote.files['/home/user/c.txt'] = [0];
      final conflicts = <UploadConflict>[];

      final result =
          await uploader(
            conflicts: conflicts,
            decisions: const [
              UploadConflictDecision(UploadConflictAction.overwrite),
              UploadConflictDecision(
                UploadConflictAction.skip,
                applyToAll: true,
              ),
            ],
          ).upload([
            localFile('a.txt', 'A'),
            localFile('b.txt', 'B'),
            localFile('c.txt', 'C'),
          ]);

      expect(conflicts, hasLength(2));
      expect(result, ['/home/user/a.txt']);
      expect(String.fromCharCodes(remote.files['/home/user/a.txt']!), 'A');
      expect(remote.files['/home/user/b.txt'], [0]);
      expect(remote.files['/home/user/c.txt'], [0]);
    },
  );

  test('merges into an existing directory when overwriting it', () async {
    remote.directories.add('/home/user/project');
    remote.files['/home/user/project/keep.txt'] = [9];
    localFile('project/new.txt', 'new');

    final result = await uploader(
      decisions: const [UploadConflictDecision(UploadConflictAction.overwrite)],
    ).upload([path.join(local.path, 'project')]);

    expect(result, ['/home/user/project']);
    expect(
      remote.files.keys,
      containsAll([
        '/home/user/project/keep.txt',
        '/home/user/project/new.txt',
      ]),
    );
  });

  test('does not offer overwriting an entry of a different type', () async {
    remote.files['/home/user/project'] = [0];
    localFile('project/file.txt', 'x');
    final conflicts = <UploadConflict>[];

    final result = await uploader(
      conflicts: conflicts,
      decisions: const [UploadConflictDecision(UploadConflictAction.rename)],
    ).upload([path.join(local.path, 'project')]);

    expect(conflicts.single.canOverwrite, isFalse);
    expect(conflicts.single.isDirectory, isTrue);
    expect(result, ['/home/user/project (1)']);
    expect(remote.files, contains('/home/user/project (1)/file.txt'));
  });

  test('cancels when the conflict dialog is dismissed', () async {
    remote.files['/home/user/a.txt'] = [0];

    await expectLater(
      uploader(
        decisions: const [null],
      ).upload([localFile('a.txt', 'A'), localFile('b.txt', 'B')]),
      throwsA(isA<UploadCancelledException>()),
    );
    expect(remote.files.keys, ['/home/user/a.txt']);
  });

  test('removes a partially written file when cancelled', () async {
    var cancelled = false;
    final file = localFile('big.bin', 'x' * 200000);
    final progress = <UploadProgress>[];
    final upload = RemoteFileUploader(
      fileSystem: remote,
      resolveConflict: (_) async => null,
      onProgress: (value) {
        progress.add(value);
        if (value.transferredBytes > 0) cancelled = true;
      },
      isCancelled: () => cancelled,
    );

    await expectLater(
      upload.upload([file]),
      throwsA(isA<UploadCancelledException>()),
    );
    expect(remote.deleted, ['/home/user/big.bin']);
    expect(remote.files, isEmpty);
  });
}
