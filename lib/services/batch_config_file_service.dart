import 'dart:io';

import 'package:path/path.dart' as p;

import '../utils/config_loader.dart';

class BatchConfigFileService {
  const BatchConfigFileService();

  Future<String> createEmptyBatchFile({
    required String directoryPath,
    required String name,
  }) async {
    final slug = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'^[_-]+|[_-]+$'), '');
    if (slug.isEmpty) throw ArgumentError.value(name, 'name');

    var suffix = 1;
    while (true) {
      final baseName = suffix == 1 ? slug : '${slug}_$suffix';
      final target = File(p.join(directoryPath, '-$baseName.yaml'));
      if (await FileSystemEntity.type(target.path) !=
          FileSystemEntityType.notFound) {
        suffix++;
        continue;
      }

      final temporary = File(
        p.join(
          directoryPath,
          '.batch-create-$pid-${DateTime.now().microsecondsSinceEpoch}.tmp',
        ),
      );
      try {
        await temporary.writeAsString('commands: []\n', flush: true);
        ConfigLoader.loadBatchConfig(temporary.path);
        if (await FileSystemEntity.type(target.path) !=
            FileSystemEntityType.notFound) {
          suffix++;
          continue;
        }
        await temporary.rename(target.path);
        return target.path;
      } on FileSystemException {
        if (await FileSystemEntity.type(target.path) !=
            FileSystemEntityType.notFound) {
          suffix++;
          continue;
        }
        rethrow;
      } finally {
        if (await temporary.exists()) await temporary.delete();
      }
    }
  }
}
