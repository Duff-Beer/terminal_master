import 'package:flutter/material.dart';
import 'app.dart';
import 'utils/app_initializer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final initData = await initializeApp();

  runApp(MyApp(
    configDirectoryPath: initData.configPath,
    displayPath: initData.displayPath,
  ));
}
