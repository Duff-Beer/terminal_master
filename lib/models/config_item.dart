class ConfigItem {
  final String command;
  final String description;
  final String filePath;
  final bool isBatch;

  ConfigItem({
    required this.command,
    required this.description,
    required this.filePath,
    this.isBatch = false,
  });
}
