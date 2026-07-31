class ConfigItem {
  final String command;
  final String description;
  final String filePath;
  final bool isBatch;
  final String? error;

  ConfigItem({
    required this.command,
    required this.description,
    required this.filePath,
    this.isBatch = false,
    this.error,
  });
}
