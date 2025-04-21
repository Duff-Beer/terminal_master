import 'dart:io';
import 'package:path_provider/path_provider.dart';

class InitData {
  final String configPath;
  final String displayPath;
  InitData({required this.configPath, required this.displayPath});
}

Future<InitData> initializeApp() async {
  final appSupportDir = await getApplicationSupportDirectory();
  final terminalMasterDir = Directory(appSupportDir.path);

  if (!terminalMasterDir.existsSync()) {
    terminalMasterDir.createSync(recursive: true);
  }

  String displayPath = terminalMasterDir.path;
  final homeDir = Platform.environment['HOME'];
  if (homeDir != null && displayPath.startsWith(homeDir)) {
    displayPath = displayPath.replaceFirst(homeDir, '~');
  }

  return InitData(
    configPath: terminalMasterDir.path,
    displayPath: displayPath,
  );
}
