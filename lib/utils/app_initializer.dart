import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'settings_loader.dart';

class InitData {
  final String configPath;
  final String yamlDirectoryPath;
  final String displayPath;
  InitData({
    required this.configPath,
    required this.yamlDirectoryPath,
    required this.displayPath,
  });
}

Future<InitData> initializeApp() async {
  final appSupportDir = await getApplicationSupportDirectory();
  final terminalMasterDir = Directory(appSupportDir.path);

  if (!terminalMasterDir.existsSync()) {
    terminalMasterDir.createSync(recursive: true);
  }

  await _installBundledConfigs(terminalMasterDir);

  SettingsLoader.initialize(terminalMasterDir.path);

  final yamlDirectoryPath = SettingsLoader.yamlDirectoryPath;
  String displayPath = yamlDirectoryPath;
  final homeDir =
      Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
  if (homeDir != null && displayPath.startsWith(homeDir)) {
    displayPath = displayPath.replaceFirst(homeDir, '~');
  }

  return InitData(
    configPath: terminalMasterDir.path,
    yamlDirectoryPath: yamlDirectoryPath,
    displayPath: displayPath,
  );
}

Future<void> _installBundledConfigs(Directory targetDirectory) async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final configAssets = manifest.listAssets().where(
    (asset) => asset.startsWith('data/') && asset.endsWith('.yaml'),
  );

  for (final asset in configAssets) {
    final fileName = asset.substring(asset.lastIndexOf('/') + 1);
    final target = File(
      '${targetDirectory.path}${Platform.pathSeparator}$fileName',
    );
    if (!target.existsSync()) {
      await target.writeAsString(await rootBundle.loadString(asset));
    }
  }
}
